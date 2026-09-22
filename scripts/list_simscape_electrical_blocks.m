load_system('ee_lib');
allBlocks = find_system('ee_lib', 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'Type', 'Block');
terms = {'Transformer', 'Converter', 'Inverter', 'Battery', ...
    'PV', 'Solar', 'Grid', 'Three-Phase', 'RLC'};
for t = 1:numel(terms)
    fprintf('\n=== %s ===\n', terms{t});
    hit = allBlocks(contains(allBlocks, terms{t}, 'IgnoreCase', true));
    for k = 1:min(numel(hit), 120)
        fprintf('%s\n', hit{k});
    end
end
close_system('ee_lib', 0);
