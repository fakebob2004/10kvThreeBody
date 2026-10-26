function NetResults = run_stage2_network_impedance_sweep(plotOnly)
%RUN_STAGE2_NETWORK_IMPEDANCE_SWEEP Layer-2 network stress test:
% Electrical-distance and feeder-impedance sweep for the three-source islanded microgrid.
%
% Base Values (10 kV network base):
%   V_base = 10 kV, S_base = 10 MVA, f_base = 50 Hz -> Z_base = 10.0 Ohm, X/R = 5.0
%
% Part 1: Symmetric Electrical-Distance Sweep (Group C0 Priority Coordination)
%   Z_BESS = Z_PV = Z_Wind in {0.02, 0.05, 0.10, 0.20} pu
% Part 2: Asymmetric Feeder Topology (Z_BESS=0.02 pu, Z_PV=0.08 pu, Z_Wind=0.20 pu)
%   Compared across Group A (Natural AC), Group B (Fixed 50/50), Group C0 (Priority), Group C1 (Weighted)

if nargin < 1
    plotOnly = false;
end
scriptDir = fileparts(mfilename('fullpath'));
root = fileparts(scriptDir);
addpath(scriptDir);
addpath(fullfile(root, 'scripts'));
artifactDir = fullfile(root, 'artifacts');
if plotOnly && isfile(fullfile(artifactDir, 'stage2_network_impedance_results.mat'))
    S = load(fullfile(artifactDir, 'stage2_network_impedance_results.mat'), 'NetResults');
    NetResults = S.NetResults;
    figPath = fullfile(artifactDir, 'stage2_network_impedance_comparison.png');
    plot_network_impedance_comparison(NetResults, figPath);
    return;
end
addpath(fullfile(root, 'build'));
addpath(fullfile(root, 'tests'));
set_param(0, 'ErrorIfLoadNewModel', 'off');

model = 'BESS_PV_WIND_STAGE2_R2_API';
modelFile = fullfile(root, 'build', [model '.slx']);
assert(isfile(modelFile), 'Missing model file: %s', modelFile);

if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
run(fullfile(root, 'scripts', 'init_bess_pv_wind_stage2_r1.m'));

% Ensure guaranteed cleanup without saving temporary feeder blocks to the frozen SLX
cleanupObj = onCleanup(@() close_system(model, 0));

% Configure the 2.5s multi-event stress scenario
setup_stage2_stress_scenario(model);

artifactDir = fullfile(root, 'artifacts');
if ~exist(artifactDir, 'dir')
    mkdir(artifactDir);
end

% Insert 3-phase series RL feeder impedances between each resource PCC_10kV and Island Load
insert_feeder_impedances(model);

apiSub = [model '/07 Resource API Layer'];

% Base impedance calculation (10 kV, 10 MVA -> Z_base = 10 Ohm, X/R = 5)
Z_base_ohm = (10e3)^2 / 10e6; % 10.0 Ohm
f0_Hz      = 50.0;
xr_ratio   = 5.0;

% Define sweep cases:
% 1-4: Symmetric Z in {0.02, 0.05, 0.10, 0.20} pu under Group C0 (mode 1)
% 5-8: Asymmetric Z = [0.02, 0.08, 0.20] pu across Groups A (0), B (2), C0 (1), C1 (3)
cases = {
    'Sym_0p02pu_C0',  [0.02, 0.02, 0.02], 1, 'Symmetric 0.02 pu (Group C0)';
    'Sym_0p05pu_C0',  [0.05, 0.05, 0.05], 1, 'Symmetric 0.05 pu (Group C0)';
    'Sym_0p10pu_C0',  [0.10, 0.10, 0.10], 1, 'Symmetric 0.10 pu (Group C0)';
    'Sym_0p20pu_C0',  [0.20, 0.20, 0.20], 1, 'Symmetric 0.20 pu (Group C0)';
    'Asym_GroupA',    [0.02, 0.08, 0.20], 0, 'Asymmetric [0.02, 0.08, 0.20] pu (Group A)';
    'Asym_GroupB',    [0.02, 0.08, 0.20], 2, 'Asymmetric [0.02, 0.08, 0.20] pu (Group B)';
    'Asym_GroupC0',   [0.02, 0.08, 0.20], 1, 'Asymmetric [0.02, 0.08, 0.20] pu (Group C0)';
    'Asym_GroupC1',   [0.02, 0.08, 0.20], 3, 'Asymmetric [0.02, 0.08, 0.20] pu (Group C1)';
};

