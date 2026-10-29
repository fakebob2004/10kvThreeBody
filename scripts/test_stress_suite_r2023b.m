% test_stress_suite_r2023b.m
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
addpath(fullfile(root, 'scripts'));
setup_v2_paths;

fprintf('=== STARTING COORDINATION STRESS SUITE IN R2023b ===\n');
t0 = tic;
res = run_stage2_coordination_stress_suite();
totalTime = toc(t0);
fprintf('=== COMPLETED COORDINATION STRESS SUITE IN R2023b (Total: %.1f s) ===\n', totalTime);
