function p3_lvrt_zero_batch(outdir,smokeOnly)
if nargin<2,smokeOnly=false;end
r=setup_v2_paths;m='PV_WIND_BESS_SM_FIXED_R1';assert(isfolder(outdir));d=outdir;[~,runid]=fileparts(d);
cache=tempname;mkdir(cache);Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'cache'),'CodeGenFolder',fullfile(cache,'code'),'createDir',true);
for k=0:1
 modes={'local','coordinated'};tag=modes{k+1};R=struct('stage',tag,'state','running','fault_R_ohm',.40,'on_s',2.65,'off_s',2.8,'run_id',runid);record;
 try
 assert(~bdIsLoaded(m));load_system(p3_release_model_path(r,m));cl=onCleanup(@()close_system(m,0));
 % Same pre-fault VAR policies, inertia, AVR, resource feeders in both cases.
 p3_var_case(m,'var_local_feeders');p=[m '/PV Command'];w=[m '/Wind Command'];
 set_param([m '/1 Mvar bank'],'component_structure','ee.enum.rlc.structure.R','R','.40');add_block('simulink/Sources/Step',[m '/Clear shunt'],'Time','2.8','Before','0','After','1');add_block('simulink/Math Operations/Sum',[m '/Fault breaker gate'],'Inputs','++');delete_line(m,'Apply VAR load/1','Bank control PS/1');wire(m,'Apply VAR load/1','Fault breaker gate/1');wire(m,'Clear shunt/1','Fault breaker gate/2');wire(m,'Fault breaker gate/1','Bank control PS/1');
 % Native per-phase current-zero opening, retaining the identical close command,
 % 0.4 ohm shunt, controller, initial states, local protections, and solver.
 br=[m '/VAR load breaker'];enumName='ee.enum.switches.breakerBehavior.zeroCrossingEnable';R.previous_mode=get_param(br,'breaker_behavior');set_param(br,'breaker_behavior',enumName);
 assert(strcmp(get_param(br,'breaker_behavior'),enumName));R.mode=enumName;
 bport=v2_port(br,'RConn',1);zport=v2_port([m '/1 Mvar bank'],'LConn',1);
 l0=get_param(bport,'Line');assert(l0==get_param(zport,'Line'));delete_line(l0);
 meter=[m '/Fault branch VI'];add_block([m '/Intertie VI'],meter);add_line(m,bport,v2_port(meter,'LConn',1),'autorouting','on');add_line(m,v2_port(meter,'RConn',3),zport,'autorouting','on');
 add_block([m '/Intertie amps'],[m '/Fault abc amperes']);add_line(m,v2_port(meter,'RConn',2),v2_port([m '/Fault abc amperes'],'LConn',1),'autorouting','on');
 add_block('simulink/Sinks/To Workspace',[m '/Fault current recorder'],'VariableName','fault_abc_A','SaveFormat','Timeseries','MaxDataPoints','inf');wire(m,'Fault abc amperes/1','Fault current recorder/1');
 add_block('simulink/Sinks/To Workspace',[m '/Fault release recorder'],'VariableName','fault_open_command','SaveFormat','Timeseries','MaxDataPoints','inf');wire(m,'Fault breaker gate/1','Fault release recorder/1');
 R.state='simulating';R.pid=feature('getpid');record;
 % Continuous voltage measurement, 5 ms supervisory action. Never feed fault
 % time to the coordinator. Local hardware limits operate in both cases.
 % Registered voltage measurement: the supervisor uses the previous 5 ms
 % sample (in volts), not the same-step grid response to its own P/Q output.
 add_block('simulink/Discrete/Unit Delay',[m '/AC sample'],'SampleTime','.005','InitialCondition','10000');wire(m,'Grid measurements/1','AC sample/1');
 add_block('simulink/User-Defined Functions/Fcn',[m '/Voltage deficit'],'Expr','(9000-u)/2500');add_block('simulink/Discontinuities/Saturation',[m '/Fault severity'],'LowerLimit','0','UpperLimit','1');
 wire(m,'AC sample/1','Voltage deficit/1');wire(m,'Voltage deficit/1','Fault severity/1');add_block('simulink/Sources/Step',[m '/Supervisor armed'],'Time','2.40','Before','0','After',num2str(k));add_block('simulink/Math Operations/Product',[m '/Dispatch severity']);wire(m,'Fault severity/1','Dispatch severity/1');wire(m,'Supervisor armed/1','Dispatch severity/2');
 for j=1:2
  subs={p,w};names={'PV Command','Wind Command'};s=subs{j};bn=names{j};add_block('simulink/Sources/In1',[s '/LVRT input']);port=get_param([s '/LVRT input'],'Port');wire(m,'Dispatch severity/1',[bn '/' port]);
  delete_line(s,'P Reference/1','Command/1');add_block('simulink/User-Defined Functions/Fcn',[s '/P fraction'],'Expr','1-0.5*u');wire(s,'LVRT input/1','P fraction/1');add_block('simulink/Math Operations/Product',[s '/Active dispatch']);wire(s,'P Reference/1','Active dispatch/1');wire(s,'P fraction/1','Active dispatch/2');wire(s,'Active dispatch/1','Command/1');
  if j==1
   delete_line(s,'Q Reference/1','Command/2');add_block('simulink/Math Operations/Gain',[s '/PF setting'],'Gain','tan(acos(.90))');wire(s,'P Reference/1','PF setting/1');add_block('simulink/Sources/Step',[s '/PF permit'],'Time','1.35','Before','0','After','1');add_block('simulink/Math Operations/Product',[s '/PF paced']);wire(s,'PF setting/1','PF paced/1');wire(s,'PF permit/1','PF paced/2');add_block('simulink/Discontinuities/Rate Limiter',[s '/PF slew'],'RisingSlewLimit','4e6','FallingSlewLimit','-4e6');wire(s,'PF paced/1','PF slew/1');base='PF slew/1';
  else,delete_line(s,'Reactive dispatch/1','Command/2');base='Reactive dispatch/1';end
  add_block('simulink/Math Operations/Gain',[s '/Extra Q'],'Gain','1.0e6');wire(s,'LVRT input/1','Extra Q/1');add_block('simulink/Math Operations/Sum',[s '/Reactive order'],'Inputs','++');wire(s,base,'Reactive order/1');wire(s,'Extra Q/1','Reactive order/2');wire(s,'Reactive order/1','Command/2');
  ph=get_param([s '/Command'],'PortHandles');set_param(get_param(ph.Inport(1),'Line'),'Name','P_ref_W');set_param(get_param(ph.Inport(2),'Line'),'Name','Q_ref_var');
 end
 seed=load(fullfile(r,'parameters','initial_states','bw_wind_grid_seed.mat'),'op');in=Simulink.SimulationInput(m);in=in.setVariable('faultSeed',seed.op).setBlockParameter([m '/Close permit'],'Value','1').setModelParameter('SimscapeUseOperatingPoints','on','SimscapeOperatingPoint','faultSeed','StopTime','3.6','ReturnWorkspaceOutputs','on','CaptureErrors','on');
 if smokeOnly
  o=sim(in.setModelParameter('StopTime','.003'));assert(isempty(o.ErrorMessage),'%s',o.ErrorMessage);assert(o.integration_sm.Time(end)>=.003-1e-9);R.state='smoke_only';record;clear cl o;continue
 end
 o=sim(in);save(fullfile(d,[tag '.mat']),'o','-v7.3');if ~isempty(o.ErrorMessage),error('%s',o.ErrorMessage);end
 R.zero=measureZero(o);R.metrics=p3_lvrt_metrics_new(o);R.metrics.clearance_reference='LVRT comparability uses original trip command; post-extinction extrema also reported separately.';
 R.state='completed';R.pass=R.metrics.pass && R.zero.evidence_pass;record;
 catch ME,R.pass=false;R.state='failed';R.error=getReport(ME,'extended','hyperlinks','off');record;end
 clear cl o
