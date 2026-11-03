function p3_multi_island(k,d,smokeOnly)
if nargin<3,smokeOnly=false;end
% Identical physical weather & load. k only enables the outer dispatch increment.
assert(ismember(k,[0 1])&&isfolder(d));r=setup_v2_paths;m='PV_WIND_BESS_ISLAND_R1';tag={'local','coordinated'};tag=tag{k+1};assert(~isfile(fullfile(d,[tag '.json'])));R=struct('stage',tag,'state','building','pid',feature('getpid'),'scope','warm island; mild physical inputs');record;
try
 tmp=fullfile(d,['cache_' tag]);Simulink.fileGenControl('set','CacheFolder',fullfile(tmp,'sim'),'CodeGenFolder',fullfile(tmp,'code'),'createDir',true);
 load_system(p3_release_model_path(r,m));cl=onCleanup(@()close_system(m,0));s=[m '/BESS Synchronism and Dispatch'];trip=2.8;stop=4.4;
 set_param([m '/Island at 1.8 s'],'Time',num2str(trip));set_param([m '/PV Command/Q Reference'],'Time','1.3','After','2e6*tan(acos(.9))');set_param([m '/Close permit'],'Value','1');
 set_param([m '/BESS P request'],'VariableName','[0 0;1.25 1.10e6;6 1.10e6]');set_param([m '/BESS Q request'],'VariableName','[0 0;1.40 0.55e6;6 0.55e6]');
 if true
  add_block('simulink/Sources/In1',[s '/Utility open command'],'Port','7');add_block('simulink/Discrete/Unit Delay',[m '/Registered utility release'],'SampleTime','.001','InitialCondition','0');wire(m,'Gate double/1','Registered utility release/1');wire(m,'Registered utility release/1','BESS Synchronism and Dispatch/7');set_param([s '/Inputs'],'Inputs','8');wire(s,'Utility open command/1','Inputs/8');
  rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[s '/Synchrocheck and latch']);assert(numel(ch)==1);old=ch.Script;eq='trim=trim+T*8e-5*(qref-u(11));';assert(contains(old,eq)&&contains(old,'reshape(u,11,1)'));ch.Script=strrep(strrep(old,'reshape(u,11,1)','reshape(u,12,1)'),eq,sprintf('if u(12)>.5\n trim=trim+T*min(90,max(-90,750*(1-vb)));\nelse\n %s\nend',eq));
 end

 stop=10.1;
 % The donor deferred its +1 MW commissioning step to t=10, which was
 % outside older tests but inside this one. Only weather/load may change.
 set_param([m '/PV Command/P Increment'],'Before','0','After','0');
 set_param([m '/Wind Command/P Increment'],'Before','0','After','0');
 logv([m '/PV Command'],'P Reference/1','multi_pv_schedule_W');
 logv([m '/Wind Command'],'P Reference/1','multi_wind_schedule_W');
 % The linked helper above joins the exact same predispatch and island-voltage
 % trim as the commissioned case. Release feedback is recorded independently.
 logv(m,'Gate double/1','utility_release');
 a=find_system([m '/PV Resource'],'Name','Irradiance','BlockType','Constant');assert(numel(a)==1);ap=get_param(a{1},'Parent');
 replace_block(ap,'SearchDepth',1,'Name','Irradiance','simulink/Sources/From Workspace','noprompt');set_param(a{1},'VariableName','multiSunProfile','Interpolate','on','OutputAfterFinalValue','Holding final value');logv(ap,'Irradiance/1','multi_sun');
 wind=[m '/Wind Resource/01 Wind Turbine Two-Mass Aerodynamics'];assert(getSimulinkBlockHandle([wind '/Wind Speed Profile'])>0);set_param([wind '/Wind Speed Step'],'Time','6.9','After','-.3');logv(wind,'Wind Speed Profile/1','multi_wind_mps');
 grid=[m '/Synchronous Machine PCC'];br=[m '/Small load breaker'];loadz=[m '/100kW + 30kvar load'];me=[m '/Bank VI'];ng=[m '/Bank neutral'];
 add_block([m '/BESS intertie breaker'],br);add_block([m '/Intertie VI'],me);add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)',loadz,'component_structure','ee.enum.rlc.structure.SeriesRL','R','1e8*1e5/(1e5^2+3e4^2)','L','1e8*3e4/(1e5^2+3e4^2)/(2*pi*50)');add_block(sprintf('ee_lib/Connectors &\nReferences/Grounded Neutral\n(Three-Phase)'),ng);
 conn(m,grid,'RConn',1,br,'LConn',2);conn(m,br,'RConn',1,me,'LConn',1);conn(m,me,'RConn',3,loadz,'LConn',1);conn(m,loadz,'RConn',1,ng,'LConn',1);
 add_block([m '/Intertie amps'],[m '/Measured bank current']);conn(m,me,'RConn',2,[m '/Measured bank current'],'LConn',1);logv(m,'Measured bank current/1','multi_bank_amps');
 add_block('simulink/Sources/Step',[m '/Connect small RL'],'Time','5.3','Before','1','After','0');add_block([m '/Intertie command PS'],[m '/Small RL gate']);wire(m,'Connect small RL/1','Small RL gate/1');conn(m,[m '/Small RL gate'],'RConn',1,br,'LConn',1);logv(m,'Connect small RL/1','multi_bank_open');
 % Remove inherited PV-only coordinator from BOTH sides. Dynamic BESS power
 % selected only from local measurements at the AC boundary, no disturbance clock.
 delete_line(m,'Effective BESS request/1','BESS Synchronism and Dispatch/3');
 for pair={'PV','Wind'}
  n=pair{1};add_block('simulink/Signal Routing/Bus Selector',[m '/' n ' P observed'],'OutputSignals','P_W');wire(m,[n ' Resource/1'],[n ' P observed/1']);
 end
 add_block('simulink/Math Operations/Dot Product',[m '/Measured load addition W']);wire(m,'Synchronous Machine PCC/2','Measured load addition W/1');wire(m,'Measured bank current/1','Measured load addition W/2');
 add_block('simulink/Math Operations/Sum',[m '/AC residual'],'Inputs','+--');wire(m,'Measured load addition W/1','AC residual/1');wire(m,'PV P observed/1','AC residual/2');wire(m,'Wind P observed/1','AC residual/3');
 add_block('simulink/Discrete/Unit Delay',[m '/Last residual sample'],'SampleTime','.005','InitialCondition','-3.9e6');wire(m,'AC residual/1','Last residual sample/1');
 add_block('simulink/Sources/Step',[m '/Arm after transfer'],'Time','3.5','Before','0','After','1','SampleTime','.005');
 add_block('simulink/User-Defined Functions/MATLAB Function',[m '/Residual dispatch']);rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[m '/Residual dispatch']);ch.Script=sprintf('function y=dispatch(x,arm)\npersistent anchor filt\nif isempty(anchor),anchor=x;filt=0;end\nif arm==0,anchor=x;filt=0;end\nfilt=filt+.005/(.15+.005)*(x-anchor-filt);\ny=max(-250000,min(250000,filt));\nend');
 wire(m,'Last residual sample/1','Residual dispatch/1');wire(m,'Arm after transfer/1','Residual dispatch/2');add_block('simulink/Math Operations/Gain',[m '/Upper layer enable'],'Gain',num2str(k));wire(m,'Residual dispatch/1','Upper layer enable/1');logv(m,'Upper layer enable/1','multi_coord_W');
 add_block('simulink/Math Operations/Sum',[m '/Island P reference'],'Inputs','++');wire(m,'BESS P request/1','Island P reference/1');wire(m,'Upper layer enable/1','Island P reference/2');wire(m,'Island P reference/1','BESS Synchronism and Dispatch/3');
 seed=load(fullfile(r,'parameters','initial_states','bw_wind_grid_seed.mat'),'op');in=Simulink.SimulationInput(m);in=in.setVariable('multiSunProfile',[0 1000;3.7 1000;3.75 950;8.5 950;8.55 1000;11 1000]).setVariable('islandSeed',seed.op).setModelParameter('SimscapeUseOperatingPoints','on','SimscapeOperatingPoint','islandSeed','StopTime',num2str(stop),'ReturnWorkspaceOutputs','on','CaptureErrors','on');
 if smokeOnly
  o=sim(in.setModelParameter('StopTime','.003'));assert(isempty(o.ErrorMessage),'%s',o.ErrorMessage);assert(o.integration_sm.Time(end)>=.003-1e-9);R.state='smoke_only';record;return
 end
 R.state='simulating';record;o=sim(in);save(fullfile(d,[tag '.mat']),'o','-v7.3');if ~isempty(o.ErrorMessage),error('%s',o.ErrorMessage);end
 R.metrics=p3_island_multi_metrics(o);R.schedule_verified=all(abs(o.multi_pv_schedule_W.Data(:)-2e6)<1)&&all(abs(o.multi_wind_schedule_W.Data(:)-2e6)<1);
 R.pass=R.schedule_verified&&R.metrics.pass;R.state='completed';record;
catch ME,R.state='failed';R.error=getReport(ME,'extended','hyperlinks','off');record;rethrow(ME);end
 function record,path=fullfile(d,[tag '.json']);fid=fopen([path '.tmp'],'w');fprintf(fid,'%s',jsonencode(R));fclose(fid);movefile([path '.tmp'],path,'f');end
end
function logv(m,src,n),add_block('simulink/Sinks/To Workspace',[m '/' n],'VariableName',n,'SaveFormat','Timeseries');wire(m,src,[n '/1']);end
function wire(m,a,b),add_line(m,a,b,'autorouting','on');end
function conn(m,a,ap,ai,b,bp,bi),add_line(m,v2_port(a,ap,ai),v2_port(b,bp,bi),'autorouting','on');end