NetResults = struct();

fprintf('\n====================================================================\n');
fprintf('BEGINNING STAGE 2 LAYER-2 ELECTRICAL-DISTANCE & IMPEDANCE SWEEP\n');
fprintf('Base: 10 kV, 10 MVA (Z_base = 10.0 Ohm, X/R = 5.0)\n');
fprintf('====================================================================\n');

feederNames = {'Z_BESS_Feeder', 'Z_PV_Feeder', 'Z_Wind_Feeder'};

for c = 1:size(cases, 1)
    cName  = cases{c, 1};
    z_pu   = cases{c, 2};
    gMode  = cases{c, 3};
    cLabel = cases{c, 4};

    fprintf('\n--- Running %s: Z=[%.2f, %.2f, %.2f] pu, mode=%d ---\n', ...
        cLabel, z_pu(1), z_pu(2), z_pu(3), gMode);

    % Configure R and L on the three feeder blocks
    R_ohm = zeros(1, 3);
    L_H   = zeros(1, 3);
    for r = 1:3
        Z_mag = z_pu(r) * Z_base_ohm;
        R_ohm(r) = Z_mag / sqrt(1.0 + xr_ratio^2);
        X_ohm    = R_ohm(r) * xr_ratio;
        L_H(r)   = X_ohm / (2.0 * pi * f0_Hz);
        set_param([model '/' feederNames{r}], ...
            'R', num2str(R_ohm(r), 12), ...
            'L', num2str(L_H(r), 12));
    end

    % Configure coordinator mode
    set_param([apiSub '/Coordinator Enable'], 'Value', num2str(gMode));
    if gMode > 0
        set_param([apiSub '/Resource Modes'], 'Value', '[0 1 1]');
    else
        set_param([apiSub '/Resource Modes'], 'Value', '[0 0 0]');
    end

    tic;
    simOut = sim(model);
    el = toc;
    fprintf('  Simulation finished in %.2f s.\n', el);

    raw = squeeze(simOut.get('stage2_result'));
    if size(raw, 2) ~= 54, raw = raw.'; end

    api = squeeze(simOut.get('resource_api_result'));
    if size(api, 2) ~= 48, api = api.'; end

    t = raw(:, 1);
    tail = t > 0.20;

    res = struct();
    res.label  = cLabel;
    res.z_pu   = z_pu;
    res.R_ohm  = R_ohm;
    res.L_H    = L_H;
    res.mode   = gMode;
    res.t      = t;

    res.Pbess  = raw(:, 2);
    res.Qbess  = raw(:, 3);
    res.fbess  = raw(:, 4);
    res.soc    = raw(:, 6);
    res.kI_bess= raw(:, 14);

    res.Ppv         = raw(:, 17);
    res.Qpv         = raw(:, 18);
    res.fpv         = raw(:, 22);
    res.pll_err_pv  = raw(:, 26);
    res.kI_pv       = raw(:, 28);
    res.Vpcc_pv     = raw(:, 30);

    res.Pwind        = raw(:, 33);
    res.Qwind        = raw(:, 34);
    res.fwind        = raw(:, 38);
    res.pll_err_wind = raw(:, 42);
    res.kI_wind      = raw(:, 44);
    res.Vpcc_wind    = raw(:, 46);
    res.Pwind_avail  = raw(:, 48);

    res.Pcmd_bess = api(:, 1);
    res.Pcmd_pv   = api(:, 5);
    res.Pcmd_wind = api(:, 9);
    res.Pavail_pv   = api(:, 29);
    res.Pavail_wind = api(:, 41);

    % Metrics over operational window (t > 0.20 s)
    res.f_min     = min(res.fbess(tail));
    res.f_max     = max(res.fbess(tail));
    res.Vpv_min   = min(res.Vpcc_pv(tail));
    res.Vpv_max   = max(res.Vpcc_pv(tail));
    res.Vwind_min = min(res.Vpcc_wind(tail));
    res.Vwind_max = max(res.Vpcc_wind(tail));

    % Local PCC voltage difference between Wind and PV terminals
    res.dV_wind_pv     = res.Vpcc_wind - res.Vpcc_pv;
    res.dV_max_abs     = max(abs(res.dV_wind_pv(tail)));
    res.dV_mean_03_10s = mean(abs(res.dV_wind_pv(t >= 0.30 & t <= 1.00)));

    % PLL tracking & oscillation metrics
    res.pll_err_pv_peak_rad   = max(abs(res.pll_err_pv(tail)));
    res.pll_err_wind_peak_rad = max(abs(res.pll_err_wind(tail)));
    res.df_pll_pv_max         = max(abs(res.fpv(tail) - res.fbess(tail)));
    res.df_pll_wind_max       = max(abs(res.fwind(tail) - res.fbess(tail)));

    % 100 ms Sliding-Window RoCoF
    win_s = 0.100;
    dt_avg = mean(diff(t));
    win_samples = max(2, round(win_s / dt_avg));
    rocof_vec = zeros(size(t));
    if numel(t) > win_samples
        for idx = win_samples:numel(t)
            if t(idx) > 0.20
                dt_win = t(idx) - t(idx - win_samples + 1);
                if dt_win > 1e-4
                    rocof_vec(idx) = abs(res.fbess(idx) - res.fbess(idx - win_samples + 1)) / dt_win;
                end
            end
        end
    end
    res.rocof_max = max(rocof_vec);

    % Integral Renewable Utilization eta_RE
    win_coord = (t >= 0.30) & (t <= 1.00);
    res.eta_RE_total = trapz(t(tail), res.Ppv(tail) + res.Pwind(tail)) / ...
                       max(1.0, trapz(t(tail), res.Pavail_pv(tail) + res.Pavail_wind(tail)));
    res.eta_RE_coord = trapz(t(win_coord), res.Ppv(win_coord) + res.Pwind(win_coord)) / ...
                       max(1.0, trapz(t(win_coord), res.Pavail_pv(win_coord) + res.Pavail_wind(win_coord)));

    % Key snapshot at t = 0.95s (peak load + active coordination)
    idx_095 = find(t >= 0.95, 1, 'first');
    res.snap095_Pbess   = res.Pbess(idx_095);
    res.snap095_Ppv     = res.Ppv(idx_095);
    res.snap095_Pwind   = res.Pwind(idx_095);
    res.snap095_Vpv     = res.Vpcc_pv(idx_095);
    res.snap095_Vwind   = res.Vpcc_wind(idx_095);
    res.snap095_fbess   = res.fbess(idx_095);

    fprintf('  f=[%.3f, %.3f] Hz, RoCoF=%.2f Hz/s | V_PV=[%.0f, %.0f] V, V_W=[%.0f, %.0f] V, max|V_W-V_PV|=%.1f V\n', ...
        res.f_min, res.f_max, res.rocof_max, res.Vpv_min, res.Vpv_max, res.Vwind_min, res.Vwind_max, res.dV_max_abs);
    fprintf('  PLL peak phase err [PV, Wind]=[%.4f, %.4f] rad, max|f_PLL-f_BESS|=[%.3f, %.3f] Hz | eta_RE(0.3-1.0s)=%.2f%%\n', ...
        res.pll_err_pv_peak_rad, res.pll_err_wind_peak_rad, res.df_pll_pv_max, res.df_pll_wind_max, 100*res.eta_RE_coord);
    fprintf('  @0.95s: P_BESS=%.1f kW, P_PV=%.1f kW, P_Wind=%.1f kW, V_PV=%.1f V, V_Wind=%.1f V\n', ...
        res.snap095_Pbess/1e3, res.snap095_Ppv/1e3, res.snap095_Pwind/1e3, res.snap095_Vpv, res.snap095_Vwind);

    NetResults.(cName) = res;
