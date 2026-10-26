%RUN_ALL_CHECKS Validate both wind-turbine course models.
root=fileparts(fileparts(mfilename('fullpath')));
old=pwd;
cleanup=onCleanup(@()cd(old));
cd(root);

fprintf('\n=== Direct-drive PMSG SPWM model ===\n');
run(fullfile(root,'parameters','init_wind_course_spwm_r2.m'));
run(fullfile(root,'scripts','validate_wind_course_spwm_r2.m'));

fprintf('\n=== Reused-plant DFIG average model ===\n');
run(fullfile(root,'parameters','init_wind_dfig_reused_r2.m'));
run(fullfile(root,'scripts','validate_wind_dfig_reused_r2.m'));

fprintf('\nWIND_COURSE_ALL_CHECKS_OK=1\n');
clear cleanup
