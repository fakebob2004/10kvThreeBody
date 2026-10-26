function LVRTResults = run_stage2_lvrt_coordination_suite(plotOnly)
%RUN_STAGE2_LVRT_COORDINATION_SUITE Layer-3 benchmark:
% Symmetrical Voltage Sag Ride-Through (LVRT) & Post-Fault Recovery Coordination
% on Asymmetric Weak Feeders (System-Level Average Converter Model).
%
% Physical Scope & Model Fidelity Note:
%   Evaluates system-level average converter metrics: dq/AC equivalent current
%   magnitudes (I_actual vs I_limit), converter current-circle factors (k_I),
%   local PCC voltages (V_PCC,i), GFL SRF-PLL phase tracking errors (|dtheta|),
%   active/reactive power sharing (P_i, Q_i), and fundamental/control-scale
%   post-fault recovery voltage peak (V_PCC,peak). Does not claim device-level
%   IGBT bridge-arm switching spike analysis.
%
% Event Sequence (0 - 1.50 s on Asymmetric Network Z = [0.02, 0.08, 0.20] pu):
%   - 0.20 - 0.50 s : Pre-fault steady state (Load = 5.5 MW + j1.5 Mvar)
%   - 0.50 - 0.70 s : 200 ms symmetrical inductive fault shunt switched onto 10 kV bus
%   - 0.70 - 1.50 s : Fault cleared by 3-phase breaker zero-crossing opening; post-fault recovery
%
% Three-Scheme Comparison:
%   1. C1_P_Only  (mode = 3): Active-power priority (Q=0, no fault P de-loading)
%   2. C1_PQ_Local(mode = 4): Uncoupled local-V Q boost (no P de-loading, slow Q release)
%   3. C1_LVRT    (mode = 6): Capability- & network-aware Q-priority + orthogonal P de-loading
%                             + fast post-fault Q retraction

if nargin < 1
    plotOnly = false;
end

scriptDir = fileparts(mfilename('fullpath'));
root = fileparts(scriptDir);
addpath(scriptDir);
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'build'));
addpath(fullfile(root, 'tests'));
set_param(0, 'ErrorIfLoadNewModel', 'off');

artifactDir = fullfile(root, 'artifacts');
if ~exist(artifactDir, 'dir')
    mkdir(artifactDir);
end

if plotOnly && isfile(fullfile(artifactDir, 'stage2_lvrt_coordination_results.mat'))
    S = load(fullfile(artifactDir, 'stage2_lvrt_coordination_results.mat'), 'LVRTResults');
    LVRTResults = S.LVRTResults;
    figPath = fullfile(artifactDir, 'stage2_lvrt_coordination_comparison.png');
    plot_lvrt_coordination_comparison(LVRTResults, figPath);
    return;
end

model = 'BESS_PV_WIND_STAGE2_R2_API';
modelFile = fullfile(root, 'build', [model '.slx']);
assert(isfile(modelFile), 'Missing model file: %s', modelFile);

if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
run(fullfile(root, 'scripts', 'init_bess_pv_wind_stage2_r1.m'));
% Disable InitFcn in memory so sim(model) does not overwrite workspace/API settings
set_param(model, 'InitFcn', '');
cleanupObj = onCleanup(@() close_system(model, 0));

if exist(fullfile(root, 'slprj'), 'dir')
    try, rmdir(fullfile(root, 'slprj'), 's'); catch, end
end

% Explicitly lock 07 Resource API Layer coordinator to discrete 5 ms sample time
apiSub = [model '/07 Resource API Layer'];
set_param([apiSub '/PV_ProfileCommand'], 'SampleTime', '0.005');
set_param([apiSub '/Wind_ProfileCommand'], 'SampleTime', '0.005');
set_param([apiSub '/MATLAB Function Coordinator'], 'SystemSampleTime', '0.005');

