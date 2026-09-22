% Simulate and validate the R3 GFM/GFL coordination model.
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
modelName = 'PV_Wind_BESS_Coordination_R3';
modelFile = fullfile(projectRoot, 'build', [modelName '.slx']);
resultFile = fullfile(projectRoot, 'build', [modelName '_results.png']);

load_system(modelFile);
set_param(modelName, 'SimulationCommand', 'update');
out = sim(modelName);
coord = squeeze(out.get('coord')).';
assert(size(coord,2) == 11, 'Unexpected R3 output width.');

t = coord(:,1); grid = coord(:,2); f = coord(:,3); v = coord(:,4);
pb = coord(:,5); pg = coord(:,6); ppv = coord(:,7);
pw = coord(:,8); pl = coord(:,9); soc = coord(:,10); qb = coord(:,11);
island = t >= 1.05;
assert(all(abs(pg(island)) < 1e-9), 'Grid power is not zero after islanding.');
assert(min(f(island)) >= 49.5 && max(f(island)) <= 50.5, ...
    'Island frequency left the 49.5-50.5 Hz validation band.');
assert(min(v(island)) >= 0.95 && max(v(island)) <= 1.05, ...
    'Island voltage left the 0.95-1.05 pu validation band.');
assert(max(abs(pb)) <= 5.0+1e-6, 'BESS active-power limit was exceeded.');
assert(all(soc >= 0.20 & soc <= 0.90), 'SOC operating limits were exceeded.');

tail = t >= 4.85;
residualMW = mean(ppv(tail)+pw(tail)+pb(tail)-pl(tail));
assert(abs(residualMW) < 0.05, 'Final island active-power residual is too large.');
assert(abs(mean(pb(tail))-3.5) < 0.08, 'Final BESS sharing target is incorrect.');

fig = figure('Visible','off','Color','w','Position',[100 100 1100 820]);
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(t,f,'LineWidth',1.4); yline(50,'--'); yline(49.5,':r'); yline(50.5,':r');
ylabel('f (Hz)'); grid on; title('R3 AC-coupled wind-PV-BESS coordination');
nexttile; plot(t,v,'LineWidth',1.4); yline(1,'--'); yline(0.95,':r'); yline(1.05,':r');
ylabel('V (pu)'); grid on;
nexttile; plot(t,[ppv pw pl pb pg],'LineWidth',1.2);
ylabel('P (MW)'); legend('PV','Wind','Load','BESS','Grid','Location','eastoutside'); grid on;
nexttile; yyaxis left; plot(t,100*soc,'LineWidth',1.4); ylabel('SOC (%)');
yyaxis right; plot(t,qb,'LineWidth',1.2); ylabel('Q_{BESS} (Mvar)');
xlabel('Time (s)'); grid on;
exportgraphics(fig,resultFile,'Resolution',160);
close(fig);

fprintf('R3_SIMULATION_OK=1 END_TIME=%.3f s\n', t(end));
fprintf('R3_FREQUENCY_RANGE_HZ=[%.4f, %.4f]\n', min(f(island)), max(f(island)));
fprintf('R3_VOLTAGE_RANGE_PU=[%.5f, %.5f]\n', min(v(island)), max(v(island)));
fprintf('R3_FINAL_PBESS_MW=%.4f RESIDUAL_MW=%.6f SOC=%.6f\n', ...
    mean(pb(tail)), residualMW, soc(end));
fprintf('R3_RESULT_PNG=%s\n', resultFile);
close_system(modelName, 0);
