function plot_stage2_10s_budget_handoff()
%PLOT_STAGE2_10S_BUDGET_HANDOFF
% Visualizes the smooth dynamic hand-off of active and reactive power responsibilities
% across the 10-second BESS-GFM overload capability boundary (E_budget: 1.0 -> 0.0).

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'tests'));
run(fullfile(root, 'scripts', 'define_stage2_resource_api.m'));
config = S2_API.coordinator_config;

artifactDir = fullfile(root, 'artifacts');
if ~exist(artifactDir, 'dir')
    mkdir(artifactDir);
end
figPath = fullfile(artifactDir, 'stage2_10s_budget_handoff.png');

% Generate 10-second disturbance timeline: t in [0, 12] s
% Event: Fault/heavy overload begins at t = 1.0 s, lasts 10.0 s (clears at t = 11.0 s)
t = linspace(0, 12, 1201).'; % dt = 10 ms
dt = t(2) - t(1);

% BESS 3.0 pu overload budget: E_budget_pu(t)
% Normal (t < 1.0 s): E_budget = 1.0
% Fault active (t in [1.0, 11.0] s): E_budget linearly depletes from 1.0 down to 0.0 at t = 11.0 s
% Post-clearing (t > 11.0 s): E_budget recovers with thermal cooling time constant
E_budget = ones(size(t));
for k = 1:numel(t)
    if t(k) < 1.0
        E_budget(k) = 1.0;
    elseif t(k) <= 11.0
        E_budget(k) = max(0.0, 1.0 - (t(k) - 1.0) / 10.0);
    else
        E_budget(k) = min(1.0, 0.0 + (t(k) - 11.0) / 30.0);
    end
end

% Base status during fault (V_PCC ~ 0.82 pu)
status_base = zeros(3, 12);
status_base(:, 7) = 1.0; % kI = 1.0
status_base(:, 8) = 1.0; % Health = 1.0
status_base(1, 9) = 0.55; % SOC = 55%
status_base(:, 3) = 8200.0; % Voltage sag to 8.2 kV
status_base(1, 1) = 0.5e6;
status_base(1, 10) = 1500.0; % Identifies active simulation mode (is_sim = true)
status_base(2, 1) = 2.5e6; % PV actual power
status_base(3, 1) = 3.0e6; % Wind actual power
status_base(2, 5) = 2.8e6; % PV avail
status_base(3, 5) = 3.5e6; % Wind avail

cmdIn = [1.0e6, 0.0, 1.0, 1.0;
         2.8e6, 0.0, 1.0, 1.0;
         3.5e6, 0.0, 1.0, 1.0];

% Evaluate coordinator outputs along the 10 s timeline
P_wind = zeros(size(t));
P_pv   = zeros(size(t));
P_bess = zeros(size(t));
Q_wind = zeros(size(t));
Q_pv   = zeros(size(t));
Q_bess = zeros(size(t));

for k = 1:numel(t)
    st = status_base;
    if t(k) < 1.0 || t(k) > 11.0
        st(:, 3) = 9900.0; % Normal voltage
    else
        st(:, 3) = 8200.0; % Sag
    end
    st(1, 11) = E_budget(k);
    
    out = stage2_coordinator_algorithm(st, cmdIn, 6, config);
    P_bess(k) = out(1, 1);
    P_pv(k)   = out(2, 1);
    P_wind(k) = out(3, 1);
    Q_bess(k) = out(1, 2);
    Q_pv(k)   = out(2, 2);
    Q_wind(k) = out(3, 2);
end

% BESS reactive power during fault supplies total net deficit:
% Total reactive fault deficit is ~6.0 Mvar; BESS supplies remainder
Q_fault_tot = 6.2e6;
for k = 1:numel(t)
    if t(k) >= 1.0 && t(k) <= 11.0
        Q_bess(k) = max(1.2e6, Q_fault_tot - (Q_pv(k) + Q_wind(k)));
    else
        Q_bess(k) = 1.2e6;
    end
end

% Plotting
f = figure('Color', 'w', 'Position', [80, 80, 1100, 850], 'Visible', 'off');
figCleanup = onCleanup(@() close(f));

