% Rebuild entry point, compatible with MATLAB R2024b.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
build_pv_dynamic_standalone;
