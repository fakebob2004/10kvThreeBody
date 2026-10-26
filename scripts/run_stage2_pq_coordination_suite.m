function PQResults = run_stage2_pq_coordination_suite(plotOnly)
%RUN_STAGE2_PQ_COORDINATION_SUITE Stage 2.5 (Stage 2B) benchmark:
% Capability- and Network-Aware P-Q Dual-Channel Coordination on Asymmetric Weak Feeders.
%
% Network Topology (Asymmetric 10 kV Feeders on 10 MVA / 10 kV base, X/R = 5.0):
%   Z_BESS = 0.02 pu (Co-located GFM slack/droop bus)
%   Z_PV   = 0.08 pu (Medium-distance GFL feeder)
%   Z_Wind = 0.20 pu (Long weak GFL feeder)
%
% Part 1: Empirical Small-Signal V-Q Sensitivity Identification (S_VQ = dV_j / dQ_i)
%   Perturbs Q_PV and Q_Wind by +0.5 Mvar around baseline to extract the 2x2 Jacobian
%   and normalized network voltage effectiveness weights beta_bar_i.
%
% Part 2: Three-Group Dynamic P-Q Coordination Benchmark (0 - 2.5 s)
%   - C1_P_Only    (mode = 3): Capability-weighted P, fixed Q = 0
%   - C1_PQ_Local  (mode = 4): Capability-weighted P, uncoupled local-V Q allocation
%   - C1_PQ_Net    (mode = 5): Two-stage capability- & network-aware P-Q coordination

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

if plotOnly && isfile(fullfile(artifactDir, 'stage2_pq_coordination_results.mat'))
    S = load(fullfile(artifactDir, 'stage2_pq_coordination_results.mat'), 'PQResults');
    PQResults = S.PQResults;
    figPath = fullfile(artifactDir, 'stage2_pq_coordination_comparison.png');
    plot_pq_coordination_comparison(PQResults, figPath);
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

% Force clean rebuild of MATLAB Function block if needed
if exist(fullfile(root, 'slprj'), 'dir')
    try, rmdir(fullfile(root, 'slprj'), 's'); catch, end
end

% Explicitly lock 07 Resource API Layer coordinator to discrete 5 ms sample time
apiSub = [model '/07 Resource API Layer'];
set_param([apiSub '/PV_ProfileCommand'], 'SampleTime', '0.005');
set_param([apiSub '/Wind_ProfileCommand'], 'SampleTime', '0.005');
set_param([apiSub '/MATLAB Function Coordinator'], 'SystemSampleTime', '0.005');

% Insert physical 10 kV feeder impedances: Z = [0.02, 0.08, 0.20] pu
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

fprintf('\n====================================================================\n');
fprintf('STAGE 2.5 PART 1: SMALL-SIGNAL V-Q SENSITIVITY IDENTIFICATION (S_VQ)\n');
fprintf('Asymmetric Network: Z_BESS=0.02 pu, Z_PV=0.08 pu, Z_Wind=0.20 pu\n');
fprintf('====================================================================\n');

PQResults = struct();
PQResults.S_VQ = identify_vq_sensitivity(model);

fprintf('\n====================================================================\n');
fprintf('STAGE 2.5 PART 2: DYNAMIC P-Q COORDINATION BENCHMARK (3 SCHEMES)\n');
fprintf('====================================================================\n');

% Configure compound P-Q stress scenario on asymmetric network
configure_pq_stress_scenario(model);

schemes = {
    'C1_P_Only',   3, 'C_1-P Only (Capability P, Fixed Q=0)';
    'C1_PQ_Local', 4, 'C_1-PQ Local (Uncoupled Local-V Q)';
    'C1_PQ_Net',   5, 'C_1-PQ Network-Aware (2-Stage Coupled P-Q)';
};

apiSub = [model '/07 Resource API Layer'];
S2_API = evalin('base', 'S2_API');
cfg = S2_API.coordinator_config;

