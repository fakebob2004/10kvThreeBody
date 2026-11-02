function report=validate_grid_supported_integration(selection)
%VALIDATE_GRID_SUPPORTED_INTEGRATION Staged tests with the machine always present.
if nargin<1,selection={};end
root=setup_v2_paths;folder=fullfile(root,'artifacts','grid_supported_integration');
if ~exist(folder,'dir'),mkdir(folder);end
cache=fullfile(tempdir,'pvwind_grid_supported_cache');if ~exist(cache,'dir'),mkdir(cache);end
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache);
report=struct('islanding_tested',false,'machine','100 MVA fixed-speed synchronous machine', ...
 'wind_gsc','averaged-switch bridge','cases',struct());
previous=fullfile(folder,'integration_results.json');
if ~isempty(selection)&&isfile(previous),report=jsondecode(fileread(previous));end
cases={'wind_smoke','wind_local_pll','joint_smoke','pv_dispatch','wind_step','pv_q_step','frequency_step'};
for k=1:numel(cases)
 name=cases{k};if ~isempty(selection)&&~ismember(name,selection),continue,end
 onlyWind=startsWith(name,'wind_')&&strcmp(name,'wind_local_pll')||strcmp(name,'wind_smoke');
 if onlyWind,m='GRID_SUPPORTED_WIND_R1';else,m='GRID_SUPPORTED_PV_WIND_R1';end
 fprintf('\nGRID_SUPPORTED_CASE_START=%s\n',name);started=tic;
 try
  load_system(fullfile(root,'models','integration',[m '.slx']));
  assert(getSimulinkBlockHandle([m '/Strong Synchronous Machine - Always Connected'])>0);
  assert(isempty(find_system(m,'LookUnderMasks','all','FollowLinks','on','Name','Grid Disconnect')));
  in=Simulink.SimulationInput(m);stop=1.05;
  in=in.setBlockParameter([m '/Wind Resource/01 Wind Turbine Two-Mass Aerodynamics/Wind Speed Step'],'Time','10');
  if ~onlyWind,in=in.setBlockParameter([m '/PV Command/P Increment'],'Time','10');end
  switch name
   case 'wind_smoke',stop=0.25;
   case 'joint_smoke',stop=0.45;
   case 'wind_local_pll',stop=0.40;
   case 'pv_dispatch',in=in.setBlockParameter([m '/PV Command/P Increment'],'Time','0.6');
   case 'wind_step',in=in.setBlockParameter([m '/Wind Resource/01 Wind Turbine Two-Mass Aerodynamics/Wind Speed Step'],'Time','0.6');
   case 'pv_q_step'
    in=in.setBlockParameter([m '/PV Command/Q Reference'],'Time','0.65');
    in=in.setBlockParameter([m '/PV Command/Q Reference'],'After','1e6');
   case 'frequency_step'
    in=in.setBlockParameter([m '/Strong Synchronous Machine - Always Connected/Governor Speed'],'Time','0.65');
    in=in.setBlockParameter([m '/Strong Synchronous Machine - Always Connected/Governor Speed'],'After','2*pi*50.2');
  end
  in=in.setModelParameter('StopTime',num2str(stop),'SimulationMode','accelerator');
  out=sim(in);evidence=compact_evidence(out,onlyWind);save(fullfile(folder,[name '.mat']),'evidence');
  metrics=analyze(out,name,onlyWind,stop);
  report.cases.(name)=struct('pass',true,'elapsed_s',toc(started),'metrics',metrics);
  draw_case(out,name,onlyWind,folder);
 catch ME
  report.cases.(name)=struct('pass',false,'elapsed_s',toc(started), ...
   'error',getReport(ME,'extended','hyperlinks','off'));
  fprintf('GRID_SUPPORTED_CASE_ERROR=%s\n%s\n',name,report.cases.(name).error);
 end
 write_report(folder,report);bdclose('all');
 fprintf('GRID_SUPPORTED_CASE_END=%s PASS=%d\n',name,report.cases.(name).pass);
 if ~report.cases.(name).pass,break,end % Do not advance after a failed stage.
