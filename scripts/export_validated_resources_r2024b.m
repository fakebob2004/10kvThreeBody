function files = export_validated_resources_r2024b()
%EXPORT_VALIDATED_RESOURCES_R2024B Export accepted v2 resources for R2024b.
% The R2026a source models remain authoritative and are never overwritten.

root = fileparts(fileparts(mfilename('fullpath')));
setup_v2_paths;
define_resource_buses(true);
define_v2_parameters(true);
define_strong_machine_fixture(true);

sourceFolder = fullfile(root,'models','resources');
targetFolder = fullfile(root,'models','r2024b');
if ~exist(targetFolder,'dir'), mkdir(targetFolder); end

models = {'pv_resource_standalone','wind_resource_standalone'};
files = cell(size(models));
for k = 1:numel(models)
    model = models{k};
    sourceFile = fullfile(sourceFolder,[model '.slx']);
    targetFile = fullfile(targetFolder,[model '.slx']);
    assert(isfile(sourceFile),'Missing validated source model: %s',sourceFile);
    if bdIsLoaded(model), close_system(model,0); end
    load_system(sourceFile);
    set_param(model,'SimulationCommand','update');
    save_system(model,targetFile,'ExportToVersion','R2024b');
    close_system(model,0);
    files{k} = targetFile;
    fprintf('R2024B_EXPORT_OK=%s\n',targetFile);
end
fprintf('R2024B_RESOURCE_EXPORT_CREATED=1\n');
end