end
 function record
  fid=fopen(fullfile(d,[tag '.json.tmp']),'w');assert(fid>=0);fprintf(fid,'%s',jsonencode(R));fclose(fid);movefile(fullfile(d,[tag '.json.tmp']),fullfile(d,[tag '.json']),'f');
 end
end
function wire(m,a,b),add_line(m,a,b,'autorouting','on');end
function z=measureZero(o)
% Resolution-limited extinction; do not equate a transient sampled zero with open.
s=o.fault_abc_A;t=s.Time(:);if s.IsTimeFirst,i=reshape(s.Data,numel(t),3);else,i=reshape(s.Data,3,numel(t)).';end
u=o.fault_open_command;op=u.Time(find(u.Time>2.65 & squeeze(u.Data)>.5,1));z.command_s=op;
assert(isscalar(op)&&abs(op-2.8)<.001 && t(end)>op+.10);
z.fixed_step_s=median(diff(t));z.phase={'A','B','C'};tol=2;z.leakage_band_A=tol;z.evidence_pass=true;
for a=1:3
 x=i(:,a);pre=t>op-.02&t<op;z.pre_peak_A(a)=max(abs(x(pre)));idx=find(t>=op & abs(x)>tol,1,'last');
 if isempty(idx),idx=find(t<op,1,'last');end
 assert(idx+1<=numel(t) && idx>3);j=idx+1;z.extinct_by_s(a)=t(j);z.extinction_bracket_s(a,:)=[t(idx) t(j)];z.command_delay_ms(a)=1e3*(t(j)-op);
 z.last_on_A(a)=x(idx);z.first_off_A(a)=x(j);z.post_leakage_peak_A(a)=max(abs(x(j:end)));
 % Check decaying current close to zero relative to the last half-cycle peak.
 z.final_slope_A_per_s(a)=median(diff(x(idx-3:idx))./diff(t(idx-3:idx)));
 z.extrapolated_zero_s(a)=t(idx)-x(idx)/z.final_slope_A_per_s(a);
 z.local_zero_residual_A(a)=abs(x(idx))/max(z.pre_peak_A(a),1);
 z.evidence_pass=z.evidence_pass && z.pre_peak_A(a)>100 && abs(x(idx))<.05*z.pre_peak_A(a) && ...
   abs(z.extrapolated_zero_s(a)-t(j))<4*z.fixed_step_s && z.command_delay_ms(a)>=-.05 && z.command_delay_ms(a)<12 && z.post_leakage_peak_A(a)<=tol;
end
z.phase_spread_ms=1e3*range(z.extinct_by_s);z.evidence_pass=z.evidence_pass&&z.phase_spread_ms>1;
sm=o.integration_sm;z.post_last_extinction_peak_pu=max(sm.Data(sm.Time>=max(z.extinct_by_s),3))/1e4;
end