% Insert asymmetric 10 kV feeder impedances: Z = [0.02, 0.08, 0.20] pu
insert_feeder_impedances(model);
Z_base = 10.0; % 10 kV, 10 MVA
XR     = 5.0;
w0     = 2 * pi * 50.0;
z_asym = [0.02, 0.08, 0.20];
feederNames = {'Z_BESS_Feeder', 'Z_PV_Feeder', 'Z_Wind_Feeder'};
for r = 1:3
    Z_ohm = z_asym(r) * Z_base;
    R_ohm = Z_ohm / sqrt(1.0 + XR * XR);
    X_ohm = R_ohm * XR;
    L_H   = X_ohm / w0;
    fBlk  = [model '/' feederNames{r}];
    set_param(fBlk, 'R', num2str(R_ohm, 12), 'L', num2str(L_H, 12));
end

% Configure Layer-3 200 ms symmetrical fault & clearing scenario
configure_lvrt_fault_scenario(model);

fprintf('\n====================================================================\n');
fprintf('LAYER 3: SYMMETRICAL VOLTAGE SAG (LVRT) & RECOVERY BENCHMARK\n');
fprintf('Asymmetric Network: Z_BESS=0.02 pu, Z_PV=0.08 pu, Z_Wind=0.20 pu\n');
fprintf('Fault Window: t in [0.50, 0.70] s (200 ms symmetrical inductive fault)\n');
fprintf('====================================================================\n');

schemes = {
    'C1_P_Only',   3, 'C_1-P Only (Uncoordinated Fault P-Priority, Q=0)';
    'C1_PQ_Local', 4, 'C_1-PQ Local (Uncoupled Q-Boost, Slow Q Release)';
    'C1_LVRT',     6, 'C_1-LVRT Proposed (Q-Priority + P De-Loading + Fast Retraction)';
};

S2_API = evalin('base', 'S2_API');
cfg = S2_API.coordinator_config;
LVRTResults = struct();

