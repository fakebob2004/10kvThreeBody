function report=collect_grid_supported_evidence()
%COLLECT_GRID_SUPPORTED_EVIDENCE Recheck physical PV DC charge from saved traces.
root=setup_v2_paths;folder=fullfile(root,'artifacts','grid_supported_integration');
report=jsondecode(fileread(fullfile(folder,'postsettling_dynamics_results.json')));
C=define_v2_parameters(false);names=fieldnames(report.cases);
for k=1:numel(names)
 name=names{k};assert(report.cases.(name).pass,'A requested dynamic case failed');
 data=load(fullfile(folder,['postsettling_' name '.mat']),'evidence');e=data.evidence;
 x=e.pv_dynamic;t=x.Time(:);a=x.Data;keep=t>=0.5;
 ib=interp1(e.pv_boost_current.Time,squeeze(e.pv_boost_current.Data),t(keep));
 iv=interp1(e.pv_vsc_dc_current.Time,squeeze(e.pv_vsc_dc_current.Data),t(keep));
 v=a(keep,3);charge=C.PV.dynamic.Cdc_F*(v-v(1))-cumtrapz(t(keep),ib-iv);
 residual=max(abs(charge));
 fprintf('POSTSETTLING_DC_CHARGE_%s_C=%.9g\n',name,residual);
 % Same physical charge-balance threshold as the supplied PV acceptance.
 assert(residual<max(5,0.05*C.PV.dynamic.Cdc_F*max(v)),'PV DC charge balance failed');
 report.cases.(name).metrics.pv_DC_charge_residual_C=residual;
 pv=e.pv;wind=e.wind;kp=pv.Time>=0.5;kw=wind.Time>=0.5;
 report.cases.(name).metrics.pv_pll_frequency_range_Hz=[min(pv.Data(kp,4)) max(pv.Data(kp,4))];
 report.cases.(name).metrics.wind_pll_frequency_range_Hz=[min(wind.Data(kw,4)) max(wind.Data(kw,4))];
 report.cases.(name).metrics.pv_Vdc_range_V=[min(pv.Data(kp,9)) max(pv.Data(kp,9))];
 report.cases.(name).metrics.wind_Vdc_range_V=[min(wind.Data(kw,9)) max(wind.Data(kw,9))];
 report.cases.(name).metrics.pv_actual_current_peak_A=max(hypot(a(keep,9),a(keep,10)));
end
report.BESS_integrated=false;report.coordinator_enabled=false;
report.result_scope='Conditional post-settling grid-supported dynamics, not cold start or island acceptance';
report.runtime_version=version;
fid=fopen(fullfile(folder,'postsettling_dynamics_results.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
startup=load(fullfile(folder,'postsettling_steady.mat'),'evidence');e=startup.evidence;
cold=struct('source_model','GRID_SUPPORTED_PV_WIND_R1', ...
 'assessment_method','Raw-startup gate reassessed on the retained direct-connected full trace; no new simulation', ...
 'pass',false,'raw_bus_peak_V',max(e.sm.Data(:,3)),'raw_bus_gate_V',15000, ...
 'PV_initial_Vdc_V',e.pv.Data(1,9),'Wind_initial_Vdc_V',e.wind.Data(1,9));
cold.raw_bus_pass=cold.raw_bus_peak_V<cold.raw_bus_gate_V;
cold.wind_dc_pass=abs(cold.Wind_initial_Vdc_V-1500)<75;
cold.pv_dc_pass=abs(cold.PV_initial_Vdc_V-1500)<75;
assert(~(cold.raw_bus_pass && cold.wind_dc_pass && cold.pv_dc_pass), ...
 'Raw voltage gates now pass. Rerun the complete cold-start suite to update acceptance.');
fid=fopen(fullfile(folder,'direct_cold_start_assessment.json'),'w');fprintf(fid,'%s',jsonencode(cold,PrettyPrint=true));fclose(fid);
small=struct('scope',report.result_scope,'islanding_tested',false,'cold_start_accepted',false,'direct_cold_start',cold, ...
 'components',jsondecode(fileread(fullfile(folder,'component_checks.json'))), ...
 'source_audit',jsondecode(fileread(fullfile(folder,'source_and_interface_audit.json'))),'dynamics',report);
target=fullfile(root,'docs','evidence','grid_supported');if ~exist(target,'dir'),mkdir(target);end
fid=fopen(fullfile(target,'results.json'),'w');fprintf(fid,'%s',jsonencode(small,PrettyPrint=true));fclose(fid);
fprintf('GRID_SUPPORTED_SAVED_EVIDENCE_PASS=1 COLD_START_ACCEPTANCE=0\n');
end
