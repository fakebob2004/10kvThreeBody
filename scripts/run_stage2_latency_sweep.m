function LatencyResults = run_stage2_latency_sweep()
%RUN_STAGE2_LATENCY_SWEEP Sweeps coordinator execution period and communication
% latency across Tc in {1, 5, 10, 20, 50} ms under the 2.5s multi-event stress scenario.

scriptDir = fileparts(mfilename('fullpath'));
root = fileparts(scriptDir);
addpath(scriptDir);
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'build'));
addpath(fullfile(root, 'tests'));
set_param(0, 'ErrorIfLoadNewModel', 'off');

model = 'BESS_PV_WIND_STAGE2_R2_API';
modelFile = get_stage2_model_path(model);
assert(isfile(modelFile), 'Missing model file: %s', modelFile);

if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
run(fullfile(root, 'scripts', 'init_bess_pv_wind_stage2_r1.m'));

% Guaranteed cleanup restoring model and workspace parameters
cleanupObj = onCleanup(@() cleanup_latency_test(model));

% Configure the 2.5s sequential multi-event scenario
setup_stage2_stress_scenario(model);

artifactDir = fullfile(root, 'artifacts');
if ~exist(artifactDir, 'dir')
    mkdir(artifactDir);
end

apiSub = [model '/07 Resource API Layer'];

% Group C: Capability-Aware Dynamic Allocation
set_param([apiSub '/Coordinator Enable'], 'Value', '1');
set_param([apiSub '/Resource Modes'], 'Value', '[0 1 1]');

% Latency test cases: Tc = [1, 5, 10, 20, 50] ms
periods_s = [0.001, 0.005, 0.010, 0.020, 0.050];
period_names = {'Tc_1ms', 'Tc_5ms', 'Tc_10ms', 'Tc_20ms', 'Tc_50ms'};
statusDelayNames = {'BESS Status Snapshot', 'PV Status Snapshot', 'Wind Status Snapshot'};

LatencyResults = struct();

fprintf('\n============================================================\n');
fprintf('BEGINNING STAGE 2 REAL-TIME LATENCY & SAMPLING SWEEP\n');
fprintf('Tc in {1, 5, 10, 20, 50} ms (Group C: Capability-Aware)\n');
fprintf('============================================================\n');

for k = 1:numel(periods_s)
    tc = periods_s(k);
    tName = period_names{k};
    fprintf('\n--- Simulating Tc = %.1f ms (%s) ---\n', tc * 1e3, tName);

    % Update S2_API.sample_time_s directly in base workspace
    s2 = evalin('base', 'S2_API');
    s2.sample_time_s = tc;
    assignin('base', 'S2_API', s2);
    assignin('base', 'S2_API_sample_time_s', tc);

    % Update all snapshot delays and periodic inputs
    for d = 1:numel(statusDelayNames)
        set_param([apiSub '/' statusDelayNames{d}], 'SampleTime', num2str(tc));
    end
    set_param([apiSub '/BESS Desired Command'], 'SampleTime', num2str(tc));
    set_param([apiSub '/Resource Modes'], 'SampleTime', num2str(tc));

    tic;
    simOut = sim(model);
    el = toc;
    fprintf('  Simulation finished in %.2f s.\n', el);

    raw = squeeze(simOut.get('stage2_result'));
    if size(raw, 2) ~= 54, raw = raw.'; end

    api = squeeze(simOut.get('resource_api_result'));
    if size(api, 2) ~= 48, api = api.'; end

    t = raw(:, 1);
    api = sync_api_to_continuous_time(api, t);

    res = struct();
    res.tc = tc;
    res.t = t;
    res.Pbess = raw(:, 2);
    res.Qbess = raw(:, 3);
    res.fbess = raw(:, 4);
    res.soc   = raw(:, 6);
    res.kI_bess = raw(:, 14);

    res.Ppv   = raw(:, 17);
    res.Qpv   = raw(:, 18);
    res.fpv   = raw(:, 22);
    res.kI_pv = raw(:, 28);
    res.Vpcc_pv = raw(:, 30);

    res.Pwind = raw(:, 33);
    res.Qwind = raw(:, 34);
    res.fwind = raw(:, 38);
    res.kI_wind = raw(:, 44);
    res.Pwind_avail = raw(:, 48);

    res.Pload = raw(:, 53);
    res.Qload = raw(:, 54);

    res.Pcmd_bess = api(:, 1);
    res.Pcmd_pv   = api(:, 5);
    res.Pcmd_wind = api(:, 9);

    tail = t > 0.20;
    res.f_min = min(res.fbess(tail));
    res.f_max = max(res.fbess(tail));
    res.f_dev_max = max(abs(res.fbess(tail) - 50.0));
    res.V_min = min(res.Vpcc_pv(tail));
    res.V_max = max(res.Vpcc_pv(tail));

    % 100 ms Sliding-Window RoCoF calculation
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

    res.kI_max_bess = max(res.kI_bess(tail));
    res.kI_max_pv   = max(res.kI_pv(tail));
    res.kI_max_wind = max(res.kI_wind(tail));

    fprintf('  f_min = %.3f Hz, f_max = %.3f Hz, max|df| = %.3f Hz\n', ...
        res.f_min, res.f_max, res.f_dev_max);
    fprintf('  RoCoF_100ms_max = %.2f Hz/s, V_min = %.1f V, V_max = %.1f V\n', ...
        res.rocof_max, res.V_min, res.V_max);
    fprintf('  kI_min [BESS, PV, Wind] = [%.3f, %.3f, %.3f]\n', ...
        min(res.kI_bess(tail)), min(res.kI_pv(tail)), min(res.kI_wind(tail)));

    LatencyResults.(tName) = res;
