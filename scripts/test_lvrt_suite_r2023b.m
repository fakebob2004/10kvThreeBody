% test_lvrt_suite_r2023b.m
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
addpath(fullfile(root, 'scripts'));
setup_v2_paths;

fprintf('=== STARTING LVRT COORDINATION SUITE IN R2023b ===\n');
t0 = tic;
res = run_stage2_lvrt_coordination_suite(false);
totalTime = toc(t0);
fprintf('=== COMPLETED LVRT COORDINATION SUITE IN R2023b (Total: %.1f s) ===\n', totalTime);
