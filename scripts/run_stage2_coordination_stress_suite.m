function S = run_stage2_coordination_stress_suite()
%RUN_STAGE2_COORDINATION_STRESS_SUITE Executes the 2.5s multi-event stress test
% across four control groups:
%   Group A  (mode 0): Natural AC Coupling (Uncoordinated droop)
%   Group B  (mode 2): Fixed-Ratio 50/50 Allocation
%   Group C0 (mode 1): Capability-Constrained Priority Dispatch
%   Group C1 (mode 3): Capability-Weighted Adaptive Coordination (alpha_i = H_i / sum(H_j))

scriptDir = fileparts(mfilename('fullpath'));
root = fileparts(scriptDir);
addpath(scriptDir);
addpath(fullfile(root, 'scripts'));
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

% Ensure guaranteed cleanup on function exit
cleanupObj = onCleanup(@() close_system(model, 0));

% Configure the 2.5s sequential multi-event scenario
setup_stage2_stress_scenario(model);

artifactDir = fullfile(root, 'artifacts');
if ~exist(artifactDir, 'dir')
    mkdir(artifactDir);
end

apiSub = [model '/07 Resource API Layer'];

groups = {'GroupA_Natural', 'GroupB_Fixed', 'GroupC0_Priority', 'GroupC1_Weighted'};
modes  = [0, 2, 1, 3]; % 0: Natural AC, 2: Fixed 50/50, 1: Priority C0, 3: Weighted C1
labels = {'Group A: Natural AC Coupling (Uncoordinated)', ...
          'Group B: Fixed 50/50 Allocation (Capability-Unaware)', ...
          'Group C0: Capability-Constrained Priority Dispatch', ...
          'Group C1: Capability-Weighted Adaptive Coordination'};

S = struct();
s2_cfg = evalin('base', 'S2_API.coordinator_config');

for g = 1:numel(groups)
    gName = groups{g};
    gMode = modes(g);
    fprintf('\n============================================================\n');
    fprintf('Running %s (coordEnable = %d)...\n', labels{g}, gMode);
    fprintf('============================================================\n');

    set_param([apiSub '/Coordinator Enable'], 'Value', num2str(gMode));
    if gMode > 0
        set_param([apiSub '/Resource Modes'], 'Value', '[0 1 1]');
    else
        set_param([apiSub '/Resource Modes'], 'Value', '[0 0 0]');
    end
    
    tic;
    simOut = sim(model);
    el = toc;
    fprintf('Simulation completed in %.2f s.\n', el);

    % Extract raw telemetry (54 channels) and API diagnostics (48 channels)
    raw = squeeze(simOut.get('stage2_result'));
    if size(raw, 2) ~= 54, raw = raw.'; end

    api = squeeze(simOut.get('resource_api_result'));
    if size(api, 2) ~= 48, api = api.'; end

    t = raw(:, 1);

    res = struct();
    res.t = t;
    res.Pbess = raw(:, 2);
    res.Qbess = raw(:, 3);
    res.fbess = raw(:, 4);
    res.soc   = raw(:, 6);
    res.Vdc_bess = raw(:, 7);
    res.Ibat  = raw(:, 8);
    res.kI_bess = raw(:, 14); % Current limit factor (1.0 = healthy)

    res.Ppv   = raw(:, 17);
    res.Qpv   = raw(:, 18);
    res.fpv   = raw(:, 22);
    res.kI_pv = raw(:, 28);
    res.Vpcc_pv = raw(:, 30);

    res.Pwind = raw(:, 33);
    res.Qwind = raw(:, 34);
    res.fwind = raw(:, 38);
    res.kI_wind = raw(:, 44);
    res.Vpcc_wind = raw(:, 46);
    res.Pwind_avail = raw(:, 48);

    res.Pload = raw(:, 53);
    res.Qload = raw(:, 54);

    % API signals
    res.Pcmd_bess = api(:, 1);
    res.Pcmd_pv   = api(:, 5);
    res.Pcmd_wind = api(:, 9);

    res.Pavail_pv   = api(:, 25 + 4); % PV status column 5 (index 29)
    res.Pavail_wind = api(:, 37 + 4); % Wind status column 5 (index 41)

    % Reconstruct time-series participation factors alpha_i(t) and capability H_i(t)
    N = numel(t);
    res.alpha = zeros(N, 3);
    res.H     = zeros(N, 3);
    for k = 1:N
        st_k = reshape(api(k, 13:48), 12, 3).';
        cmd_in_k = [1.0e6, 0.0, 1.0, (gMode > 0)*1.0; ...
                    res.Pavail_pv(k), 0.0, 1.0, (gMode > 0)*1.0; ...
                    2.0e6, 0.0, 1.0, (gMode > 0)*1.0];
        [~, a_k, h_k] = stage2_coordinator_algorithm(st_k, cmd_in_k, gMode, s2_cfg);
        res.alpha(k, :) = a_k.';
        res.H(k, :)     = h_k.';
    end

    % Current headroom margin
    res.Imargin_bess = max(0.0, res.kI_bess);
    res.Imargin_pv   = max(0.0, res.kI_pv);
    res.Imargin_wind = max(0.0, res.kI_wind);

    % Performance metrics on operational window (t > 0.20s)
    tail = t > 0.20;
    res.f_min = min(res.fbess(tail));
    res.f_max = max(res.fbess(tail));
    res.f_dev_max = max(abs(res.fbess(tail) - 50.0));
    res.V_min = min(res.Vpcc_pv(tail));
    res.V_max = max(res.Vpcc_pv(tail));

    % Rigorous Integral Renewable Energy Utilization Definition:
    % eta_RE = int(P_PV + P_W) dt / int(P_PV,avail + P_W,avail) dt
    E_re_gen   = trapz(t(tail), res.Ppv(tail) + res.Pwind(tail));
    E_re_avail = trapz(t(tail), res.Pavail_pv(tail) + res.Pavail_wind(tail));
    res.eta_RE_total = E_re_gen / max(1.0, E_re_avail);

    % Also compute over active coordination window (0.30s <= t <= 1.00s) where Wind headroom exists
    win_coord = (t >= 0.30) & (t <= 1.00);
    res.eta_RE_coord_window = trapz(t(win_coord), res.Ppv(win_coord) + res.Pwind(win_coord)) / ...
                              max(1.0, trapz(t(win_coord), res.Pavail_pv(win_coord) + res.Pavail_wind(win_coord)));

    % 100 ms Sliding-Window RoCoF calculation (Grid-Code compliant)
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

    fprintf('  f_min=%.3f Hz, f_max=%.3f Hz, max|df|=%.3f Hz, RoCoF_100ms_max=%.2f Hz/s\n', ...
        res.f_min, res.f_max, res.f_dev_max, res.rocof_max);
    fprintf('  V_min=%.1f V, V_max=%.1f V | eta_RE (total)=%.2f%%, eta_RE (0.3-1.0s)=%.2f%%\n', ...
        res.V_min, res.V_max, 100*res.eta_RE_total, 100*res.eta_RE_coord_window);

    S.(gName) = res;