end

% Save MAT file
matPath = fullfile(artifactDir, 'stage2_latency_sweep_results.mat');
save(matPath, 'LatencyResults', '-v7.3');
fprintf('\nLatency sweep results saved to %s\n', matPath);

% Generate 4-panel comparison plot
figPath = fullfile(artifactDir, 'stage2_latency_sweep_comparison.png');
plot_latency_comparison(LatencyResults, figPath);

end

function cleanup_latency_test(model)
if bdIsLoaded(model)
    apiSub = [model '/07 Resource API Layer'];
    statusDelayNames = {'BESS Status Snapshot', 'PV Status Snapshot', 'Wind Status Snapshot'};
    try
        s2 = evalin('base', 'S2_API');
        s2.sample_time_s = 0.005;
        assignin('base', 'S2_API', s2);
        for d = 1:numel(statusDelayNames)
            set_param([apiSub '/' statusDelayNames{d}], 'SampleTime', 'S2_API.sample_time_s');
        end
        set_param([apiSub '/BESS Desired Command'], 'SampleTime', 'S2_API.sample_time_s');
        set_param([apiSub '/Resource Modes'], 'SampleTime', 'S2_API.sample_time_s');
    catch
    end
    close_system(model, 0);
end
end

function plot_latency_comparison(L, figPath)
fprintf('Generating latency comparison plot: %s...\n', figPath);

f = figure('Color', 'w', 'Position', [60, 60, 1100, 850], 'Visible', 'off');
figCleanup = onCleanup(@() close(f));

fields = fieldnames(L);
colors = {
    [0.00, 0.45, 0.74]; % 1 ms (Dark Blue)
    [0.30, 0.75, 0.93]; % 5 ms (Sky Blue)
    [0.47, 0.67, 0.19]; % 10 ms (Green)
    [0.93, 0.69, 0.13]; % 20 ms (Gold)
    [0.85, 0.33, 0.10]; % 50 ms (Red)
};
labels = {'T_c = 1 ms', 'T_c = 5 ms (Baseline)', 'T_c = 10 ms', 'T_c = 20 ms', 'T_c = 50 ms'};

% Subplot 1: Frequency Trajectory Under Latency
subplot(2, 2, 1); hold on; grid on; box on;
for k = 1:numel(fields)
    res = L.(fields{k});
    plot(res.t, res.fbess, 'Color', colors{k}, 'LineWidth', 1.2, 'DisplayName', labels{k});
end
yline(50.0, 'k:', 'Nominal 50 Hz');
title('1. Microgrid Frequency Under Sampling Latency', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Frequency (Hz)');
xlim([0.2, 2.5]); ylim([49.2, 50.2]);
legend('Location', 'northeast', 'FontSize', 8);

% Subplot 2: Wind Dispatch Tracking vs Latency
subplot(2, 2, 2); hold on; grid on; box on;
for k = [1, 2, 5]
    res = L.(fields{k});
    plot(res.t, res.Pwind/1e6, 'Color', colors{k}, 'LineWidth', 1.3, 'DisplayName', labels{k});
end
resBase = L.(fields{2});
plot(resBase.t, resBase.Pwind_avail/1e6, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Wind Available');
title('2. Wind Converter Response (1ms vs 5ms vs 50ms)', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Power (MW)');
xlim([0.2, 2.5]); ylim([0.5, 3.5]);
legend('Location', 'northeast', 'FontSize', 8);

% Subplot 3: Latency Sensitivity (Dynamic Bounds)
subplot(2, 2, 3); hold on; grid on; box on;
tcs_ms = [1, 5, 10, 20, 50];
fmins = zeros(1, 5);
rocofs = zeros(1, 5);
for k = 1:5
    fmins(k) = L.(fields{k}).f_min;
    rocofs(k) = L.(fields{k}).rocof_max;
end

yyaxis left;
plot(tcs_ms, fmins, 's-', 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.8, 'MarkerFaceColor', [0.00, 0.45, 0.74]);
ylabel('Frequency Nadir f_{min} (Hz)');
ylim([min(fmins) - 0.05, max(fmins) + 0.05]);

yyaxis right;
plot(tcs_ms, rocofs, 'd--', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.8, 'MarkerFaceColor', [0.85, 0.33, 0.10]);
ylabel('Max RoCoF_{100ms} (Hz/s)');
ylim([0.0, max(rocofs) * 1.25 + 0.1]);

title('3. Frequency Nadir & RoCoF vs Latency T_c', 'FontWeight', 'bold');
xlabel('Coordinator Period T_c (ms)');
xticks(tcs_ms);

% Subplot 4: BESS Current Factor vs Latency
subplot(2, 2, 4); hold on; grid on; box on;
for k = 1:numel(fields)
    res = L.(fields{k});
    plot(res.t, res.kI_bess, 'Color', colors{k}, 'LineWidth', 1.2, 'DisplayName', labels{k});
end
yline(1.0, 'r--', 'Current Limit Factor (1.0 = Normal)');
title('4. BESS Inverter Current Limit Factor', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Limit Factor (pu)');
xlim([0.2, 2.5]); ylim([0.8, 1.05]);
legend('Location', 'southwest', 'FontSize', 8);

exportgraphics(f, figPath, 'Resolution', 300);
fprintf('Latency plot exported to %s\n', figPath);
end
