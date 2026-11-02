function report=diagnose_grid_supported_joint_initialization()
%DIAGNOSE_GRID_SUPPORTED_JOINT_INITIALIZATION Include passive PV filter in initial flow.
root=setup_v2_paths;init_grid_supported_integration;
folder=fullfile(root,'artifacts','grid_supported_integration');
Simulink.fileGenControl('set','CacheFolder',fullfile(tempdir,'pvwind_grid_supported_cache'), ...
 'CodeGenFolder',fullfile(tempdir,'pvwind_grid_supported_cache'));
m='GRID_SUPPORTED_PV_WIND_R1';load_system(fullfile(root,'models','integration',[m '.slx']));
C=evalin('base','V2');pv=C.PV;
z=pv.filter.Rd_ohm+pv.filter.R2_ohm+pv.transformer.R_pu*690^2/pv.transformer.S_VA ...
 +1i*(2*pi*50*pv.filter.L2_H-1/(2*pi*50*pv.filter.C_F));
shuntS=690^2/conj(z);report=struct('calculated_passive_PQ_VA',[real(shuntS) imag(shuntS)]);
matched=load(fullfile(folder,'initial_matched_machine_load.mat'),'evidence');
bus=matched.evidence.bus;
if bus.IsTimeFirst,vll0=bus.Data(1,:);else,vll0=bus.Data(:,:,1);end
% The PV builder uses Matrix(u*K), so the column-vector equivalent is K'.
vph0=[1 -1 0;0 1 -1;-1 0 1].'*vll0(:)*690/10000/3;
fprintf('GRID_INITIAL_PHASE_VOLTS=%s\n',mat2str(vph0));
names={'load_only','load_plus_passive_filter','initialized_filter_voltage'};
for k=1:3
 in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','0.003','SimulationMode','normal');
 machine=[m '/Strong Synchronous Machine - Always Connected/Synchronous Machine'];
 if k==2
  in=in.setBlockParameter(machine,'Pt0',num2str(5e6+real(shuntS),17));
  in=in.setBlockParameter(machine,'Qt0',num2str(1.5e6+imag(shuntS),17));
 elseif k==3
  cf=[m '/PV Resource/03 AC Interface/Damped Shunt C'];
  in=in.setBlockParameter(cf,'VC_specify','on');
  in=in.setBlockParameter(cf,'VC',mat2str(vph0.'));
 end
 try
  out=sim(in);s=out.integration_sm;p=out.integration_pv;w=out.integration_wind;
  metrics=struct('Vmax',max(s.Data(:,3)),'Vmax_after_20us',max(s.Data(s.Time>2e-5,3)), ...
   'PV_Vdc0',p.Data(1,9),'Wind_Vdc0',w.Data(1,9),'time',s.Time(1:5),'first_samples',s.Data(1:5,:));
  report.(names{k})=metrics;
  evidence=struct('sm',s,'pv',p,'wind',w,'bus',out.integration_bus_vabc);
  save(fullfile(folder,['joint_initial_' names{k} '.mat']),'evidence');
  fprintf('JOINT_INITIAL_DIAG_%s=%s\n',names{k},jsonencode(metrics));
 catch ME
  report.(names{k})=struct('error',getReport(ME,'extended','hyperlinks','off'));
  fprintf('JOINT_INITIAL_ERROR=%s\n',report.(names{k}).error);
 end
 fid=fopen(fullfile(folder,'joint_initialization_diagnosis.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
end
end
