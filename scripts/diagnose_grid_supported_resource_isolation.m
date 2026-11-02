function result=diagnose_grid_supported_resource_isolation()
%DIAGNOSE_GRID_SUPPORTED_RESOURCE_ISOLATION Native PV vs same-grid PV+load, 3 ms.
root=setup_v2_paths;folder=fullfile(root,'artifacts','grid_supported_integration');
cache=fullfile(tempdir,'pvwind_grid_isolation_cache');if ~exist(cache,'dir'),mkdir(cache);end
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache);
result=struct();
m='pv_resource_dynamic_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','0.003','SimulationMode','normal');
out=sim(in);x=out.pv_dynamic;
result.native_pv=struct('initial_Vdc_V',x.Data(1,3),'raw_Vpcc_peak_V',max(x.Data(:,24)), ...
 'Vpcc_after_20us_peak_V',max(x.Data(x.Time>2e-5,24)));
close_system(m,0);
build_grid_supported_integration({'PV'});m='GRID_SUPPORTED_PV_R1';
load_system(fullfile(root,'models','integration',[m '.slx']));
in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','0.003','SimulationMode','normal');
out=sim(in);p=out.integration_pv;s=out.integration_sm;
result.pv_same_grid_and_load=struct('initial_Vdc_V',p.Data(1,9), ...
 'raw_Vpcc_peak_V',max(s.Data(:,3)),'Vpcc_after_20us_peak_V',max(s.Data(s.Time>2e-5,3)));
fid=fopen(fullfile(folder,'resource_isolation_diagnosis.json'),'w');fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));fclose(fid);
fprintf('RESOURCE_ISOLATION_DIAG=%s\n',jsonencode(result));
end