end

% Save MAT results
matPath = fullfile(artifactDir, 'stage2_network_impedance_results.mat');
save(matPath, 'NetResults', '-v7.3');
fprintf('\nNetwork impedance sweep results saved to %s\n', matPath);

% Export 6-panel figure
figPath = fullfile(artifactDir, 'stage2_network_impedance_comparison.png');
plot_network_impedance_comparison(NetResults, figPath);

end

function insert_feeder_impedances(model)
% Disconnect direct 10 kV bus short and insert Z_BESS_Feeder, Z_PV_Feeder, Z_Wind_Feeder
bessPH = get_param([model '/02 GFM PCS and Step-up'], 'PortHandles');
pvPH   = get_param([model '/03 PV-GFL Branch'], 'PortHandles');
windPH = get_param([model '/04 Wind-GFL Branch'], 'PortHandles');
loadPH = get_param([model '/05 Island Load'], 'PortHandles');

% Delete existing conserving connection lines on the 10 kV network
conns = [bessPH.RConn(1), pvPH.RConn(1), windPH.RConn(1), loadPH.LConn(1)];
for k = 1:numel(conns)
    ln = get_param(conns(k), 'Line');
    if ln > 0
        try, delete_line(ln); catch, end
    end
end

protoRL = [model '/02 GFM PCS and Step-up/04 PCS Filter and Transformer/LCL_L1'];
feederNames = {'Z_BESS_Feeder', 'Z_PV_Feeder', 'Z_Wind_Feeder'};
srcPorts    = [bessPH.RConn(1), pvPH.RConn(1), windPH.RConn(1)];
posList     = {[655 245 695 275], [1025 255 1065 285], [1025 580 1065 610]};