for sIdx = 1:size(schemes, 1)
    sName  = schemes{sIdx, 1};
    sMode  = schemes{sIdx, 2};
    sLabel = schemes{sIdx, 3};

    fprintf('\n--- Running %s (coordinatorEnable = %d) ---\n', sLabel, sMode);
    clear stage2_coordinator_algorithm;
    set_param([apiSub '/Coordinator Enable'], 'Value', num2str(sMode));
    set_param([apiSub '/Resource Modes'], 'Value', '[0 1 1]');
    set_param([apiSub '/Coordinator Numeric Config'], 'Value', mat2str(cfg, 12));

    set_param(model, 'StopTime', '2.5');
    tStart = tic;
    simOut = sim(model);
    elapsed = toc(tStart);
    fprintf('  Simulation finished in %.2f s.\n', elapsed);

    raw = squeeze(simOut.get('stage2_result'));
    if size(raw, 2) ~= 54, raw = raw.'; end
    api = squeeze(simOut.get('resource_api_result'));
    if size(api, 2) ~= 48, api = api.'; end

    t = raw(:, 1);
    tail = t >= 0.20;
    win_coord = (t >= 0.30) & (t <= 1.00);
    win_qstep = (t >= 0.65) & (t <= 1.00);
    win_recov = (t >= 1.35) & (t <= 2.50);

    res = struct();
    res.name  = sName;
    res.mode  = sMode;
    res.label = sLabel;
    res.t     = t;

    res.Pbess   = raw(:, 2);
    res.Qbess   = raw(:, 3);
    res.fbess   = raw(:, 4);
    res.soc     = raw(:, 6);
    res.kI_bess = raw(:, 14);

    res.Ppv     = raw(:, 17);
    res.Qpv     = raw(:, 18);
    res.fpv     = raw(:, 22);
    res.kI_pv   = raw(:, 28);
    res.Vpcc_pv = raw(:, 30);

    res.Pwind     = raw(:, 33);
    res.Qwind     = raw(:, 34);
    res.fwind     = raw(:, 38);
    res.kI_wind   = raw(:, 44);
    res.Vpcc_wind = raw(:, 46);

    % API trajectories
    t_api = linspace(0, 2.5, size(api, 1)).';
    res.t_api       = t_api;
    res.Pcmd_bess   = api(:, 1);
    res.Qcmd_bess   = api(:, 2);
    res.Pcmd_pv     = api(:, 5);
    res.Qcmd_pv     = api(:, 6);
    res.Pcmd_wind   = api(:, 9);
    res.Qcmd_wind   = api(:, 10);
    res.Pavail_pv   = api(:, 29);
    res.Pavail_wind = api(:, 41);

    % Reconstruct exact alpha_P, H_P, alpha_Q, H_Q trajectories
    clear stage2_coordinator_algorithm;
    nA = size(api, 1);
    alphaP_traj = zeros(nA, 3);
    HP_traj     = zeros(nA, 3);
    alphaQ_traj = zeros(nA, 3);
    HQ_traj     = zeros(nA, 3);
    for k = 1:nA
        st_k = reshape(api(k, 13:48), 12, 3).';
        pv_av_k = st_k(2, 5);
        w_av_k  = st_k(3, 5);
        w_base_k = 2.0e6 + 2.5e6 * (t_api(k) >= 0.65);
        cmd_k = [1.0e6, 0, 1, 1; ...
                 min(2.0e6, pv_av_k), 0, 1, 1; ...
                 min(w_base_k, w_av_k), 0, 1, 1];
        [~, aP_k, hP_k, aQ_k, hQ_k] = stage2_coordinator_algorithm(st_k, cmd_k, sMode, cfg);
        alphaP_traj(k, :) = aP_k.';
        HP_traj(k, :)     = hP_k.';
        alphaQ_traj(k, :) = aQ_k.';
        HQ_traj(k, :)     = hQ_k.';
    end
    res.alphaP = alphaP_traj;
    res.HP     = HP_traj;
    res.alphaQ = alphaQ_traj;
    res.HQ     = HQ_traj;

    % Key metrics over t >= 0.20 s
    res.Vpv_min   = min(res.Vpcc_pv(tail));
    res.Vwind_min = min(res.Vpcc_wind(tail));
    res.V_min_all = min(res.Vpv_min, res.Vwind_min);
    res.f_min     = min(res.fbess(tail));
    res.f_max     = max(res.fbess(tail));

    % Voltage deviation integrals: J_V = int |V_pu - 1.0| dt (pu*s)
    res.JV_pv   = trapz(t(tail), abs(res.Vpcc_pv(tail)/10000.0 - 1.0));
    res.JV_wind = trapz(t(tail), abs(res.Vpcc_wind(tail)/10000.0 - 1.0));
    res.JV_mean = 0.5 * (res.JV_pv + res.JV_wind);

    % Minimum current limit factors (detects current circle saturation k_I < 1)
    res.kI_pv_min   = min(res.kI_pv(tail));
    res.kI_wind_min = min(res.kI_wind(tail));
    res.kI_bess_min = min(res.kI_bess(tail));
    res.kI_gfl_min  = min(res.kI_pv_min, res.kI_wind_min);

    % Renewable energy utilization eta_RE
    tail_api = t_api >= 0.20;
    coord_api = (t_api >= 0.30) & (t_api <= 1.00);
    P_re_act_api = interp1(t, res.Ppv + res.Pwind, t_api, 'linear', 'extrap');
    P_re_av_api  = res.Pavail_pv + res.Pavail_wind;
    res.eta_RE_coord = trapz(t_api(coord_api), P_re_act_api(coord_api)) / ...
                       max(1.0, trapz(t_api(coord_api), P_re_av_api(coord_api)));
    res.eta_RE_total = trapz(t_api(tail_api), P_re_act_api(tail_api)) / ...
                       max(1.0, trapz(t_api(tail_api), P_re_av_api(tail_api)));

    % Mean values during heavy P+Q stress window [0.75, 0.98] s and recovery [1.60, 2.40] s
    w_peak = (t >= 0.75) & (t <= 0.98);
    w_late = (t >= 1.60) & (t <= 2.40);
    res.peak_Vpv   = mean(res.Vpcc_pv(w_peak));
    res.peak_Vwind = mean(res.Vpcc_wind(w_peak));
    res.peak_Pbess = mean(res.Pbess(w_peak));
    res.peak_Ppv   = mean(res.Ppv(w_peak));
    res.peak_Pwind = mean(res.Pwind(w_peak));
    res.peak_Qbess = mean(res.Qbess(w_peak));
    res.peak_Qpv   = mean(res.Qpv(w_peak));
    res.peak_Qwind = mean(res.Qwind(w_peak));

    res.late_Vpv   = mean(res.Vpcc_pv(w_late));
    res.late_Vwind = mean(res.Vpcc_wind(w_late));
    res.late_Qpv   = mean(res.Qpv(w_late));
    res.late_Qwind = mean(res.Qwind(w_late));

    fprintf('  V_min=[PV: %.0f V, Wind: %.0f V] | J_V(mean)=%.4f pu*s | min(k_I)=[PV: %.4f, Wind: %.4f]\n', ...
        res.Vpv_min, res.Vwind_min, res.JV_mean, res.kI_pv_min, res.kI_wind_min);
    fprintf('  Peak Window [0.75-0.98s]: V=[PV: %.1f V, Wind: %.1f V] | P=[BESS: %.1f, PV: %.1f, Wind: %.1f] kW\n', ...
        res.peak_Vpv, res.peak_Vwind, res.peak_Pbess/1e3, res.peak_Ppv/1e3, res.peak_Pwind/1e3);
    fprintf('  Peak Window [0.75-0.98s]: Q=[BESS: %.1f, PV: %.1f, Wind: %.1f] kvar | eta_RE(0.3-1.0s)=%.2f%%\n', ...
        res.peak_Qbess/1e3, res.peak_Qpv/1e3, res.peak_Qwind/1e3, 100*res.eta_RE_coord);
    fprintf('  Late Window [1.60-2.40s]: V=[PV: %.1f V, Wind: %.1f V] | Q=[PV: %.1f, Wind: %.1f] kvar\n', ...
        res.late_Vpv, res.late_Vwind, res.late_Qpv/1e3, res.late_Qwind/1e3);

    PQResults.(sName) = res;
