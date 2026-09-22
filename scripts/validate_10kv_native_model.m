% Regression check for the generated R2026a-native architecture model.
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
run(fullfile(scriptDir, 'init_10kv_architecture.m'));
modelFile = fullfile(projectRoot, 'build', 'PV_Wind_BESS_10kV_ACCoupled_R2026a.slx');
modelName = 'PV_Wind_BESS_10kV_ACCoupled_R2026a';

load_system(modelFile);
requiredBlocks = { ...
    'PV_GFL_PCS_690V', 'BESS_GFM_PCS_690V', 'Wind_PCS_690V', ...
    'T_PV_0p69_10kV', 'T_BESS_0p69_10kV', 'T_Wind_0p69_10kV', ...
    'T_Load_10_0p4kV', 'Main_Load_5MW_400V'};
for k = 1:numel(requiredBlocks)
    assert(getSimulinkBlockHandle([modelName '/' requiredBlocks{k}]) ~= -1, ...
        'Required R2 block is missing: %s', requiredBlocks{k});
end
assert(getSimulinkBlockHandle([modelName '/PV_BESS_PCS_690V']) == -1, ...
    'Legacy common-DC PV+BESS equivalent is still present.');
assert(abs(P.base.Vdc_V - 1295.780074) < 1e-3, 'Unexpected R2 DC-link base.');
fprintf('R2_STRUCTURE_OK=1\n');
set_param(modelName, 'SimulationCommand', 'update');
fprintf('UPDATE_OK=1\n');

if ~exist('RUN_TRANSIENT', 'var')
    RUN_TRANSIENT = false;
end
if RUN_TRANSIENT
    out = sim(modelName, 'StopTime', '0.01');
    assert(abs(out.tout(end)-0.01) < 1e-9, 'Transient run did not reach 10 ms.');
    fprintf('TRANSIENT_OK=1 END_TIME=%.6f\n', out.tout(end));
else
    fprintf('TRANSIENT_SKIPPED=1 (set RUN_TRANSIENT=true to execute 10 ms run)\n');
end

close_system(modelName, 0);
