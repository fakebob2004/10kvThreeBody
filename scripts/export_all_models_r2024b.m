% export_all_models_r2024b.m
% Export models to Simulink R2024b version

root = fileparts(fileparts(mfilename('fullpath')));

% 1. Standalone resource models in models/resources -> models/r2024b
addpath(root);
addpath(fullfile(root, 'scripts'));
setup_v2_paths;
export_validated_resources_r2024b();

% 2. Integrated 3-source model: build/BESS_PV_WIND_STAGE2_R2_API.slx -> build/r2024b/
stage2Model = 'BESS_PV_WIND_STAGE2_R2_API';
srcStage2 = fullfile(root, 'build', [stage2Model '.slx']);
dstStage2Dir = fullfile(root, 'build', 'r2024b');
if ~exist(dstStage2Dir, 'dir'), mkdir(dstStage2Dir); end
dstStage2 = fullfile(dstStage2Dir, [stage2Model '.slx']);
if isfile(srcStage2)
    if bdIsLoaded(stage2Model), close_system(stage2Model, 0); end
    load_system(srcStage2);
    try
        save_system(stage2Model, dstStage2, 'ExportToVersion', 'R2024b');
        fprintf('EXPORT_STAGE2_R2024B_OK=%s\n', dstStage2);
    catch ME
        fprintf('EXPORT_STAGE2_R2024B_WARN=%s\n', ME.message);
    end
    close_system(stage2Model, 0);
end

% 3. Submission models in submission/Wind_Turbine_Course_Design_2026/build/ -> build/r2024b/
subBuildDir = fullfile(root, 'submission', 'Wind_Turbine_Course_Design_2026', 'build');
if exist(subBuildDir, 'dir')
    subR2024bDir = fullfile(subBuildDir, 'r2024b');
    if ~exist(subR2024bDir, 'dir'), mkdir(subR2024bDir); end
    subModels = {'Wind_DirectDrive_SPWM_R2', 'Wind_DFIG_Reused_R2'};
    for k = 1:numel(subModels)
        sm = subModels{k};
        smSrc = fullfile(subBuildDir, [sm '.slx']);
        smDst = fullfile(subR2024bDir, [sm '.slx']);
        if isfile(smSrc)
            if bdIsLoaded(sm), close_system(sm, 0); end
            load_system(smSrc);
            try
                save_system(sm, smDst, 'ExportToVersion', 'R2024b');
                fprintf('EXPORT_SUBMISSION_R2024B_OK=%s\n', smDst);
            catch ME
                fprintf('EXPORT_SUBMISSION_R2024B_WARN=%s\n', ME.message);
            end
            close_system(sm, 0);
        end
    end
    
    % Re-zip submission package with R2024b models included
    zipFile = fullfile(root, 'submission', 'Wind_Turbine_Course_Design_2026.zip');
    subFolder = fullfile(root, 'submission', 'Wind_Turbine_Course_Design_2026');
    if isfile(zipFile), delete(zipFile); end
    zip(zipFile, '*', subFolder);
    fprintf('REPACKAGED_SUBMISSION_ZIP_OK=%s\n', zipFile);
end

fprintf('ALL_R2024B_EXPORTS_COMPLETE=1\n');