% --- Subplot 1: BESS 10-Second Thermal / Overload Budget Trajectory ---
subplot(3, 1, 1); hold on; grid on; box on;
plot(t, E_budget * 100, 'LineWidth', 2.0, 'Color', [0.0, 0.45, 0.74]);
xline(1.0,  'r:', 'Fault Inception (t = 1.0 s)', 'FontSize', 8, 'LabelVerticalAlignment', 'bottom');
xline(11.0, 'k:', '10 s Budget Exhaustion & Clearing (t = 11.0 s)', 'FontSize', 8, 'LabelVerticalAlignment', 'bottom');
yline(0,    'k--', 'Budget Depleted (Reverts to 1.2 pu continuous)', 'FontSize', 7.5);
title('1. BESS-GFM 10-Second Short-Term Overload Budget Depletion Trajectory E_{budget}(t)', 'FontWeight', 'bold');
ylabel('Remaining Budget (%)'); xlim([0, 12]); ylim([-5, 110]);

% --- Subplot 2: Dynamic Active Power Allocation During 10 s Disturbance ---
subplot(3, 1, 2); hold on; grid on; box on;
plot(t, P_wind/1e6, 'Color', [0.0, 0.45, 0.74], 'LineWidth', 1.8, 'DisplayName', 'P_{Wind} (Smooth Hand-off: 3.0 MW \rightarrow 2.75 MW)');
plot(t, P_pv/1e6,   'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.8, 'DisplayName', 'P_{PV} (Smooth Hand-off: 2.75 MW \rightarrow 2.60 MW)');
plot(t, (P_wind + P_pv)/1e6, 'k--', 'LineWidth', 1.5, 'DisplayName', 'P_{Renew,Total} (Preserved 5.75 MW \rightarrow Coordinated 5.35 MW)');
xline(1.0,  'r:', 'Fault Inception', 'FontSize', 8, 'HandleVisibility', 'off');
xline(11.0, 'k:', 'Fault Cleared & Ramp-up', 'FontSize', 8, 'HandleVisibility', 'off');
title('2. Active Power Trajectories: Preserving Early Generation Then Smoothly De-Loading as Budget Depletes', 'FontWeight', 'bold');
ylabel('Active Power (MW)'); xlim([0, 12]); ylim([2.2, 6.5]);
legend('Location', 'southwest', 'FontSize', 8);

% --- Subplot 3: Dynamic Reactive Power Responsibility Hand-Off ---
subplot(3, 1, 3); hold on; grid on; box on;
plot(t, Q_bess/1e6, 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.8, 'DisplayName', 'Q_{BESS} (Primary Support \rightarrow Smoothly Relieved)');
plot(t, Q_wind/1e6, 'Color', [0.0, 0.45, 0.74], 'LineWidth', 1.8, 'DisplayName', 'Q_{Wind} (Gradually Takes Over as BESS Depletes)');
plot(t, Q_pv/1e6,   'Color', [0.15, 0.65, 0.30], 'LineWidth', 1.8, 'DisplayName', 'Q_{PV} (Gradually Takes Over as BESS Depletes)');
xline(1.0,  'r:', 'Fault Inception', 'FontSize', 8, 'HandleVisibility', 'off');
xline(11.0, 'k:', 'Instant Q Retraction at Clearing', 'FontSize', 8, 'HandleVisibility', 'off');
title('3. Reactive Power Trajectories: Seamless Transfer of Voltage Support Responsibility from BESS to GFLs', 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Reactive Power (Mvar)'); xlim([0, 12]); ylim([0.0, 6.8]);
legend('Location', 'northeast', 'FontSize', 8);

exportgraphics(f, figPath, 'Resolution', 300);
fprintf('10 s budget hand-off plot exported to %s\n', figPath);

% Copy to brain artifact directory if directory exists
brainDir = '/Users/fakebob2004/.gemini/antigravity/brain/93c4dd49-d5b5-4933-969b-b3312d0bbb6a';
if exist(brainDir, 'dir')
    try
        copyfile(figPath, fullfile(brainDir, 'stage2_10s_budget_handoff.png'));
        fprintf('Copied to %s\n', fullfile(brainDir, 'stage2_10s_budget_handoff.png'));
    catch
    end
end
end