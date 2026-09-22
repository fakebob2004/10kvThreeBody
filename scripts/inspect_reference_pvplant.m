scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
referenceRoot = fullfile(projectRoot, 'references', ...
    'Renewable-Energy-Integration-Simscape-master');
projectFile = fullfile(referenceRoot, 'RenewableEnergyIntegrationSimscape.prj');

proj = openProject(projectFile);
SimulationTime = 3.5;
run(fullfile(referenceRoot, 'ScriptsData', 'PVPlant', ...
    'BatteryStoragePVPlantGFMParameters.m'));

fprintf('PV_VDC=%.6f V\n', PVInverter.Vdc);
fprintf('PANEL_SERIES_CELLS=%g\n', Panel.n_series_cell_panel);
fprintf('ARRAY_SERIES_PANELS=%g\n', Array.n_series_panels_per_string);
fprintf('MPPT_DV=%.6f V\n', Mpp.dv);
fprintf('BATTERY_NOMINAL_V=%.6f V\n', battery.vbat_nominal);
fprintf('BATTERY_INVERTER_DC_V=%.6f V\n', BatteryInverter.DCVoltage);

models = {'BatteryStoragePVPlantGFM', 'PVInverterGFL', 'PVcontroller'};
for m = 1:numel(models)
    name = models{m};
    load_system(name);
    fprintf('\n=== MODEL %s ===\n', name);
    blocks = find_system(name, 'SearchDepth', 3, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'Type', 'Block');
    for k = 1:numel(blocks)
        b = blocks{k};
        if contains(b, {'PV','Solar','Battery','BESS','DC','MPPT','Inverter', ...
                'Controller','Transformer'}, 'IgnoreCase', true)
            bt = get_param(b, 'BlockType');
            ref = '';
            try
                ref = get_param(b, 'ReferenceBlock');
            catch
            end
            fprintf('BLOCK=%s | TYPE=%s | REF=%s\n', ...
                strrep(b, newline, '|'), bt, strrep(ref, newline, '|'));
        end
    end
    close_system(name, 0);
end

close(proj);
