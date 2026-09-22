load_system('ee_lib');
blocks = {
    sprintf('ee_lib/Sources/Voltage\nSource\n(Three-Phase)')
    sprintf('ee_lib/Sources/Controlled Voltage\nSource\n(Three-Phase)')
    sprintf('ee_lib/Passive/Transformers/Two-Winding\nTransformer\n(Three-Phase)')
    sprintf('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)')
    sprintf('ee_lib/Passive/Constant Power Load (Three-Phase)')
    sprintf('ee_lib/Semiconductors &\nConverters/Converters/Average-Value\nVoltage Source\nConverter\n(Three-Phase)')
    sprintf('ee_lib/Semiconductors &\nConverters/Converters/Average-Value\nInverter\n(Three-Phase)')
    };

for k = 1:numel(blocks)
    b = blocks{k};
    fprintf('\n=== BLOCK %s ===\n', strrep(b, newline, '|'));
    p = get_param(b, 'DialogParameters');
    names = fieldnames(p);
    for n = 1:numel(names)
        name = names{n};
        try
            value = get_param(b, name);
            if ischar(value) || (isstring(value) && isscalar(value))
                fprintf('PARAM %s=%s\n', name, char(value));
            end
        catch
        end
    end
    pc = get_param(b, 'PortConnectivity');
    for n = 1:numel(pc)
        fprintf('PORT %d Type=%s Position=[%g %g]\n', n, pc(n).Type, ...
            pc(n).Position(1), pc(n).Position(2));
    end
end
close_system('ee_lib', 0);