for r = 1:3
    fBlk = [model '/' feederNames{r}];
    if getSimulinkBlockHandle(fBlk) < 0
        add_block(protoRL, fBlk, 'Position', posList{r});
    end
    set_param(fBlk, 'R', '0.04', 'L', '6.366e-4');
    fPH = get_param(fBlk, 'PortHandles');
    if get_param(fPH.LConn(1), 'Line') > 0
        try, delete_line(get_param(fPH.LConn(1), 'Line')); catch, end
    end
    if get_param(fPH.RConn(1), 'Line') > 0
        try, delete_line(get_param(fPH.RConn(1), 'Line')); catch, end
    end
    add_line(model, srcPorts(r), fPH.LConn(1), 'autorouting', 'on');
    add_line(model, fPH.RConn(1), loadPH.LConn(1), 'autorouting', 'on');
end
end

function plot_network_impedance_comparison(N, figPath)
fprintf('Generating network impedance comparison plot: %s...\n', figPath);

f = figure('Color', 'w', 'Position', [50, 50, 1260, 980], 'Visible', 'off');
figCleanup = onCleanup(@() close(f));

symFields = {'Sym_0p02pu_C0', 'Sym_0p05pu_C0', 'Sym_0p10pu_C0', 'Sym_0p20pu_C0'};
symLabels = {'Z = 0.02 pu', 'Z = 0.05 pu', 'Z = 0.10 pu', 'Z = 0.20 pu'};
symCols   = {
    [0.00, 0.45, 0.74]; % 0.02 pu (Blue)
    [0.30, 0.75, 0.93]; % 0.05 pu (Cyan)
    [0.93, 0.69, 0.13]; % 0.10 pu (Gold)
    [0.85, 0.33, 0.10]; % 0.20 pu (Red-Orange)
};