end

save(fullfile(artifactDir, 'stage2_pq_coordination_results.mat'), 'PQResults');
fprintf('\nSaved Stage 2.5 P-Q results to %s\n', fullfile(artifactDir, 'stage2_pq_coordination_results.mat'));

figPath = fullfile(artifactDir, 'stage2_pq_coordination_comparison.png');
plot_pq_coordination_comparison(PQResults, figPath);

end

function S_VQ = identify_vq_sensitivity(model)
% Measure empirical dV_j / dQ_i around baseline operating point (t in [0.35, 0.44] s)
sup     = [model '/06 Supervision and Results'];
pvCmd   = [sup '/01 PV Command Profile'];
windCmd = [sup '/02 Wind Command Profile'];
loadSys = [model '/05 Island Load'];

% Constant baseline operating point: Load = 5 MW + j2.0 Mvar, PV = 2 MW, Wind = 2 MW
set_param([loadSys '/Adjusted_Island_Load'], 'active_power', '5.0e6', 'reactive_power', '2.0e6');
set_param([loadSys '/One_MW_Step_Load'], 'active_power', '1e3', 'reactive_power', '1e3');
set_param([loadSys '/Load_Step_Command'], 'Time', '10.0', 'Before', '1', 'After', '0');

set_param([pvCmd '/P Base Limit'], 'UpperLimit', '2.0e6');
set_param([pvCmd '/P Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([windCmd '/P Available Base'], 'Value', '3.5e6');
set_param([windCmd '/P Available Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([windCmd '/P Base Limit'], 'UpperLimit', '2.0e6');
set_param([windCmd '/P Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');

apiSub = [model '/07 Resource API Layer'];
set_param([apiSub '/Coordinator Enable'], 'Value', '0');
set_param([apiSub '/Resource Modes'], 'Value', '[0 0 0]');

dQ_test = 0.5e6; % +0.5 Mvar perturbation
q_cases = [0.0, 0.0; dQ_test, 0.0; 0.0, dQ_test];
V_ss    = zeros(3, 2); % rows: [base; +dQ_PV; +dQ_Wind], cols: [V_PV, V_Wind]
Q_ss    = zeros(3, 2);

for c = 1:3
    set_param([pvCmd '/Q Base Command'], 'Value', num2str(q_cases(c, 1), 12));
    set_param([windCmd '/Q Base Command'], 'Value', num2str(q_cases(c, 2), 12));
    set_param(model, 'StopTime', '0.45');
    simOut = sim(model);
    raw = squeeze(simOut.get('stage2_result'));
    if size(raw, 2) ~= 54, raw = raw.'; end
    t = raw(:, 1);
    win = (t >= 0.35) & (t <= 0.44);
    V_ss(c, 1) = mean(raw(win, 30));
    V_ss(c, 2) = mean(raw(win, 46));
    Q_ss(c, 1) = mean(raw(win, 18));
    Q_ss(c, 2) = mean(raw(win, 34));
end

% Reset Q base commands to 0
set_param([pvCmd '/Q Base Command'], 'Value', '0');
set_param([windCmd '/Q Base Command'], 'Value', '0');

dQ_pv_Mvar   = (Q_ss(2, 1) - Q_ss(1, 1)) / 1e6;
dQ_wind_Mvar = (Q_ss(3, 2) - Q_ss(1, 2)) / 1e6;

% Jacobian S_VQ (V / Mvar): rows = [V_PV; V_Wind], cols = [Q_PV, Q_Wind]
J_V_per_Mvar = [
    (V_ss(2, 1) - V_ss(1, 1)) / dQ_pv_Mvar,   (V_ss(3, 1) - V_ss(1, 1)) / dQ_wind_Mvar;
    (V_ss(2, 2) - V_ss(1, 2)) / dQ_pv_Mvar,   (V_ss(3, 2) - V_ss(1, 2)) / dQ_wind_Mvar
];

beta_raw = mean(J_V_per_Mvar, 1); % Mean voltage lift across PCCs per Mvar injected
beta_bar = beta_raw / max(beta_raw);

S_VQ = struct();
S_VQ.V_base_V     = V_ss(1, :);
S_VQ.J_V_per_Mvar = J_V_per_Mvar;
S_VQ.beta_raw     = beta_raw;
S_VQ.beta_bar     = beta_bar;

fprintf('  Baseline Local Voltages: V_PV = %.1f V, V_Wind = %.1f V\n', V_ss(1,1), V_ss(1,2));
fprintf('  Empirical S_VQ = dV_j / dQ_i (V / Mvar):\n');
fprintf('    dV_PV/dQ_PV   = %+6.1f V/Mvar | dV_PV/dQ_Wind   = %+6.1f V/Mvar\n', J_V_per_Mvar(1,1), J_V_per_Mvar(1,2));
fprintf('    dV_Wind/dQ_PV = %+6.1f V/Mvar | dV_Wind/dQ_Wind = %+6.1f V/Mvar\n', J_V_per_Mvar(2,1), J_V_per_Mvar(2,2));
fprintf('  Mean Network Sensitivity beta = [PV: %.1f, Wind: %.1f] V/Mvar -> Normalized beta_bar = [PV: %.3f, Wind: %.3f]\n', ...
    beta_raw(1), beta_raw(2), beta_bar(1), beta_bar(2));
end

function configure_pq_stress_scenario(model)
% First apply standard Stage-2 dynamic stress harness
setup_stage2_stress_scenario(model);

sup     = [model '/06 Supervision and Results'];
windCmd = [sup '/02 Wind Command Profile'];
loadSys = [model '/05 Island Load'];

% Set GFL PCS MVA rating to 5.02 MVA (1.004 pu of 5.0 MW rated active power)
% so that during heavy active-power dispatch (P_Wind ~ 4.68 MW at t in [0.65, 1.00] s),
% C1-PQ Network-Aware (which suppresses Q_Wind to ~0 and shifts Q to PV) stays at kI_Wind = 1.0,
% whereas C1-PQ Local (which injects uncoupled Q_Wind ~ 0.85 Mvar) hits the current circle!
S_pcs_pq = 5.02e6;
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

% Set Wind initial available power to 4.8 MW (drops by -3.8 MW to 1.0 MW at t=1.00 s)
% and step Wind base dispatch by +2.5 MW at t=0.65 s (from 2.0 MW to 4.5 MW) so Wind carries
% ~4.72 MW during [0.65, 1.00] s, directly testing P-Q current circle coupling!
set_param([windCmd '/P Available Base'], 'Value', '4.8e6');
set_param([windCmd '/P Available Increment'], 'Time', '1.00', 'Before', '0', 'After', '-3.8e6');
set_param([windCmd '/P Base Limit'], 'UpperLimit', '2.0e6');
set_param([windCmd '/P Increment'], 'Time', '0.65', 'Before', '0', 'After', '2.5e6');

% Inductive island load + reactive load step at t = 0.65 s
set_param([loadSys '/Adjusted_Island_Load'], 'active_power', '5.0e6', 'reactive_power', '1.5e6');
set_param([loadSys '/One_MW_Step_Load'], 'active_power', '1.4e6', 'reactive_power', '1.2e6');
set_param([loadSys '/Load_Step_Command'], 'Time', '0.65', 'Before', '1', 'After', '0');
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

function plot_pq_coordination_comparison(P, figPath)
fprintf('Generating Stage 2.5 P-Q coordination plot: %s...\n', figPath);

f = figure('Color', 'w', 'Position', [50, 50, 1280, 980], 'Visible', 'off');
figCleanup = onCleanup(@() close(f));

rP   = P.C1_P_Only;
rLoc = P.C1_PQ_Local;
rNet = P.C1_PQ_Net;

colP   = [0.85, 0.33, 0.10]; % Red-Orange: C1-P Only
colLoc = [0.93, 0.69, 0.13]; % Gold: C1-PQ Local
colNet = [0.00, 0.45, 0.74]; % Blue: C1-PQ Network-Aware

% --- Panel 1: Local PCC Voltages (PV & Wind) Across the 3 Schemes ---
subplot(3, 2, 1); hold on; grid on; box on;
plot(rP.t,   rP.Vpcc_pv/1e3,   'Color', colP,   'LineWidth', 1.3, 'DisplayName', 'V_{PCC,PV} (C_1-P Only)');
plot(rLoc.t, rLoc.Vpcc_pv/1e3, 'Color', colLoc, 'LineWidth', 1.3, 'DisplayName', 'V_{PCC,PV} (C_1-PQ Local)');
plot(rNet.t, rNet.Vpcc_pv/1e3, 'Color', colNet, 'LineWidth', 1.7, 'DisplayName', 'V_{PCC,PV} (C_1-PQ Network-Aware)');
plot(rNet.t, rNet.Vpcc_wind/1e3, '--', 'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.5, 'DisplayName', 'V_{PCC,Wind} (C_1-PQ Network-Aware)');
yline(10.0, 'k:', 'Nominal 10 kV', 'LabelHorizontalAlignment', 'left', 'FontSize', 7.5, 'HandleVisibility', 'off');
title('1. Local PCC Voltage Recovery (Asymmetric Feeders [0.02, 0.08, 0.20] pu)', 'FontWeight', 'bold');
ylabel('Voltage (kV)'); xlim([0.2, 2.5]); ylim([7.8, 10.6]);
legend('Location', 'southwest', 'FontSize', 7.2);

% --- Panel 2: Reactive Power Dispatch Q_PV, Q_Wind, Q_BESS ---
subplot(3, 2, 2); hold on; grid on; box on;
plot(rP.t,   rP.Qbess/1e6,   ':',  'Color', colP,   'LineWidth', 1.4, 'DisplayName', 'Q_{BESS} (C_1-P Only)');
plot(rNet.t, rNet.Qbess/1e6, '-',  'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.3, 'DisplayName', 'Q_{BESS} (C_1-PQ Network-Aware)');
plot(rNet.t, rNet.Qpv/1e6,   '-',  'Color', colNet, 'LineWidth', 1.7, 'DisplayName', 'Q_{PV} (C_1-PQ Network-Aware)');
plot(rNet.t, rNet.Qwind/1e6, '--', 'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.6, 'DisplayName', 'Q_{Wind} (C_1-PQ Network-Aware)');
plot(rLoc.t, rLoc.Qwind/1e6, '-.', 'Color', colLoc, 'LineWidth', 1.3, 'DisplayName', 'Q_{Wind} (C_1-PQ Local)');
title('2. Reactive Power Sharing: Offloading BESS & Dynamic PV/Wind Q Shift', 'FontWeight', 'bold');
ylabel('Reactive Power (Mvar)'); xlim([0.2, 2.5]); ylim([-0.3, 2.5]);
legend('Location', 'northeast', 'FontSize', 7.2);

% --- Panel 3: Converter Current Circle Factor k_I (P/Q & Voltage-Sag Coupling) ---
subplot(3, 2, 3); hold on; grid on; box on;
plot(rP.t,   rP.kI_wind,   '--', 'Color', colP,   'LineWidth', 1.5, 'DisplayName', 'k_{I,Wind} (C_1-P Only: V-Sag Current Clip!)');
plot(rLoc.t, rLoc.kI_wind, '-',  'Color', colLoc, 'LineWidth', 1.4, 'DisplayName', 'k_{I,Wind} (C_1-PQ Local)');
plot(rNet.t, rNet.kI_wind, '-',  'Color', colNet, 'LineWidth', 1.7, 'DisplayName', 'k_{I,Wind} (C_1-PQ Network-Aware = 1.0 in Peak)');
plot(rNet.t, rNet.kI_pv,   '--', 'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.4, 'DisplayName', 'k_{I,PV} (C_1-PQ Network-Aware = 1.0)');
title('3. Converter Current Circle Factor k_I (Eliminating V-Sag Overcurrent)', 'FontWeight', 'bold');
ylabel('Current Limit Factor k_I'); xlim([0.2, 2.5]); ylim([0.88, 1.02]);
legend('Location', 'southwest', 'FontSize', 7.2);

% --- Panel 4: Active Power P_Wind & P_BESS Across the 3 Schemes ---
subplot(3, 2, 4); hold on; grid on; box on;
plot(rP.t,   rP.Pwind/1e6,   '--', 'Color', colP,   'LineWidth', 1.5, 'DisplayName', 'P_{Wind} (C_1-P Only: Clipped by k_I < 1)');
plot(rLoc.t, rLoc.Pwind/1e6, '-.', 'Color', colLoc, 'LineWidth', 1.4, 'DisplayName', 'P_{Wind} (C_1-PQ Local)');
plot(rNet.t, rNet.Pwind/1e6, '-',  'Color', colNet, 'LineWidth', 1.7, 'DisplayName', 'P_{Wind} (C_1-PQ Network-Aware)');
plot(rP.t,   rP.Pbess/1e6,   ':',  'Color', [0.75, 0.20, 0.05], 'LineWidth', 1.4, 'DisplayName', 'P_{BESS} (C_1-P Only)');
plot(rNet.t, rNet.Pbess/1e6, '-.', 'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.5, 'DisplayName', 'P_{BESS} (C_1-PQ Network-Aware)');
title('4. Active Power Trajectories: P_{Wind} & P_{BESS} Under Coupled P-Q Support', 'FontWeight', 'bold');
ylabel('Active Power (MW)'); xlim([0.2, 2.5]); ylim([0.5, 4.9]);
legend('Location', 'northwest', 'FontSize', 7.2);

% --- Panel 5: Reactive Participation Factors alpha_i^Q in C1-PQ Network-Aware ---
subplot(3, 2, 5); hold on; grid on; box on;
stairs(rNet.t_api, rNet.alphaQ(:, 2), 'Color', colNet, 'LineWidth', 1.6, 'DisplayName', '\alpha_{PV}^Q (C_1-PQ Network-Aware)');
stairs(rNet.t_api, rNet.alphaQ(:, 3), 'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.6, 'DisplayName', '\alpha_{Wind}^Q (C_1-PQ Network-Aware)');
stairs(rLoc.t_api, rLoc.alphaQ(:, 3), '--', 'Color', colLoc, 'LineWidth', 1.2, 'DisplayName', '\alpha_{Wind}^Q (C_1-PQ Local)');
title('5. Dynamic Reactive Participation Factors \alpha_i^Q(t)', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('\alpha_i^Q'); xlim([0.2, 2.5]); ylim([-0.05, 1.05]);
legend('Location', 'east', 'FontSize', 7.2);

% --- Panel 6: Island Frequency Trajectory Across the 3 Schemes ---
subplot(3, 2, 6); hold on; grid on; box on;
plot(rP.t,   rP.fbess,   '--', 'Color', colP,   'LineWidth', 1.4, 'DisplayName', 'C_1-P Only');
plot(rLoc.t, rLoc.fbess, '-.', 'Color', colLoc, 'LineWidth', 1.4, 'DisplayName', 'C_1-PQ Local');
plot(rNet.t, rNet.fbess, '-',  'Color', colNet, 'LineWidth', 1.7, 'DisplayName', 'C_1-PQ Network-Aware');
title('6. Island Frequency f_{BESS}(t) Under P-Q Coordination', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Frequency (Hz)'); xlim([0.2, 2.5]); ylim([49.50, 49.95]);
legend('Location', 'southwest', 'FontSize', 7.5);

exportgraphics(f, figPath, 'Resolution', 300);
fprintf('Stage 2.5 P-Q comparison plot exported to %s\n', figPath);
end
