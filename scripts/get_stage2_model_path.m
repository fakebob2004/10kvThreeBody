function modelPath = get_stage2_model_path(modelName)
%GET_STAGE2_MODEL_PATH Returns the appropriate .slx model file path
% matching the running MATLAB release (native build or r2023b rebuilt).

if nargin < 1 || isempty(modelName)
    modelName = 'BESS_PV_WIND_STAGE2_R2_API';
end

root = fileparts(fileparts(mfilename('fullpath')));
isR2026 = contains(version, 'R2026');
r2023bPath = fullfile(root, 'build', 'r2023b', [modelName '.slx']);
rootPath   = fullfile(root, 'build', [modelName '.slx']);

if ~isR2026 && isfile(r2023bPath)
    modelPath = r2023bPath;
else
    modelPath = rootPath;
end
end