% --- Panel 1: Local PCC Voltage Divergence (Wind vs PV in Asymmetric Network) ---
subplot(3, 2, 1); hold on; grid on; box on;
resAsymC0 = N.Asym_GroupC0;
resSym02  = N.Sym_0p02pu_C0;
plot(resAsymC0.t, resAsymC0.Vpcc_wind/1e3, 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, ...
    'DisplayName', 'V_{PCC,Wind} (Asym Z_W=0.20 pu)');
plot(resAsymC0.t, resAsymC0.Vpcc_pv/1e3,   'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.5, ...
    'DisplayName', 'V_{PCC,PV} (Asym Z_{PV}=0.08 pu)');
plot(resSym02.t,  resSym02.Vpcc_wind/1e3,  'k--', 'LineWidth', 1.1, ...
    'DisplayName', 'V_{PCC} (Sym Z=0.02 pu)');
title('1. Local PCC Voltage Divergence: V_{PCC,Wind} vs V_{PCC,PV}', 'FontWeight', 'bold');
ylabel('Voltage (kV)'); xlim([0.2, 2.5]); ylim([8.4, 10.6]);
legend('Location', 'southwest', 'FontSize', 7.5);

% --- Panel 2: Local Voltage Difference V_PCC,Wind - V_PCC,PV Across Impedances ---
subplot(3, 2, 2); hold on; grid on; box on;
for k = 1:4
    r = N.(symFields{k});
    plot(r.t, r.dV_wind_pv, 'Color', symCols{k}, 'LineWidth', 1.2, 'DisplayName', ['Sym ' symLabels{k}]);
end
plot(resAsymC0.t, resAsymC0.dV_wind_pv, 'Color', [0.49, 0.18, 0.56], 'LineWidth', 1.6, ...
    'DisplayName', 'Asym [0.02, 0.08, 0.20] pu');
title('2. Inter-Resource PCC Voltage Difference V_{PCC,Wind} - V_{PCC,PV}', 'FontWeight', 'bold');
ylabel('\DeltaV_{PCC} (V)'); xlim([0.2, 2.5]); ylim([-140, 220]);
legend('Location', 'northeast', 'FontSize', 7.5);

% --- Panel 3: GFL Local SRF-PLL Frequency Tracking Across Impedances ---
subplot(3, 2, 3); hold on; grid on; box on;
for k = [1, 3, 4]
    r = N.(symFields{k});
    plot(r.t, r.fwind, 'Color', symCols{k}, 'LineWidth', 1.2, 'DisplayName', ['f_{PLL,Wind} (' symLabels{k} ')']);
end
plot(resAsymC0.t, resAsymC0.fwind, 'Color', [0.49, 0.18, 0.56], 'LineStyle', '--', 'LineWidth', 1.4, ...
    'DisplayName', 'f_{PLL,Wind} (Asym 0.20 pu)');
title('3. Wind GFL Local SRF-PLL Frequency Tracking', 'FontWeight', 'bold');
ylabel('Frequency (Hz)'); xlim([0.2, 2.5]); ylim([49.3, 50.2]);
legend('Location', 'northeast', 'FontSize', 7.5);

% --- Panel 4: GFL PLL Phase Error Peak & Voltage Drop vs Impedance ---
subplot(3, 2, 4); hold on; grid on; box on;
z_vec = [0.02, 0.05, 0.10, 0.20];
pll_w = zeros(1, 4);
pll_pv= zeros(1, 4);
v_min = zeros(1, 4);
v_095 = zeros(1, 4);
for k = 1:4
    r = N.(symFields{k});
    pll_w(k)  = r.pll_err_wind_peak_rad;
    pll_pv(k) = r.pll_err_pv_peak_rad;
    v_min(k)  = min(r.Vpv_min, r.Vwind_min) / 1e3;
    v_095(k)  = r.snap095_Vpv / 1e3;