end

% Alias GroupC_Capability to GroupC0_Priority for backward compatibility
S.GroupC_Capability = S.GroupC0_Priority;

% Save processed results
matFile = fullfile(artifactDir, 'stage2_stress_results.mat');
save(matFile, 'S', '-v7.3');
fprintf('\nResults saved to %s\n', matFile);

% Generate publication figure
plot_stress_comparison(S, fullfile(artifactDir, 'stage2_coordination_stress_comparison.png'));

end

function plot_stress_comparison(S, figPath)
fprintf('Generating 4-group comparison plot: %s...\n', figPath);

f = figure('Color', 'w', 'Position', [50, 50, 1250, 980], 'Visible', 'off');
figCleanup = onCleanup(@() close(f));

tA  = S.GroupA_Natural.t;
tB  = S.GroupB_Fixed.t;
tC0 = S.GroupC0_Priority.t;
tC1 = S.GroupC1_Weighted.t;

colA  = [0.85, 0.33, 0.10]; % Red-Orange (Group A)
colB  = [0.93, 0.69, 0.13]; % Gold (Group B)
colC0 = [0.00, 0.45, 0.74]; % Blue (Group C0 Priority)
colC1 = [0.47, 0.67, 0.19]; % Green (Group C1 Weighted)

% --- Panel 1: BESS Active Power Balancing Burden ---
subplot(3, 2, 1); hold on; grid on; box on;
plot(tA,  S.GroupA_Natural.Pbess/1e6,  'Color', colA,  'LineWidth', 1.2, 'DisplayName', 'Group A (Natural AC)');
plot(tB,  S.GroupB_Fixed.Pbess/1e6,    'Color', colB,  'LineWidth', 1.2, 'DisplayName', 'Group B (Fixed 50/50)');
plot(tC0, S.GroupC0_Priority.Pbess/1e6,'Color', colC0, 'LineWidth', 1.6, 'DisplayName', 'Group C0 (Priority)');
plot(tC1, S.GroupC1_Weighted.Pbess/1e6,'Color', colC1, 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Group C1 (Weighted)');
title('1. BESS-GFM Active Power Balancing Burden P_{BESS}', 'FontWeight', 'bold');
ylabel('Power (MW)'); xlim([0, 2.5]); ylim([0.5, 4.6]);
legend('Location', 'northwest', 'FontSize', 7.5);

% --- Panel 2: Microgrid Frequency ---
subplot(3, 2, 2); hold on; grid on; box on;
plot(tA,  S.GroupA_Natural.fbess,  'Color', colA,  'LineWidth', 1.2, 'DisplayName', 'Group A');
plot(tB,  S.GroupB_Fixed.fbess,    'Color', colB,  'LineWidth', 1.2, 'DisplayName', 'Group B');
plot(tC0, S.GroupC0_Priority.fbess,'Color', colC0, 'LineWidth', 1.6, 'DisplayName', 'Group C0');
plot(tC1, S.GroupC1_Weighted.fbess,'Color', colC1, 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Group C1');
yline(50.0, 'k:', 'Nominal 50 Hz');
title('2. Microgrid AC Frequency f_{BESS} (Hz)', 'FontWeight', 'bold');
ylabel('Frequency (Hz)'); xlim([0, 2.5]); ylim([49.5, 50.05]);
legend('Location', 'northeast', 'FontSize', 7.5);

% --- Panel 3: PV Output vs Solar Availability ---
subplot(3, 2, 3); hold on; grid on; box on;
plot(tB,  S.GroupB_Fixed.Pcmd_pv/1e6,    'Color', colB,  'LineStyle', ':', 'LineWidth', 1.4, 'DisplayName', 'Group B Commanded');
plot(tB,  S.GroupB_Fixed.Ppv/1e6,        'Color', colB,  'LineWidth', 1.2, 'DisplayName', 'Group B Injected');
plot(tC0, S.GroupC0_Priority.Ppv/1e6,    'Color', colC0, 'LineWidth', 1.5, 'DisplayName', 'Group C0 Injected');
plot(tC1, S.GroupC1_Weighted.Ppv/1e6,    'Color', colC1, 'LineStyle', '--', 'LineWidth', 1.4, 'DisplayName', 'Group C1 Injected');
plot(tC0, S.GroupC0_Priority.Pavail_pv/1e6, 'k--', 'LineWidth', 1.1, 'DisplayName', 'PV Available');
title('3. PV Active Power Dispatch vs Solar Availability', 'FontWeight', 'bold');
ylabel('Power (MW)'); xlim([0, 2.5]); ylim([0, 3.5]);
legend('Location', 'northeast', 'FontSize', 7);

% --- Panel 4: Wind Output vs Wind Availability ---
subplot(3, 2, 4); hold on; grid on; box on;
plot(tA,  S.GroupA_Natural.Pwind/1e6,   'Color', colA,  'LineWidth', 1.2, 'DisplayName', 'Group A');
plot(tB,  S.GroupB_Fixed.Pwind/1e6,     'Color', colB,  'LineWidth', 1.2, 'DisplayName', 'Group B');
plot(tC0, S.GroupC0_Priority.Pwind/1e6, 'Color', colC0, 'LineWidth', 1.6, 'DisplayName', 'Group C0 (Priority)');
plot(tC1, S.GroupC1_Weighted.Pwind/1e6, 'Color', colC1, 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Group C1 (Weighted)');
plot(tC0, S.GroupC0_Priority.Pavail_wind/1e6, 'k--', 'LineWidth', 1.1, 'DisplayName', 'Wind Available');
title('4. Wind Active Power Dispatch vs Wind Availability', 'FontWeight', 'bold');
ylabel('Power (MW)'); xlim([0, 2.5]); ylim([0.5, 3.4]);
legend('Location', 'northeast', 'FontSize', 7);

% --- Panel 5: Dynamic Participation Factors alpha_i(t) in Group C1 ---
subplot(3, 2, 5); hold on; grid on; box on;
plot(tC1, S.GroupC1_Weighted.alpha(:, 3), 'Color', colC0, 'LineWidth', 1.5, 'DisplayName', '\alpha_{Wind} (C1)');
plot(tC1, S.GroupC1_Weighted.alpha(:, 2), 'Color', colB,  'LineWidth', 1.5, 'DisplayName', '\alpha_{PV} (C1)');
plot(tC1, S.GroupC1_Weighted.alpha(:, 1), 'Color', colA,  'LineWidth', 1.5, 'DisplayName', '\alpha_{BESS} (C1)');
title('5. Group C1 Capability-Weighted Participation Factors \alpha_i(t)', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Participation \alpha_i'); xlim([0, 2.5]); ylim([-0.05, 1.05]);
legend('Location', 'east', 'FontSize', 7.5);

% --- Panel 6: 10 kV PCC Bus Voltage ---
subplot(3, 2, 6); hold on; grid on; box on;
plot(tA,  S.GroupA_Natural.Vpcc_pv/1e3,   'Color', colA,  'LineWidth', 1.2, 'DisplayName', 'Group A');
plot(tB,  S.GroupB_Fixed.Vpcc_pv/1e3,     'Color', colB,  'LineWidth', 1.2, 'DisplayName', 'Group B');
plot(tC0, S.GroupC0_Priority.Vpcc_pv/1e3, 'Color', colC0, 'LineWidth', 1.5, 'DisplayName', 'Group C0');
plot(tC1, S.GroupC1_Weighted.Vpcc_pv/1e3, 'Color', colC1, 'LineStyle', '--', 'LineWidth', 1.4, 'DisplayName', 'Group C1');
yline(10.0, 'k:', 'Nominal 10 kV');
title('6. 10 kV PCC Bus Voltage Magnitude', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Voltage (kV)'); xlim([0, 2.5]); ylim([8.4, 10.5]);
legend('Location', 'southwest', 'FontSize', 7.5);

exportgraphics(f, figPath, 'Resolution', 300);
fprintf('Figure successfully exported: %s\n', figPath);
end
