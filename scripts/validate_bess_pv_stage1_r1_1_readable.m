% Run the unchanged Stage-1 functional acceptance against the R1.1 model.
STAGE1_MODEL_OVERRIDE='BESS_GFM_PV_GFL_Stage1_R1_1_Readable';
run(fullfile(fileparts(mfilename('fullpath')),'validate_bess_pv_stage1_r1.m'));