end
requested=cases;if ~isempty(selection),requested=selection;end
report.requested_cases_pass=all(cellfun(@(n)isfield(report.cases,n)&&report.cases.(n).pass,requested));
report.all_cases_pass=all(cellfun(@(n)isfield(report.cases,n)&&report.cases.(n).pass,cases));
write_report(folder,report);
assert(report.requested_cases_pass,'Grid-supported integration did not pass all requested stages.');
fprintf('GRID_SUPPORTED_REQUESTED_STAGES_PASS=1\n');
end

function R=analyze(out,name,onlyWind,stop)
sm=out.integration_sm;wind=out.integration_wind;
assert(all(isfinite(sm.Data(:)))&&all(isfinite(wind.Data(:))),'Nonfinite physical telemetry');
tail=[max(0,stop-0.06) stop];W=window_mean(wind,tail);S=window_mean(sm,tail);
R=struct('P_wind_W',W(1),'Q_wind_var',W(2),'P_machine_W',S(1), ...
 'Q_machine_var',S(2),'Vpcc_V',S(3),'wind_Vdc_V',W(9), ...
 'wind_f_Hz',W(4),'wind_limit_factor',W(7));
R.wind_Vdc_min_V=min(wind.Data(:,9));R.wind_Vdc_max_V=max(wind.Data(:,9));
R.wind_initial_Vdc_V=wind.Data(1,9);
R.raw_bus_Vmax_V=max(sm.Data(:,3));R.raw_machine_abs_Pmax_W=max(abs(sm.Data(:,1)));
R.machine_present=true;R.machine_disconnected=false;
assert(R.raw_bus_Vmax_V<15000,'Unacceptable raw startup bus-voltage spike');
assert(abs(R.wind_initial_Vdc_V-1500)<75, ...
 'Wind cold-start initial Vdc %.2f V outside 1500 V +/-5%%',R.wind_initial_Vdc_V);
assert(S(3)>8500&&S(3)<11500,'PCC voltage is outside commissioning range');
assert(W(9)>1350&&W(9)<1650,'Wind steady DC voltage is outside commissioning range');
assert(W(1)>0.5e6,'Wind is not generating');
assert(abs(W(4)-50)<0.5,'Wind local PLL is not synchronized');
R.power_balance_residual_W=S(1)+W(1)-5e6;
if ~onlyWind
 pv=out.integration_pv;assert(all(isfinite(pv.Data(:))),'Nonfinite PV telemetry');P=window_mean(pv,tail);
 R.P_pv_W=P(1);R.Q_pv_var=P(2);R.pv_Vdc_V=P(9);R.pv_f_Hz=P(4);R.pv_limit_factor=P(7);
 R.pv_Vdc_min_V=min(pv.Data(:,9));R.pv_Vdc_max_V=max(pv.Data(:,9));
 assert(abs(pv.Data(1,9)-1500)<75,'PV cold-start initial Vdc outside 1500 V +/-5%%');
 R.power_balance_residual_W=R.power_balance_residual_W+P(1);
 if stop>0.5
  assert(abs(P(9)-1500)<75,'PV DC regulation failed');
  target=2e6;if strcmp(name,'pv_dispatch'),target=3e6;end
  assert(abs(P(1)-target)<0.08*target,'PV dispatch tracking failed');
 end
 if strcmp(name,'pv_dispatch')
  preW=window_mean(wind,[0.48 0.56]);preS=window_mean(sm,[0.48 0.56]);preP=window_mean(pv,[0.48 0.56]);
  R.delta_P_pv_W=P(1)-preP(1);R.delta_P_wind_W=W(1)-preW(1);R.delta_P_machine_W=S(1)-preS(1);
  assert(R.delta_P_pv_W>0.7e6,'PV dispatch step not delivered');
  assert(R.delta_P_machine_W<-0.7e6,'Synchronous machine did not balance the PV increase');
  assert(abs(R.delta_P_wind_W)<0.15e6,'PV dispatch disturbed the Wind power excessively');
 end
 if strcmp(name,'pv_q_step'),assert(abs(P(2)-1e6)<0.15e6,'PV Q step tracking failed');end
 if strcmp(name,'frequency_step')
  R.measured_bus_f_Hz=bus_frequency(out.integration_bus_vabc,tail);
  assert(abs(R.measured_bus_f_Hz-50.2)<0.03,'Machine frequency event not established');
  assert(abs(W(4)-R.measured_bus_f_Hz)<0.05,'Wind PLL did not follow the actual network');
  assert(abs(P(4)-R.measured_bus_f_Hz)<0.05,'PV PLL did not follow the actual network');
 end
