function report=validate_grid_supported_postsettling_dynamics(selection)
%VALIDATE_GRID_SUPPORTED_POSTSETTLING_DYNAMICS Conditional dynamics, NOT cold start.
% Every case retains its complete 0..1.25 s trace. Only the separately labelled
% dynamic window starts at 0.5 s; the cold-start test remains failed.
if nargin<1,selection={};end
root=setup_v2_paths;folder=fullfile(root,'artifacts','grid_supported_integration');
Simulink.fileGenControl('set','CacheFolder',fullfile(tempdir,'pvwind_grid_supported_cache'), ...
 'CodeGenFolder',fullfile(tempdir,'pvwind_grid_supported_cache'));
m='GRID_SUPPORTED_PV_WIND_R1';load_system(fullfile(root,'models','integration',[m '.slx']));
windStep=[m '/Wind Resource/01 Wind Turbine Two-Mass Aerodynamics/Wind Speed Step'];
report=struct('cold_start_accepted',false,'islanding_tested',false, ...
 'dynamic_evaluation_starts_s',0.5,'disturbance_time_s',0.7, ...
 'cases',struct());
cases={'steady','pv_dispatch','wind_step','pv_q_step','frequency_step'};
for k=1:numel(cases)
 name=cases{k};if ~isempty(selection)&&~ismember(name,selection),continue,end
 fprintf('GRID_SUPPORTED_WARM_CASE_START=%s\n',name);started=tic;
 try
  in=Simulink.SimulationInput(m);
  in=in.setModelParameter('StartTime','0','StopTime','1.25','SimulationMode','accelerator');
  in=in.setBlockParameter([m '/PV Command/P Increment'],'Time','10');
  in=in.setBlockParameter(windStep,'Time','10');
  switch name
   case 'pv_dispatch',in=in.setBlockParameter([m '/PV Command/P Increment'],'Time','0.7');
   case 'wind_step',in=in.setBlockParameter(windStep,'Time','0.7');
   case 'pv_q_step'
    in=in.setBlockParameter([m '/PV Command/Q Reference'],'Time','0.7');
    in=in.setBlockParameter([m '/PV Command/Q Reference'],'After','1e6');
   case 'frequency_step'
    in=in.setBlockParameter([m '/Strong Synchronous Machine - Always Connected/Governor Speed'],'Time','0.7');
    in=in.setBlockParameter([m '/Strong Synchronous Machine - Always Connected/Governor Speed'],'After','2*pi*50.2');
  end
  out=sim(in);evidence=pack(out);save(fullfile(folder,['postsettling_' name '.mat']),'evidence');
  R=metrics(out,name);report.cases.(name)=struct('pass',true,'elapsed_s',toc(started),'metrics',R);
  plot_case(out,name,folder);
 catch ME
  report.cases.(name)=struct('pass',false,'elapsed_s',toc(started),'error',getReport(ME,'extended','hyperlinks','off'));
  fprintf('GRID_SUPPORTED_WARM_CASE_ERROR=%s\n%s\n',name,report.cases.(name).error);
 end
 fid=fopen(fullfile(folder,'postsettling_dynamics_results.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
 fprintf('GRID_SUPPORTED_WARM_CASE_END=%s PASS=%d\n',name,report.cases.(name).pass);
 if ~report.cases.(name).pass,break,end
end
requested=cases;if ~isempty(selection),requested=selection;end
report.requested_cases_pass=all(cellfun(@(n)isfield(report.cases,n)&&report.cases.(n).pass,requested));
fid=fopen(fullfile(folder,'postsettling_dynamics_results.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
assert(report.requested_cases_pass,'Warm operating-point dynamics failed; cold start remains unaccepted.');
fprintf('GRID_SUPPORTED_POSTSETTLING_DYNAMICS_PASS=1 COLD_START_ACCEPTANCE=0\n');
end

function R=metrics(out,name)
s=out.integration_sm;p=out.integration_pv;w=out.integration_wind;
initial=mean_window(s,[0.44 0.5]);preP=mean_window(p,[0.44 0.5]);preW=mean_window(w,[0.44 0.5]);
assert(initial(3)>9500&&initial(3)<10500,'Pre-event bus operating point not established');
assert(abs(preP(9)-1500)<75&&abs(preW(9)-1500)<75,'Pre-event DC regulation not settled');
S=mean_window(s,[1.15 1.25]);P=mean_window(p,[1.15 1.25]);W=mean_window(w,[1.15 1.25]);
assert(all(isfinite([s.Data(:);p.Data(:);w.Data(:)])),'Nonfinite physical telemetry');
R=struct('P_pv_W',P(1),'Q_pv_var',P(2),'P_wind_W',W(1),'Q_wind_var',W(2), ...
 'P_machine_W',S(1),'Q_machine_var',S(2),'Vpcc_V',S(3),'Vmax_V',max(s.Data(s.Time>=0.5,3)), ...
 'Vmin_V',min(s.Data(s.Time>=0.5,3)),'pv_Vdc_V',P(9),'wind_Vdc_V',W(9), ...
 'pv_f_Hz',P(4),'wind_f_Hz',W(4),'balance_residual_W',S(1)+P(1)+W(1)-5e6);
R.cold_start_bus_raw_peak_V=max(s.Data(:,3));R.cold_start_accepted=false;
assert(R.Vmax_V<11500&&R.Vmin_V>8500,'Warm grid voltage is out of range');
assert(abs(R.balance_residual_W)<0.1e6,'Warm common-bus power balance failed');
assert(abs(P(9)-1500)<75&&abs(W(9)-1500)<75,'DC regulation failed');
targetP=2e6;if strcmp(name,'pv_dispatch'),targetP=3e6;end
assert(abs(P(1)-targetP)<0.08*targetP,'PV P tracking failed');
targetQ=0;if strcmp(name,'pv_q_step'),targetQ=1e6;end
assert(abs(P(2)-targetQ)<0.15e6,'PV Q tracking failed');
if strcmp(name,'pv_dispatch')
 a=mean_window(p,[0.56 0.64]);b=mean_window(w,[0.56 0.64]);c=mean_window(s,[0.56 0.64]);
 R.delta_P_pv_W=P(1)-a(1);R.delta_P_wind_W=W(1)-b(1);R.delta_P_machine_W=S(1)-c(1);
 assert(R.delta_P_pv_W>0.7e6&&R.delta_P_machine_W<-0.7e6,'Machine did not balance PV increase');
 assert(abs(R.delta_P_wind_W)<0.15e6,'PV disturbance excessively changed Wind power');
end
if strcmp(name,'wind_step')
 a=getlog(out.logsout,'P_aero_W');R.aero_before_W=mean_window(a,[0.56 0.64]);R.aero_after_W=mean_window(a,[1.15 1.25]);
 assert(R.aero_after_W>1.2*R.aero_before_W,'Wind aerodynamic event not delivered');
end
targetF=50;
if strcmp(name,'frequency_step'),targetF=50.2;end
R.bus_frequency_Hz=bus_frequency(out.integration_bus_vabc,[1.15 1.25]);
assert(abs(R.bus_frequency_Hz-targetF)<0.03,'Machine frequency does not match imposed event');
assert(abs(P(4)-R.bus_frequency_Hz)<0.05&&abs(W(4)-R.bus_frequency_Hz)<0.05,'Local PLL tracking failed');
fprintf('GRID_SUPPORTED_WARM_METRICS=%s\n',jsonencode(R));
end
function a=matrix(x)
if x.IsTimeFirst,a=reshape(x.Data,numel(x.Time),[]);else,a=reshape(x.Data,[],numel(x.Time)).';end
end
function v=mean_window(x,w)
t=x.Time(:);a=matrix(x);k=t>=w(1)&t<=w(2);assert(nnz(k)>1);v=trapz(t(k),a(k,:),1)/(max(t(k))-min(t(k)));
end
function f=bus_frequency(x,w)
t=x.Time(:);v=matrix(x);theta=unwrap(atan2((v(:,2)-v(:,3))/sqrt(3),(2*v(:,1)-v(:,2)-v(:,3))/3));
k=t>=w(1)&t<=w(2);p=polyfit(t(k),theta(k),1);f=p(1)/(2*pi);
end
function x=getlog(logs,name)
for k=1:logs.numElements,e=logs{k};if strcmp(e.Name,name),x=e.Values;return,end,end
error('Missing log %s',name);
end
function e=pack(out)
e=struct('sm',out.integration_sm,'pv',out.integration_pv,'wind',out.integration_wind, ...
 'bus',out.integration_bus_vabc,'pv_dynamic',out.pv_dynamic, ...
 'pv_boost_current',out.pv_boost_current,'pv_vsc_dc_current',out.pv_vsc_dc_current);
for n={'P_aero_W','P_msc_W','omega_turbine_rad_s','omega_generator_rad_s'}
 try,e.(n{1})=getlog(out.logsout,n{1});catch,end
end
end
function plot_case(out,name,folder)
fig=figure('Visible','off','Position',[50 50 1200 800]);cleanup=onCleanup(@()close(fig));
s=out.integration_sm;p=out.integration_pv;w=out.integration_wind;
subplot(2,2,1);plot(s.Time,s.Data(:,1)/1e6,p.Time,p.Data(:,1)/1e6,w.Time,w.Data(:,1)/1e6);legend('Synchronous machine','PV','Wind');ylabel('P / MW');grid on;
subplot(2,2,2);plot(s.Time,s.Data(:,3)/1000);ylabel('PCC / kV');grid on;
subplot(2,2,3);plot(p.Time,p.Data(:,9),w.Time,w.Data(:,9));legend('PV','Wind');ylabel('Vdc / V');grid on;
subplot(2,2,4);plot(p.Time,p.Data(:,4),w.Time,w.Data(:,4));legend('PV PLL','Wind PLL');ylabel('Frequency / Hz');grid on;
for k=1:4,subplot(2,2,k);xlim([0.5 1.25]);xlabel('Time / s');end
sgtitle(['Post-settling dynamics only: ' strrep(name,'_',' ')]);exportgraphics(fig,fullfile(folder,['postsettling_' name '.png']),'Resolution',130);
end
