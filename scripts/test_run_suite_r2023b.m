% test_run_suite_r2023b.m
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
addpath(fullfile(root, 'scripts'));
setup_v2_paths;

fprintf('=== STARTING GFM OVERLOAD COORDINATION SUITE IN R2023b ===\n');
t0 = tic;
res = run_stage2_gfm_overload_coordination_suite();
totalTime = toc(t0);
fprintf('=== COMPLETED GFM OVERLOAD SUITE IN R2023b (Total: %.1f s) ===\n', totalTime);
