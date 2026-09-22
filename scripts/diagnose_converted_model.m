scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
modelFile = fullfile(projectRoot, 'build', 'sps_conversion', ...
    'Wind_PV_SOC_DCAC_864_5MW_simscape.slx');
[~, modelName] = fileparts(modelFile);

fprintf('MODEL_FILE=%s\n', modelFile);
try
    load_system(modelFile);
    fprintf('LOAD_OK=1\n');
catch ME
    fprintf('LOAD_OK=0\nLOAD_ERROR=%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    return;
end

unresolved = find_system(modelName, 'FollowLinks', 'on', ...
    'LookUnderMasks', 'all', 'LinkStatus', 'unresolved');
inactive = find_system(modelName, 'FollowLinks', 'on', ...
    'LookUnderMasks', 'all', 'LinkStatus', 'inactive');
fprintf('UNRESOLVED_LINKS=%d\n', numel(unresolved));
fprintf('INACTIVE_LINKS=%d\n', numel(inactive));
for k = 1:min(numel(unresolved), 40)
    fprintf('UNRESOLVED=%s\n', unresolved{k});
end

try
    set_param(modelName, 'SimulationCommand', 'update');
    fprintf('UPDATE_OK=1\n');
catch ME
    fprintf('UPDATE_OK=0\nUPDATE_ERROR=%s\n', ...
        getReport(ME, 'extended', 'hyperlinks', 'off'));
end

close_system(modelName, 0);
