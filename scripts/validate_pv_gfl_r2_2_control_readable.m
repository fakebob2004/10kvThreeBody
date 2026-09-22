% Run unchanged Stage-1 functional acceptance on the PV readability derivative.
STAGE1_MODEL_OVERRIDE='BESS_GFM_PV_GFL_Stage1_R1_2_PV_CONTROL_READABLE';
run(fullfile(fileparts(mfilename('fullpath')),'validate_bess_pv_stage1_r1.m'));
fprintf('PV_GFL_R2_2_CONTROL_READABLE_ACCEPTANCE_PASS=1\n');