for sIdx = 1:size(schemes, 1)
    sName  = schemes{sIdx, 1};
    sMode  = schemes{sIdx, 2};
    sLabel = schemes{sIdx, 3};

    fprintf('\n--- Running %s (coordinatorEnable = %d) ---\n', sLabel, sMode);
    clear stage2_coordinator_algorithm;
    set_param([apiSub '/Coordinator Enable'], 'Value', num2str(sMode));
    set_param([apiSub '/Resource Modes'], 'Value', '[0 1 1]');
    set_param([apiSub '/Coordinator Numeric Config'], 'Value', mat2str(cfg, 12));

    set_param(model, 'StopTime', '1.50');
    tStart = tic;
    simOut = sim(model);
    elapsed = toc(tStart);
    fprintf('  Simulation finished in %.2f s.\n', elapsed);

    raw = squeeze(simOut.get('stage2_result'));
    if size(raw, 2) ~= 54, raw = raw.'; end
    api = squeeze(simOut.get('resource_api_result'));
    if size(api, 2) ~= 48, api = api.'; end

    t = raw(:, 1);
    tail      = t >= 0.20;
    win_pre   = (t >= 0.35) & (t <= 0.49);
    win_fault = (t >= 0.53) & (t <= 0.69);
    win_clear = (t >= 0.73) & (t <= 1.15); % Fundamental/control-scale recovery window after breaker zero-crossing clearing
    win_post  = (t >= 1.15) & (t <= 1.48);

    res = struct();
    res.name  = sName;
    res.mode  = sMode;
    res.label = sLabel;
    res.t     = t;

    % BESS signals
    res.Pbess     = raw(:, 2);
    res.Qbess     = raw(:, 3);
    res.fbess     = raw(:, 4);
    res.soc       = raw(:, 6);
    res.Ibess_rms = raw(:, 13);
    res.kI_bess   = raw(:, 14);

    % PV signals
    res.Ppv        = raw(:, 17);
    res.Qpv        = raw(:, 18);
    res.Ppv_cmd    = raw(:, 19);
    res.Qpv_cmd    = raw(:, 20);
    res.fpv        = raw(:, 22);
    res.Ipv_limit  = raw(:, 25);
    res.perr_pv    = raw(:, 26);
    res.Ipv_act    = raw(:, 27);
    res.kI_pv      = raw(:, 28);
    res.Vpcc_pv    = raw(:, 30);

    % Wind signals
    res.Pwind       = raw(:, 33);
    res.Qwind       = raw(:, 34);
    res.Pwind_cmd   = raw(:, 35);
    res.Qwind_cmd   = raw(:, 36);
    res.fwind       = raw(:, 38);
    res.Iwind_limit = raw(:, 41);
    res.perr_wind   = raw(:, 42);
    res.Iwind_act   = raw(:, 43);
    res.kI_wind     = raw(:, 44);
    res.Vpcc_wind   = raw(:, 46);

    % API trajectories
    t_api = linspace(0, 1.50, size(api, 1)).';
    res.t_api     = t_api;
    res.Pcmd_bess = api(:, 1);
    res.Qcmd_bess = api(:, 2);
    res.Pcmd_pv   = api(:, 5);
    res.Qcmd_pv   = api(:, 6);
    res.Pcmd_wind = api(:, 9);
    res.Qcmd_wind = api(:, 10);

    % Fault window [0.53, 0.69] s metrics
    res.fault_Vpv_mean   = mean(res.Vpcc_pv(win_fault));
    res.fault_Vwind_mean = mean(res.Vpcc_wind(win_fault));
    res.fault_Vpv_min    = min(res.Vpcc_pv(win_fault));
    res.fault_Vwind_min  = min(res.Vpcc_wind(win_fault));

    res.fault_Pbess = mean(res.Pbess(win_fault));
    res.fault_Ppv   = mean(res.Ppv(win_fault));
    res.fault_Pwind = mean(res.Pwind(win_fault));

    res.fault_Qbess = mean(res.Qbess(win_fault));
    res.fault_Qpv   = mean(res.Qpv(win_fault));
    res.fault_Qwind = mean(res.Qwind(win_fault));

    res.kI_bess_min = min(res.kI_bess(tail));
    res.kI_pv_min   = min(res.kI_pv(tail));
    res.kI_wind_min = min(res.kI_wind(tail));
    res.fault_kI_pv_mean   = mean(res.kI_pv(win_fault));
    res.fault_kI_wind_mean = mean(res.kI_wind(win_fault));

    res.Ipv_ratio_max   = max(res.Ipv_act(tail) ./ max(1.0, res.Ipv_limit(tail)));
    res.Iwind_ratio_max = max(res.Iwind_act(tail) ./ max(1.0, res.Iwind_limit(tail)));

    % PLL phase tracking error |dtheta| (rad & deg) during fault & recovery
    res.fault_perr_pv_deg   = max(abs(res.perr_pv(win_fault))) * (180 / pi);
    res.fault_perr_wind_deg = max(abs(res.perr_wind(win_fault))) * (180 / pi);
    res.perr_pv_max_rad     = max(abs(res.perr_pv(tail)));
    res.perr_wind_max_rad   = max(abs(res.perr_wind(tail)));
    res.perr_pv_max_deg     = res.perr_pv_max_rad * (180 / pi);
    res.perr_wind_max_deg   = res.perr_wind_max_rad * (180 / pi);

    % Post-fault recovery window [0.73, 1.15] s peak voltage (control-scale overshoot)
    res.recov_Vpv_peak   = max(res.Vpcc_pv(win_clear));
    res.recov_Vwind_peak = max(res.Vpcc_wind(win_clear));
    res.recov_V_peak_all = max(res.recov_Vpv_peak, res.recov_Vwind_peak);

    % Post-fault steady-state window [1.15, 1.48] s
    res.post_Vpv   = mean(res.Vpcc_pv(win_post));
    res.post_Vwind = mean(res.Vpcc_wind(win_post));
    res.post_Ppv   = mean(res.Ppv(win_post));
    res.post_Pwind = mean(res.Pwind(win_post));
    res.f_min      = min(res.fbess(tail));
    res.f_max      = max(res.fbess(tail));

    fprintf('  Fault [0.53-0.69s]: V_mean=[PV: %.0f V, Wind: %.0f V] | V_min=[PV: %.0f V, Wind: %.0f V]\n', ...
        res.fault_Vpv_mean, res.fault_Vwind_mean, res.fault_Vpv_min, res.fault_Vwind_min);
    fprintf('  Fault [0.53-0.69s]: P=[BESS: %.1f, PV: %.1f, Wind: %.1f] kW | Q=[BESS: %.1f, PV: %.1f, Wind: %.1f] kvar\n', ...
        res.fault_Pbess/1e3, res.fault_Ppv/1e3, res.fault_Pwind/1e3, ...
        res.fault_Qbess/1e3, res.fault_Qpv/1e3, res.fault_Qwind/1e3);
    fprintf('  Current Factors: min(k_I)=[BESS: %.4f, PV: %.4f, Wind: %.4f] | Fault mean k_I=[PV: %.4f, Wind: %.4f]\n', ...
        res.kI_bess_min, res.kI_pv_min, res.kI_wind_min, res.fault_kI_pv_mean, res.fault_kI_wind_mean);
    fprintf('  PLL & Recovery : Fault max|dtheta|=[PV: %.2f deg, Wind: %.2f deg] | Post-Fault V_peak=[PV: %.0f V, Wind: %.0f V]\n', ...
        res.fault_perr_pv_deg, res.fault_perr_wind_deg, res.recov_Vpv_peak, res.recov_Vwind_peak);

    LVRTResults.(sName) = res;