end
yyaxis left;
plot(z_vec, pll_w,  'o-', 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.6, 'MarkerFaceColor', [0.00, 0.45, 0.74], 'DisplayName', 'Wind PLL |\Delta\theta|_{max}');
plot(z_vec, pll_pv, 's--', 'Color', [0.30, 0.75, 0.93], 'LineWidth', 1.5, 'MarkerFaceColor', [0.30, 0.75, 0.93], 'DisplayName', 'PV PLL |\Delta\theta|_{max}');
ylabel('Peak PLL Phase Error (rad)');
ylim([0, max([pll_w, pll_pv])*1.35 + 0.01]);
yyaxis right;
plot(z_vec, v_095, '^-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.6, 'MarkerFaceColor', [0.85, 0.33, 0.10], 'DisplayName', 'V_{PCC,PV} @ 0.95s (kV)');
plot(z_vec, v_min, 'd:', 'Color', [0.64, 0.08, 0.18], 'LineWidth', 1.4, 'MarkerFaceColor', [0.64, 0.08, 0.18], 'DisplayName', 'Min Transient V_{PCC} (kV)');
ylabel('Local PCC Voltage (kV)');
ylim([min(v_min) - 0.3, max(v_095) + 0.3]);
title('4. PLL Phase Error & Local Voltage vs Feeder Impedance Z_{pu}', 'FontWeight', 'bold');
xlabel('Feeder Impedance Z (pu on 10 MVA / 10 kV)');
xticks(z_vec);
legend('Location', 'southwest', 'FontSize', 7.0);

% --- Panel 5: Coordination Consistency in Asymmetric Network (BESS Power) ---
subplot(3, 2, 5); hold on; grid on; box on;
plot(N.Asym_GroupA.t,  N.Asym_GroupA.Pbess/1e6,  'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.2, 'DisplayName', 'Asym Group A (Natural)');
plot(N.Asym_GroupB.t,  N.Asym_GroupB.Pbess/1e6,  'Color', [0.93, 0.69, 0.13], 'LineWidth', 1.2, 'DisplayName', 'Asym Group B (Fixed 50/50)');
plot(N.Asym_GroupC0.t, N.Asym_GroupC0.Pbess/1e6, 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.6, 'DisplayName', 'Asym Group C0 (Priority)');
plot(N.Asym_GroupC1.t, N.Asym_GroupC1.Pbess/1e6, 'Color', [0.47, 0.67, 0.19], 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Asym Group C1 (Weighted)');
title('5. BESS Active Power Under Asymmetric Feeders [0.02, 0.08, 0.20] pu', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Power (MW)'); xlim([0.2, 2.5]); ylim([0.5, 4.7]);
legend('Location', 'northwest', 'FontSize', 7.5);

% --- Panel 6: Wind Active Power Across Symmetric Impedance Sweep (0.02 -> 0.20 pu) ---
subplot(3, 2, 6); hold on; grid on; box on;
for k = 1:4
    r = N.(symFields{k});
    plot(r.t, r.Pwind/1e6, 'Color', symCols{k}, 'LineWidth', 1.3, 'DisplayName', symLabels{k});
end
plot(resAsymC0.t, resAsymC0.Pwind/1e6, 'k:', 'LineWidth', 1.5, 'DisplayName', 'Asym [0.02, 0.08, 0.20] pu');
title('6. Coordinated Wind Dispatch Consistency Across Feeder Impedances', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Power (MW)'); xlim([0.2, 2.5]); ylim([0.5, 3.4]);
legend('Location', 'northeast', 'FontSize', 7.5);

exportgraphics(f, figPath, 'Resolution', 300);
fprintf('Network impedance plot exported to %s\n', figPath);
end