end
if stop>0.5,assert(abs(R.power_balance_residual_W)<0.10e6,'Common-bus physical power balance failed');end
R.startup_initial_conditions_relaxed=true; % Explicitly retained source-side boundary.
if strcmp(name,'wind_step')
 pa=logged(out.logsout,'P_aero_W');R.aero_before_W=window_mean(pa,[0.48 0.56]);R.aero_after_W=window_mean(pa,[0.90 1.02]);
 assert(R.aero_after_W>1.2*R.aero_before_W,'Wind aerodynamic step not delivered');
end
fprintf('GRID_SUPPORTED_METRICS=%s\n',jsonencode(R));
end
function v=window_mean(x,w)
t=x.Time(:);a=reshape(x.Data,numel(t),[]);keep=t>=w(1)&t<=w(2);assert(any(keep));
v=trapz(t(keep),a(keep,:),1)/(t(find(keep,1,'last'))-t(find(keep,1,'first')));
end
function f=bus_frequency(x,w)
t=x.Time(:);
if x.IsTimeFirst,v=reshape(x.Data,numel(t),[]);else,v=reshape(x.Data,[],numel(t)).';end
theta=unwrap(atan2((v(:,2)-v(:,3))/sqrt(3),(2*v(:,1)-v(:,2)-v(:,3))/3));
k=t>=w(1)&t<=w(2);p=polyfit(t(k),theta(k),1);f=p(1)/(2*pi);
end
function x=logged(logs,name)
for k=1:logs.numElements,e=logs{k};if strcmp(e.Name,name),x=e.Values;return,end,end
error('Missing physical log %s',name);
end
function draw_case(out,name,onlyWind,folder)
fig=figure('Visible','off','Position',[50 50 1200 800]);cleanup=onCleanup(@()close(fig));
sm=out.integration_sm;w=out.integration_wind;
subplot(2,2,1);plot(sm.Time,sm.Data(:,1)/1e6,w.Time,w.Data(:,1)/1e6);hold on;
if ~onlyWind,p=out.integration_pv;plot(p.Time,p.Data(:,1)/1e6);legend('Machine','Wind','PV');else,legend('Machine','Wind');end
ylabel('Active power / MW');xlabel('Time / s');grid on;
subplot(2,2,2);plot(sm.Time,sm.Data(:,3)/1000);ylabel('10 kV bus / kV');xlabel('Time / s');grid on;
subplot(2,2,3);plot(w.Time,w.Data(:,9));hold on;if ~onlyWind,plot(p.Time,p.Data(:,9));legend('Wind','PV');end
ylabel('DC voltage / V');xlabel('Time / s');grid on;
subplot(2,2,4);plot(w.Time,w.Data(:,4));hold on;if ~onlyWind,plot(p.Time,p.Data(:,4));legend('Wind PLL','PV PLL');end
ylabel('Local frequency / Hz');xlabel('Time / s');grid on;
sgtitle(strrep(name,'_',' '));exportgraphics(fig,fullfile(folder,[name '.png']),'Resolution',130);
end
function write_report(folder,report)
fid=fopen(fullfile(folder,'integration_results.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
end

function evidence=compact_evidence(out,onlyWind)
evidence=struct('integration_sm',out.integration_sm,'integration_wind',out.integration_wind, ...
 'integration_bus_vabc',out.integration_bus_vabc);
if ~onlyWind
 evidence.integration_pv=out.integration_pv;evidence.pv_dynamic=out.pv_dynamic;
 evidence.pv_boost_current=out.pv_boost_current;evidence.pv_vsc_dc_current=out.pv_vsc_dc_current;
end
for name={'P_aero_W','P_msc_W','PMSG_id_A','PMSG_iq_A','omega_turbine_rad_s','omega_generator_rad_s'}
 try,evidence.(name{1})=logged(out.logsout,name{1});catch,end
end
end