end

save(fullfile(artifactDir, 'stage2_lvrt_coordination_results.mat'), 'LVRTResults');
fprintf('\nSaved Layer-3 LVRT results to %s\n', fullfile(artifactDir, 'stage2_lvrt_coordination_results.mat'));

figPath = fullfile(artifactDir, 'stage2_lvrt_coordination_comparison.png');
plot_lvrt_coordination_comparison(LVRTResults, figPath);

end

function configure_lvrt_fault_scenario(model)
sup     = [model '/06 Supervision and Results'];
pvCmd   = [sup '/01 PV Command Profile'];
windCmd = [sup '/02 Wind Command Profile'];
loadSys = [model '/05 Island Load'];

% 1. Set GFL PCS MVA rating to 4.35 MVA (I_limit,peak = 5.15 kA) so that at ~0.78 pu
%    fault voltage, uncoordinated active power (3.55 MW) or uncoupled P+Q exceeds
%    5.15 kApeak (saturating k_I < 1), whereas C1-LVRT proactive P de-loading
%    maintains I_actual <= 4.30 kApeak (k_I = 1.000 across the entire fault)!
S_pcs_pq = 4.35e6;
Ibase_pq = S_pcs_pq / (sqrt(3) * 690.0);
Ilim_pq  = sqrt(2) * Ibase_pq;

S1  = evalin('base', 'S1');
S21 = evalin('base', 'S21');
W1  = evalin('base', 'W1');
S2_API = evalin('base', 'S2_API');

S1.pv.S_pcs_VA             = S_pcs_pq;
S1.control.Ilimit_A        = Ilim_pq;
S21.control.Ibase_rms_A    = Ibase_pq;
S21.control.Ilimit_peak_A  = Ilim_pq;
W1.wind.S_pcs_VA           = S_pcs_pq;
W1.control.Ibase_rms_A     = Ibase_pq;
W1.control.Ilimit_peak_A   = Ilim_pq;
S2_API.rating.S_VA         = [6.25e6, S_pcs_pq, S_pcs_pq];
S2_API.coordinator_config(9:11) = [6.25e6, S_pcs_pq, S_pcs_pq];

assignin('base', 'S1', S1);
assignin('base', 'S21', S21);
assignin('base', 'W1', W1);
assignin('base', 'S2_API', S2_API);

