% Functional acceptance: the readability-only derivative must reproduce R2.
run(fullfile(fileparts(mfilename('fullpath')),'validate_stage2_resource_api.m'));
STAGE2_MODEL_OVERRIDE='BESS_PV_WIND_STAGE2_R2_1_READABLE';
run(fullfile(fileparts(mfilename('fullpath')),'validate_bess_pv_wind_stage2_r1.m'));
fprintf('BESS_PV_WIND_STAGE2_R2_1_READABLE_PASS=1\n');
