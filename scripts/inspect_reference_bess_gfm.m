scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
referenceRoot = fullfile(projectRoot, 'references', ...
    'Renewable-Energy-Integration-Simscape-master');
proj = openProject(fullfile(referenceRoot, 'RenewableEnergyIntegrationSimscape.prj'));
SimulationTime = 3.5;
run(fullfile(referenceRoot, 'ScriptsData', 'PVPlant', ...
    'BatteryStoragePVPlantGFMParameters.m'));
load_system('BatteryStoragePVPlantGFM');

targets = { ...
    'BatteryStoragePVPlantGFM/BESS PV PARK/60 MWhr Battery Energy Storage', ...
    'BatteryStoragePVPlantGFM/BESS PV PARK/60 MWhr Battery Energy Storage/Inverter and DC-DC Converter', ...
    'BatteryStoragePVPlantGFM/BESS PV PARK/60 MWhr Battery Energy Storage/Variant Subsystem'};
for t = 1:numel(targets)
    fprintf('\n=== DIRECT CHILDREN: %s ===\n', targets{t});
    blocks = find_system(targets{t}, 'SearchDepth', 1, 'Type', 'Block');
    for k = 1:numel(blocks)
        b = blocks{k};
        ref = '';
        try, ref = get_param(b, 'ReferenceBlock'); catch, end
        fprintf('BLOCK=%s | TYPE=%s | REF=%s\n', ...
            strrep(b, newline, '|'), get_param(b, 'BlockType'), strrep(ref, newline, '|'));
        if any(strcmp(get_param(b, 'BlockType'), {'Inport','Outport'}))
            try, fprintf('  PORT=%s ELEMENT=%s\n', get_param(b, 'Port'), get_param(b, 'Element')); catch, end
        end
    end
end

fprintf('\n=== TOP CONNECTIONS ===\n');
top = targets{1};
lines = find_system(top, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for k = 1:numel(lines)
    src = get_param(lines(k), 'SrcBlockHandle');
    dst = get_param(lines(k), 'DstBlockHandle');
    if src ~= -1
        srcName = get_param(src, 'Name');
    else
        srcName = '?';
    end
    if isempty(dst), continue; end
    for j = 1:numel(dst)
        if dst(j) ~= -1
            fprintf('%s -> %s\n', strrep(srcName,newline,'|'), ...
                strrep(get_param(dst(j),'Name'),newline,'|'));
        end
    end
end

close_system('BatteryStoragePVPlantGFM', 0);
close(proj);