% 2. Pre-fault steady-state renewable dispatch:
%    PV base = 2.8 MW (avail = 3.2 MW), Wind base = 3.55 MW (avail = 4.0 MW)
%    Island load = 5.8 MW + j1.5 Mvar
set_param([pvCmd '/P Base Limit'], 'UpperLimit', '2.8e6');
set_param([pvCmd '/P Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([pvCmd '/Q Base Command'], 'Value', '0');
set_param([pvCmd '/Q Increment'], 'Time', '10.0', 'After', '0');

set_param([windCmd '/P Available Base'], 'Value', '4.0e6');
set_param([windCmd '/P Available Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([windCmd '/P Base Limit'], 'UpperLimit', '3.55e6');
set_param([windCmd '/P Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([windCmd '/Q Base Command'], 'Value', '0');
set_param([windCmd '/Q Increment'], 'Time', '10.0', 'After', '0');

% 3. Configure 200 ms three-phase inductive fault shunt during t in [0.50, 0.70] s:
%    Breaker Trip signal = 1 (Open) for t < 0.50 s, 0 (Closed) for [0.50, 0.70] s, 1 (Open) for t >= 0.70 s
set_param([loadSys '/Adjusted_Island_Load'], 'active_power', '5.8e6', 'reactive_power', '1.5e6');
set_param([loadSys '/One_MW_Step_Load'], 'Vline_rms_min', '10000', ...
    'active_power', '0.4e6', 'reactive_power', '8.2e6', 'tau', '0.005');
set_param([loadSys '/Load_Step_Command'], 'Time', '0.50', 'Before', '1', 'After', '0');

fcBlk  = [loadSys '/Fault_Clear'];
sumBlk = [loadSys '/Trip_Sum'];
if getSimulinkBlockHandle(fcBlk) < 0
    add_block('simulink/Sources/Step', fcBlk, 'Position', [60 190 90 220], ...
        'Time', '0.70', 'Before', '0', 'After', '1', 'SampleTime', '0');
    add_block('simulink/Math Operations/Add', sumBlk, 'Position', [125 140 155 175], 'Inputs', '++');
    try, delete_line(loadSys, 'Load_Step_Command/1', 'Load_Step_to_PS/1'); catch, end
    add_line(loadSys, 'Load_Step_Command/1', 'Trip_Sum/1', 'autorouting', 'on');
    add_line(loadSys, 'Fault_Clear/1', 'Trip_Sum/2', 'autorouting', 'on');
    add_line(loadSys, 'Trip_Sum/1', 'Load_Step_to_PS/1', 'autorouting', 'on');
else
    set_param(fcBlk, 'Time', '0.70', 'Before', '0', 'After', '1');
end
end

function insert_feeder_impedances(model)
bessPH = get_param([model '/02 GFM PCS and Step-up'], 'PortHandles');
pvPH   = get_param([model '/03 PV-GFL Branch'], 'PortHandles');
windPH = get_param([model '/04 Wind-GFL Branch'], 'PortHandles');
loadPH = get_param([model '/05 Island Load'], 'PortHandles');

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

function plot_lvrt_coordination_comparison(L, figPath)
fprintf('Generating Layer-3 LVRT comparison plot: %s...\n', figPath);

f = figure('Color', 'w', 'Position', [50, 50, 1280, 980], 'Visible', 'off');
figCleanup = onCleanup(@() close(f));

rP    = L.C1_P_Only;
rLoc  = L.C1_PQ_Local;
rLVRT = L.C1_LVRT;

colP    = [0.85, 0.33, 0.10]; % Red-Orange: C1-P Only
colLoc  = [0.93, 0.69, 0.13]; % Gold: C1-PQ Local
colLVRT = [0.00, 0.45, 0.74]; % Blue: C1-LVRT Proposed

% --- Panel 1: Local PCC Voltages During Sag & Recovery ---
subplot(3, 2, 1); hold on; grid on; box on;
plot(rP.t,    rP.Vpcc_wind/1e3,   '--', 'Color', colP,    'LineWidth', 1.4, 'DisplayName', 'V_{PCC,Wind} (C_1-P Only)');
plot(rLoc.t,  rLoc.Vpcc_wind/1e3, '-.', 'Color', colLoc,  'LineWidth', 1.5, 'DisplayName', 'V_{PCC,Wind} (C_1-PQ Local: Recovery Overshoot)');
plot(rLVRT.t, rLVRT.Vpcc_wind/1e3,'-',  'Color', colLVRT, 'LineWidth', 1.8, 'DisplayName', 'V_{PCC,Wind} (C_1-LVRT Proposed)');
plot(rLVRT.t, rLVRT.Vpcc_pv/1e3,  ':',  'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.5, 'DisplayName', 'V_{PCC,PV} (C_1-LVRT Proposed)');
yline(10.0, 'k:', 'Nominal 10 kV', 'LabelHorizontalAlignment', 'left', 'FontSize', 7.5, 'HandleVisibility', 'off');
title('1. Local PCC Voltage: Fault Support & Overshoot Suppression', 'FontWeight', 'bold', 'FontSize', 9.5);
ylabel('Voltage (kV)'); xlim([0.3, 1.3]); ylim([6.5, 11.2]);
legend('Location', 'southwest', 'FontSize', 7.2);

% --- Panel 2: Fault Reactive Power Support & Post-Fault Retraction ---
subplot(3, 2, 2); hold on; grid on; box on;
plot(rP.t,    rP.Qbess/1e6,    ':',  'Color', colP,    'LineWidth', 1.4, 'DisplayName', 'Q_{BESS} (C_1-P Only)');
plot(rLVRT.t, rLVRT.Qbess/1e6, '-',  'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.3, 'DisplayName', 'Q_{BESS} (C_1-LVRT Proposed)');
plot(rLoc.t,  rLoc.Qwind/1e6,  '-.', 'Color', colLoc,  'LineWidth', 1.5, 'DisplayName', 'Q_{Wind} (C_1-PQ Local: Lagging Release)');
plot(rLVRT.t, rLVRT.Qwind/1e6, '-',  'Color', colLVRT, 'LineWidth', 1.8, 'DisplayName', 'Q_{Wind} (C_1-LVRT: Fast Boost & Retraction)');
plot(rLVRT.t, rLVRT.Qpv/1e6,   '--', 'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.5, 'DisplayName', 'Q_{PV} (C_1-LVRT Proposed)');
title('2. Reactive Power: Fault Q-Support & Clearing Retraction', 'FontWeight', 'bold', 'FontSize', 9.5);
ylabel('Reactive Power (Mvar)'); xlim([0.3, 1.3]); ylim([-0.4, 6.8]);
legend('Location', 'northeast', 'FontSize', 7.2);

% --- Panel 3: Converter Current Circle Factors k_I During Fault ---
subplot(3, 2, 3); hold on; grid on; box on;
plot(rP.t,    rP.kI_wind,    '--', 'Color', colP,    'LineWidth', 1.5, 'DisplayName', 'k_{I,Wind} (C_1-P Only: Overcurrent Clip!)');
plot(rLoc.t,  rLoc.kI_wind,  '-.', 'Color', colLoc,  'LineWidth', 1.5, 'DisplayName', 'k_{I,Wind} (C_1-PQ Local: Uncoupled P+Q Clip!)');
plot(rLVRT.t, rLVRT.kI_wind, '-',  'Color', colLVRT, 'LineWidth', 1.8, 'DisplayName', 'k_{I,Wind} (C_1-LVRT Proposed: P De-Loaded)');
plot(rLVRT.t, rLVRT.kI_pv,   ':',  'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.5, 'DisplayName', 'k_{I,PV} (C_1-LVRT Proposed)');
plot(rP.t,    rP.kI_bess,    ':',  'Color', [0.75, 0.15, 0.15], 'LineWidth', 1.3, 'DisplayName', 'k_{I,BESS} (C_1-P Only)');
title('3. Converter Current Circle Factors k_I (Preventing Clipping)', 'FontWeight', 'bold', 'FontSize', 9.5);
ylabel('Current Limit Factor k_I'); xlim([0.3, 1.3]); ylim([0.85, 1.02]);
legend('Location', 'southwest', 'FontSize', 7.2);

% --- Panel 4: Active Power De-Loading During Sag & Smooth Post-Fault Recovery ---
subplot(3, 2, 4); hold on; grid on; box on;
plot(rP.t,    rP.Pwind/1e6,    '--', 'Color', colP,    'LineWidth', 1.4, 'DisplayName', 'P_{Wind} (C_1-P Only)');
plot(rLoc.t,  rLoc.Pwind/1e6,  '-.', 'Color', colLoc,  'LineWidth', 1.4, 'DisplayName', 'P_{Wind} (C_1-PQ Local)');
plot(rLVRT.t, rLVRT.Pwind/1e6, '-',  'Color', colLVRT, 'LineWidth', 1.8, 'DisplayName', 'P_{Wind} (C_1-LVRT: Proactive De-Loading)');
plot(rLVRT.t, rLVRT.Ppv/1e6,   ':',  'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.6, 'DisplayName', 'P_{PV} (C_1-LVRT: Proactive De-Loading)');
title('4. Active Power: Orthogonal Fault De-Loading & Smooth Recovery', 'FontWeight', 'bold', 'FontSize', 9.5);
ylabel('Active Power (MW)'); xlim([0.3, 1.3]); ylim([1.8, 4.0]);
legend('Location', 'southwest', 'FontSize', 7.2);

% --- Panel 5: GFL SRF-PLL Phase Tracking Error |dtheta| Across Fault & Clearing ---
subplot(3, 2, 5); hold on; grid on; box on;
plot(rP.t,    rP.perr_wind*(180/pi),    '--', 'Color', colP,    'LineWidth', 1.4, 'DisplayName', '\Delta\theta_{PLL,Wind} (C_1-P Only)');
plot(rLoc.t,  rLoc.perr_wind*(180/pi),  '-.', 'Color', colLoc,  'LineWidth', 1.4, 'DisplayName', '\Delta\theta_{PLL,Wind} (C_1-PQ Local)');
plot(rLVRT.t, rLVRT.perr_wind*(180/pi), '-',  'Color', colLVRT, 'LineWidth', 1.7, 'DisplayName', '\Delta\theta_{PLL,Wind} (C_1-LVRT Proposed)');
title('5. Weak-Feeder Wind SRF-PLL Phase Tracking Error \Delta\theta_{PLL}', 'FontWeight', 'bold', 'FontSize', 9.5);
xlabel('Time (s)'); ylabel('PLL Phase Error (deg)'); xlim([0.3, 1.3]); ylim([-45, 25]);
legend('Location', 'southeast', 'FontSize', 7.2);

% --- Panel 6: Equivalent AC Peak Current Magnitude I_actual vs I_limit ---
subplot(3, 2, 6); hold on; grid on; box on;
plot(rP.t,    rP.Iwind_act/1e3,    '--', 'Color', colP,    'LineWidth', 1.4, 'DisplayName', 'I_{Wind,act} (C_1-P Only)');
plot(rLoc.t,  rLoc.Iwind_act/1e3,  '-.', 'Color', colLoc,  'LineWidth', 1.4, 'DisplayName', 'I_{Wind,act} (C_1-PQ Local)');
plot(rLVRT.t, rLVRT.Iwind_act/1e3, '-',  'Color', colLVRT, 'LineWidth', 1.8, 'DisplayName', 'I_{Wind,act} (C_1-LVRT Proposed)');
plot(rLVRT.t, rLVRT.Iwind_limit/1e3, 'k:', 'LineWidth', 1.4, 'DisplayName', 'Hardware Current Circle I_{limit}');
title('6. Converter AC Peak Current Magnitude I_{actual,Apk} vs I_{limit,Apk}', 'FontWeight', 'bold', 'FontSize', 9.5);
xlabel('Time (s)'); ylabel('Peak Current (kA)'); xlim([0.3, 1.3]); ylim([3.0, 6.0]);
legend('Location', 'northwest', 'FontSize', 7.2);

exportgraphics(f, figPath, 'Resolution', 300);
fprintf('Layer-3 LVRT comparison plot exported to %s\n', figPath);
end
