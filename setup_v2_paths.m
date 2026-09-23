function root=setup_v2_paths()
%SETUP_V2_PATHS Add the maintainable v2 source folders to the MATLAB path.
root=fileparts(mfilename('fullpath'));
builderRoot=fullfile(root,'builders');
addpath(builderRoot,fullfile(builderRoot,'components'), ...
    fullfile(builderRoot,'interfaces'),fullfile(builderRoot,'resource_builders'), ...
    fullfile(builderRoot,'assemblies'),fullfile(builderRoot,'utilities'));
addpath(fullfile(root,'parameters'));
if exist(fullfile(root,'scripts'),'dir'),addpath(fullfile(root,'scripts'));end
if exist(fullfile(root,'tests'),'dir'),addpath(fullfile(root,'tests'));end
end
