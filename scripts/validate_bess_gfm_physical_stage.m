% Validate the standalone BESS-GFM physical source-equivalent stage.
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
run(fullfile(scriptDir,'init_bess_gfm_stage.m'));

modelName = 'BESS_GFM_10kV_Physical_R4';
modelFile = fullfile(projectRoot,'build',[modelName '.slx']);
resultPng = fullfile(projectRoot,'build',[modelName '_results.png']);
load_system(modelFile);
set_param(modelName,'StopTime','1.0');
out = sim(modelName);
r = squeeze(out.get('gfm_result'));
if size(r,2) ~= 7, r = r.'; end
assert(size(r,2) == 7,'Unexpected gfm_result shape.');

t = r(:,1); P = r(:,2); Q = r(:,3); f = r(:,4);
Vcmd = r(:,5); SOC = r(:,6); phase = r(:,7);
tail = t >= 0.9;
Pss = mean(P(tail)); Qss = mean(Q(tail));
fss = mean(f(tail)); Vss = mean(Vcmd(tail));
Sss = hypot(Pss,Qss);
fExpected = G.f0_Hz - G.control.mp_Hz_per_W*Pss;
VExpected = G.ac.Vll_low_V - G.control.nq_V_per_var*Qss;

assert(Pss > 0.95*G.load.P_W && Pss < 1.08*G.load.P_W, ...
    'Steady active power does not match the three-phase load.');
assert(Qss > 0.80*G.load.Q_var && Qss < 1.20*G.load.Q_var, ...
    'Steady reactive power does not match the load.');
assert(abs(fss-fExpected) < 2e-3,'P-f droop equation mismatch.');
assert(abs(Vss-VExpected) < 0.2,'Q-V droop equation mismatch.');
assert(Pss < G.bess.P_W,'BESS active-power rating exceeded.');
assert(Sss < G.bess.S_VA,'PCS apparent-power rating exceeded.');
assert(SOC(end) < G.bess.SOC0 && SOC(end) > G.bess.SOC_min, ...
    'SOC direction or lower limit is invalid during discharge.');
assert(all(isfinite(r),'all'),'Non-finite simulation result detected.');

fig = figure('Visible','off','Color','w','Position',[100 100 1100 720]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
nexttile; plot(t,P/1e6,'LineWidth',1.2); hold on;
yline(G.load.P_W/1e6,'--'); grid on; xlabel('Time (s)'); ylabel('P (MW)');
title('BESS active power');
nexttile; plot(t,Q/1e6,'LineWidth',1.2); hold on;
yline(G.load.Q_var/1e6,'--'); grid on; xlabel('Time (s)'); ylabel('Q (Mvar)');
title('BESS reactive power');
nexttile; plot(t,f,'LineWidth',1.2); grid on;
xlabel('Time (s)'); ylabel('Frequency (Hz)'); title('P-f droop');
nexttile; yyaxis left; plot(t,Vcmd,'LineWidth',1.2); ylabel('V command (V)');
yyaxis right; plot(t,SOC,'LineWidth',1.2); ylabel('SOC'); grid on;
xlabel('Time (s)'); title('Q-V droop and SOC');
exportgraphics(fig,resultPng,'Resolution',160); close(fig);

fprintf(['BESS_GFM_VALIDATION_PASS=1\n' ...
    'P=%.4f MW, Q=%.4f Mvar, S=%.4f MVA\n' ...
    'f=%.5f Hz (expected %.5f), Vcmd=%.3f V (expected %.3f)\n' ...
    'SOC: %.7f -> %.7f, phase=%.4f rad\n' ...
    'RESULT_PNG=%s\n'],Pss/1e6,Qss/1e6,Sss/1e6, ...
    fss,fExpected,Vss,VExpected,SOC(1),SOC(end),phase(end),resultPng);
close_system(modelName,0);
