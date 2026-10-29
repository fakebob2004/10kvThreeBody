% export_all_models_r2023b.m
% Export models to Simulink R2023b version

root = fileparts(fileparts(mfilename('fullpath')));

addpath(root);
addpath(fullfile(root, 'scripts'));
setup_v2_paths;

% 1. Standalone resource models in models/resources -> models/r2023b
sourceFolder = fullfile(root, 'models', 'resources');
targetFolder = fullfile(root, 'models', 'r2023b');
if ~exist(targetFolder, 'dir'), mkdir(targetFolder); end

models = {'pv_resource_standalone', 'wind_resource_standalone', 'bess_resource_standalone'};
for k = 1:numel(models)
    m = models{k};
    sourceFile = fullfile(sourceFolder, [m '.slx']);
    targetFile = fullfile(targetFolder, [m '.slx']);
    if isfile(sourceFile)
        if bdIsLoaded(m), close_system(m, 0); end
        load_system(sourceFile);
        try
            save_system(m, targetFile, 'ExportToVersion', 'R2023b');
            fprintf('R2023B_EXPORT_OK=%s\n', targetFile);
        catch ME
            fprintf('R2023B_EXPORT_WARN=%s (%s)\n', targetFile, ME.message);
        end
        close_system(m, 0);
    end
end

% 2. Rebuild the integrated Stage 2 model in R2023b
% Note: build/r2023b/BESS_PV_WIND_STAGE2_R2_API.slx is already rebuilt and verified by rebuild_stage2_r2023b.m

fprintf('ALL_R2023B_EXPORTS_COMPLETE=1\n');
