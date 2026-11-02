function result=diagnose_grid_supported_initialization()
%DIAGNOSE_GRID_SUPPORTED_INITIALIZATION Compare startup at fixed physical controls.
root=setup_v2_paths;folder=fullfile(root,'artifacts','grid_supported_integration');
cache=fullfile(tempdir,'pvwind_grid_supported_cache');
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache);
m='GRID_SUPPORTED_WIND_R1';load_system(fullfile(root,'models','integration',[m '.slx']));
result=struct();
for k=1:3
 in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','0.003','SimulationMode','normal');
 if k==2
  machine=[m '/Strong Synchronous Machine - Always Connected/Synchronous Machine'];
  in=in.setBlockParameter(machine,'Pt0','5e6');in=in.setBlockParameter(machine,'Qt0','1.5e6');
 elseif k==3
  in=in.setModelParameter('SolverType','Variable-step','Solver','ode23t','MaxStep','1e-5');
 end
 out=sim(in);s=out.integration_sm;w=out.integration_wind;
 label={'as_supplied','matched_machine_load','variable_step'};a=reshape(s.Data,numel(s.Time),[]);
 t=s.Time;metrics=struct('time',t(1:min(8,end)), ...
  'first_samples',a(1:min(8,end),:),'Vmax',max(a(:,3)), ...
  'Vmax_after_20us',max(a(t>2e-5,3)),'Vdc0',w.Data(1,9));
 result.(label{k})=metrics;fprintf('INITIALIZATION_DIAG_%s=%s\n',label{k},jsonencode(metrics));
 evidence=struct('sm',s,'wind',w,'bus',out.integration_bus_vabc);save(fullfile(folder,['initial_' label{k} '.mat']),'evidence');
end
fid=fopen(fullfile(folder,'initialization_diagnosis.json'),'w');fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));fclose(fid);
end
