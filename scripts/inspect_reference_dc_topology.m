scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
referenceRoot = fullfile(projectRoot, 'references', ...
    'Renewable-Energy-Integration-Simscape-master');
proj = openProject(fullfile(referenceRoot, 'RenewableEnergyIntegrationSimscape.prj'));
SimulationTime = 3.5;
run(fullfile(referenceRoot, 'ScriptsData', 'PVPlant', ...
    'BatteryStoragePVPlantGFMParameters.m'));
load_system('BatteryStoragePVPlantGFM');

targets = {
    'BatteryStoragePVPlantGFM/BESS PV PARK/100 MWp PV Park/PV Inverter A1'
    'BatteryStoragePVPlantGFM/BESS PV PARK/60 MWhr Battery Energy Storage/Inverter and DC-DC Converter'
    };
for t = 1:numel(targets)
    target = targets{t};
    fprintf('\n=== %s ===\n', target);
    blocks = find_system(target, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'Type', 'Block');
    for k = 1:numel(blocks)
        b = blocks{k};
        bt = get_param(b, 'BlockType');
        if any(strcmp(bt, {'SubSystem','ModelReference','SimscapeBlock','PMIOPort','Inport','Outport'}))
            ref = '';
            try, ref = get_param(b, 'ReferenceBlock'); catch, end
            modelRef = '';
            try, modelRef = get_param(b, 'ModelName'); catch, end
            fprintf('BLOCK=%s | TYPE=%s | REF=%s | MODEL=%s\n', ...
                strrep(b, newline, '|'), bt, strrep(ref, newline, '|'), modelRef);
        end
    end
end

close_system('BatteryStoragePVPlantGFM', 0);
close(proj);
