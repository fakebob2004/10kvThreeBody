% R2 API must reproduce frozen R1 while coordinator is disabled.
run(fullfile(fileparts(mfilename('fullpath')),'validate_stage2_resource_api.m'));
STAGE2_MODEL_OVERRIDE='BESS_PV_WIND_STAGE2_R2_API';
run(fullfile(fileparts(mfilename('fullpath')),'validate_bess_pv_wind_stage2_r1.m'));
fprintf('BESS_PV_WIND_STAGE2_R2_API_BASELINE_PASS=1\n');
