function test_stage2_coordinator_algorithm()
%TEST_STAGE2_COORDINATOR_ALGORITHM Exhaustive verification suite for 3-group coordination.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'scripts'));
run(fullfile(root, 'scripts', 'define_stage2_resource_api.m'));

config = S2_API.coordinator_config;

% Nominal Baseline Status: 5 MW Load (BESS=1MW, PV=2MW, Wind=2MW)
status = zeros(3, 12);
status(:, 7) = 1.0;  % kI = 1.0
status(:, 8) = 1.0;  % Health = 1.0
status(1, 9) = 0.55; % SOC = 55%
status(1, 1) = 1.0e6;
status(2, 1) = 2.0e6;
status(3, 1) = 2.0e6;
status(2, 5) = 3.0e6; % PV avail = 3 MW
status(3, 5) = 2.0e6; % Wind avail = 2 MW

cmdIn = [1.0e6, 0.0, 1.0, 0.0;
         2.0e6, 0.0, 1.0, 0.0;
         2.0e6, 0.0, 1.0, 0.0];

% -------------------------------------------------------------------------
% Test 1: Group A - Autonomous Pass-Through & PV Reverse Power Prevention
% -------------------------------------------------------------------------
cmdIn_rev = cmdIn;
cmdIn_rev(2,1) = -0.5e6; % Invalid negative PV command
outA = stage2_coordinator_algorithm(status, cmdIn_rev, 0, config);
assert(outA(2,1) >= 0.0, 'Group A must reject negative active power for PV.');
assert(all(outA(:,4) == config(1)), 'Group A must set mode to AUTONOMOUS (0).');

% -------------------------------------------------------------------------
% Test 2: Group B - Fixed Ratio when Deficit Occurs (coordEnable = 2)
% -------------------------------------------------------------------------
status_def = status;
status_def(1, 1) = 2.0e6; % 1 MW deficit manifests on BESS
status_def(2, 5) = 0.8e6; % Irradiance drops to 0.8 MW
outB = stage2_coordinator_algorithm(status_def, cmdIn, 2, config);
assert(abs(outB(2,1) - 2.5e6) < 1e-3, 'Group B should split deficit 50/50 to PV.');
assert(abs(outB(3,1) - 2.5e6) < 1e-3, 'Group B should split deficit 50/50 to Wind.');

% -------------------------------------------------------------------------
% Test 3: Group C - PV Irradiance Drop Clamping to Available Power (coordEnable = 1)
% -------------------------------------------------------------------------
outC = stage2_coordinator_algorithm(status_def, cmdIn, 1, config);
assert(abs(outC(2,1) - 0.8e6) < 1e-3, 'Group C should clamp PV command to Pavail (0.8 MW).');
assert(abs(outC(3,1) - 2.0e6) < 1e-3, 'Group C should not overload Wind when headroom is 0.');
assert(abs(outC(1,1) - 3.2e6) < 1e-3, 'Group C should allocate remaining deficit to BESS.');

% -------------------------------------------------------------------------
% Test 4: Group C - Wind Headroom Priority
% -------------------------------------------------------------------------
status_wind_rich = status_def;
status_wind_rich(3, 5) = 3.5e6; % 1.5 MW headroom
outC_rich = stage2_coordinator_algorithm(status_wind_rich, cmdIn, 1, config);
assert(abs(outC_rich(3,1) - 3.5e6) < 1e-3, 'Group C should utilize available Wind headroom.');
assert(abs(outC_rich(1,1) - 1.7e6) < 1e-3, 'Group C BESS should only absorb residual deficit.');

% -------------------------------------------------------------------------
% Test 5: Group C - Low SOC Buffer Blocking Deficit Allocation
% -------------------------------------------------------------------------
status_low_soc = status_def;
status_low_soc(1, 9) = 0.21; % Below socMin + 0.02
outC_low = stage2_coordinator_algorithm(status_low_soc, cmdIn, 1, config);
assert(outC_low(1,1) <= 1.0e6, 'Group C should block additional BESS discharge below SOC buffer.');

% -------------------------------------------------------------------------
% Test 6: Deep SOC Depletion Clamping Active Power to Zero
% -------------------------------------------------------------------------
status_crit_soc = status;
status_crit_soc(1, 9) = 0.18; % Below socMin (0.20)
outC_crit = stage2_coordinator_algorithm(status_crit_soc, cmdIn, 1, config);
assert(outC_crit(1,1) <= 0.0, 'Deep SOC depletion must prohibit active BESS discharge.');

% -------------------------------------------------------------------------
% Test 7: High SOC Boundary Clamping Charging to Zero
% -------------------------------------------------------------------------
status_high_soc = status;
status_high_soc(1, 9) = 0.95; % Above socMax (0.90)
cmdIn_chg = cmdIn;
cmdIn_chg(1,1) = -1.0e6; % Attempting 1 MW charging
outC_high = stage2_coordinator_algorithm(status_high_soc, cmdIn_chg, 1, config);
assert(outC_high(1,1) >= 0.0, 'Over-SOC must prohibit BESS charging.');

% -------------------------------------------------------------------------
% Test 8: Current Limit Factor (kI) Derating Hard Active Power Clamp
% -------------------------------------------------------------------------
status_derated = status;
status_derated(1, 7) = 0.5; % 50% current rating -> Seff = 3.125 MVA
cmdIn_heavy = cmdIn;
cmdIn_heavy(1,1) = 4.5e6; % Demanding 4.5 MW
out_derated = stage2_coordinator_algorithm(status_derated, cmdIn_heavy, 1, config);
assert(out_derated(1,1) <= 3.125e6 + 1e-3, 'Active power must be clamped to derated Seff.');

% -------------------------------------------------------------------------
% Test 9: Circular MVA Reactive Power Clamping
% -------------------------------------------------------------------------
cmdIn_q = cmdIn;
cmdIn_q(1,:) = [3.0e6, 6.0e6, 1.0, 0.0]; % Demanding 6 Mvar with 3 MW P (S=6.7 > 6.25)
out_q = stage2_coordinator_algorithm(status, cmdIn_q, 1, config);
S_actual = hypot(out_q(1,1), out_q(1,2));
assert(S_actual <= config(9) + 1e-3, 'MVA rating violated under reactive power demand.');

% -------------------------------------------------------------------------
% Test 10: Faulted Asset Trip to BLOCKED Mode
% -------------------------------------------------------------------------
status_fault = status;
status_fault(2, 8) = 0.0; % PV Faulted
out_fault = stage2_coordinator_algorithm(status_fault, cmdIn, 1, config);
assert(out_fault(2,3) == 0.0 && out_fault(2,4) == config(3), ...
    'Faulted asset must be disabled and set to BLOCKED (2).');

% -------------------------------------------------------------------------
% Test 11: Robustness to NaN Telemetry
% -------------------------------------------------------------------------
status_nan = status;
status_nan(1, 1) = NaN;
out_nan = stage2_coordinator_algorithm(status_nan, cmdIn, 1, config);
assert(~any(isnan(out_nan(:))), 'Algorithm must handle NaN telemetry without propagation.');

% -------------------------------------------------------------------------
% Test 12: Available-power Clamp Baseline (Regression Test)
% -------------------------------------------------------------------------
status_clamp = zeros(3, 12); status_clamp(:,7) = 1; status_clamp(:,8) = 1;
status_clamp(1,9) = 0.55; status_clamp(2:3,5) = [3e6; 2e6];
cmd_clamp = [1e6, 0, 1, 1; 4e6, 0, 1, 1; 4e6, 0, 1, 1];
out_clamp = stage2_coordinator_algorithm(status_clamp, cmd_clamp, 1, config);
assert(out_clamp(1,1) == 1e6 && out_clamp(2,1) == 3e6 && out_clamp(3,1) == 2e6, ...
    'Available-power clamp regression check failed.');

% -------------------------------------------------------------------------
% Test 13: Group C1 - Continuous Participation Factors (coordEnable = 3)
% -------------------------------------------------------------------------
status_c1 = status;
status_c1(1, 1) = 1.8e6; % 0.8 MW deficit
status_c1(2, 5) = 2.8e6; % PV has 0.8 MW headroom
status_c1(3, 5) = 3.2e6; % Wind has 1.2 MW headroom
[outC1, alphaC1, HC1] = stage2_coordinator_algorithm(status_c1, cmdIn, 3, config);
assert(abs(sum(alphaC1) - 1.0) < 1e-6, 'Group C1 participation factors must sum to 1.');
assert(all(alphaC1 > 0.0) && alphaC1(3) > alphaC1(2), ...
    'Group C1 must weight Wind higher than PV when Wind has greater headroom.');
assert(outC1(2,1) > 2.0e6 && outC1(3,1) > 2.0e6, ...
    'Group C1 must continuously distribute deficit across both capable renewables.');

% -------------------------------------------------------------------------
% Test 14: Group C1 - Zero PV Headroom Gating (PV Cliff at 0.8 MW)
% -------------------------------------------------------------------------
[outC1_cliff, alphaC1_cliff] = stage2_coordinator_algorithm(status_wind_rich, cmdIn, 3, config);
assert(abs(alphaC1_cliff(2)) < 1e-9, 'Group C1 must assign alpha_PV = 0 when PV has no headroom.');
assert(abs(outC1_cliff(2,1) - 0.8e6) < 1e-3, 'Group C1 must clamp PV to 0.8 MW.');
assert(outC1_cliff(3,1) > 2.0e6 && outC1_cliff(3,1) <= 3.5e6 + 1e-3, ...
    'Group C1 must allocate to Wind within available headroom.');

% -------------------------------------------------------------------------
% Test 15: Group C1 - Water-Filling Projection Under Severe Deficit
% -------------------------------------------------------------------------
status_severe = status_def;
status_severe(1, 1) = 3.5e6; % 2.5 MW island deficit
status_severe(3, 5) = 2.6e6; % Wind only has 0.6 MW headroom
[outC1_sev, ~] = stage2_coordinator_algorithm(status_severe, cmdIn, 3, config);
assert(abs(outC1_sev(2,1) - 0.8e6) < 1e-3, 'Group C1 projection must not exceed PV Pavail.');
assert(abs(outC1_sev(3,1) - 2.6e6) < 1e-3, 'Group C1 projection must saturate Wind at Pavail (2.6 MW).');
assert(outC1_sev(1,1) > 2.0e6, 'Group C1 projection must route residual deficit to BESS.');

% -------------------------------------------------------------------------
% Test 16: Group C1-PQ Network-Aware - Coupled MVA Headroom Shifts Q to Idle Resource
% -------------------------------------------------------------------------
% Scenario: PV is curtailed in P (0.8 MW) so it has huge Q headroom (~5.6 Mvar),
% whereas Wind is heavily loaded in P (4.8 MW) so its Q headroom is restricted.
% Both see the same local voltage sag (9.30 kV).
status_pq1 = status;
status_pq1(1, 1) = 2.0e6;
status_pq1(1, 2) = 2.5e6; % 2.5 Mvar reactive load on BESS
status_pq1(:, 3) = [9400; 9300; 9300];
status_pq1(2, 5) = 0.8e6; % PV curtailed in P -> large Q headroom
status_pq1(3, 5) = 4.8e6; % Wind abundant in P -> heavily loaded in P
cmd_pq1 = [1e6, 0, 1, 1; 2e6, 0, 1, 1; 4.5e6, 0, 1, 1];
[outPQ_net, ~, ~, alphaQ_net, HQ_net] = stage2_coordinator_algorithm(status_pq1, cmd_pq1, 5, config);
assert(outPQ_net(2,2) > outPQ_net(3,2), ...
    'C1-PQ network-aware must allocate more Q to PV when Wind is heavily loaded in P.');
assert(hypot(outPQ_net(2,1), outPQ_net(2,2)) <= config(10) + 1.0 && ...
       hypot(outPQ_net(3,1), outPQ_net(3,2)) <= config(11) + 1.0, ...
    'C1-PQ network-aware must strictly respect coupled MVA circle limits.');

% -------------------------------------------------------------------------
% Test 17: Group C1-PQ Local vs Network-Aware - Network Sensitivity Weighting
% -------------------------------------------------------------------------
% Scenario: Both PV and Wind have identical P (2.0 MW) and identical local V (9.40 kV).
% C1-PQ local (Mode 4) splits Q 50/50, whereas C1-PQ network-aware (Mode 5)
% weights Wind higher due to beta_bar_Wind (1.000) > beta_bar_PV (0.858).
status_pq2 = status;
status_pq2(1, 2) = 2.0e6;
status_pq2(:, 3) = [9450; 9400; 9400];
[outPQ_loc, ~, ~, alphaQ_loc] = stage2_coordinator_algorithm(status_pq2, cmdIn, 4, config);
[outPQ_net2, ~, ~, alphaQ_net2] = stage2_coordinator_algorithm(status_pq2, cmdIn, 5, config);
assert(abs(alphaQ_loc(2) - 0.5) < 1e-6 && abs(alphaQ_loc(3) - 0.5) < 1e-6, ...
    'C1-PQ local must split Q 50/50 when local voltage errors are equal.');
assert(alphaQ_net2(3) > alphaQ_net2(2) && outPQ_net2(3,2) > outPQ_net2(2,2), ...
    'C1-PQ network-aware must weight Wind higher when headrooms and voltage errors are equal.');

% -------------------------------------------------------------------------
% Test 18: Group C1-PQ Water-Filling Projection When One Converter Q Headroom Saturates
% -------------------------------------------------------------------------
status_pq3 = status_pq1;
status_pq3(1, 2) = 4.5e6; % Heavy 4.5 Mvar reactive demand
status_pq3(:, 3) = [8700; 8600; 8600];
cmd_pq3 = [1e6, 0, 1, 1; 0.8e6, 0, 1, 1; 5.0e6, 0, 1, 1];
status_pq3(3, 5) = 5.0e6; % Wind at 5.0 MW -> small voltage-derated Q headroom at 0.86 pu V
[outPQ_sat, ~, ~, ~, ~] = stage2_coordinator_algorithm(status_pq3, cmd_pq3, 5, config);
S_wind_eff = 0.96 * config(11) * (8600 / 10000);
Q_wind_cap = sqrt(max(0.0, S_wind_eff^2 - (5.0e6)^2));
assert(abs(outPQ_sat(3,2) - Q_wind_cap) < 1.0, ...
    'C1-PQ network-aware must cap Wind Q at its voltage-derated coupled headroom.');
assert(outPQ_sat(2,2) > 4.0e6, ...
    'C1-PQ network-aware water-filling must spill remaining Q demand onto PV.');

% -------------------------------------------------------------------------
% Test 19: Group C1-LVRT (Mode 6) - Deep Voltage Sag Q-Priority & Orthogonal P De-Loading
% -------------------------------------------------------------------------
status_lvrt = status;
status_lvrt(:, 3) = [6600; 6400; 6200]; % Deep symmetrical fault sag (~0.62-0.64 pu)
status_lvrt(2, 5) = 3.5e6;
status_lvrt(3, 5) = 4.0e6;
cmd_lvrt = [1e6, 0, 1, 1; 3.2e6, 0, 1, 1; 3.6e6, 0, 1, 1];
[outLVRT_Ponly] = stage2_coordinator_algorithm(status_lvrt, cmd_lvrt, 3, config);
[outLVRT_6, ~, ~, alphaQ_lvrt] = stage2_coordinator_algorithm(status_lvrt, cmd_lvrt, 6, config);
assert(outLVRT_6(2,2) > 1.5e6 && outLVRT_6(3,2) > 1.5e6, ...
    'C1-LVRT must inject strong fault reactive current support during deep voltage sag.');
assert(outLVRT_6(2,1) < outLVRT_Ponly(2,1) && outLVRT_6(3,1) < outLVRT_Ponly(3,1), ...
    'C1-LVRT must orthogonally de-load active power during deep sag to prevent overcurrent.');
S_lvrt_pv   = 0.84 * config(10) * (6400 / 10000);
S_lvrt_wind = 0.84 * config(11) * (6200 / 10000);
assert(hypot(outLVRT_6(2,1), outLVRT_6(2,2)) <= S_lvrt_pv + 1.0 && ...
       hypot(outLVRT_6(3,1), outLVRT_6(3,2)) <= S_lvrt_wind + 1.0, ...
    'C1-LVRT must strictly respect voltage-derated converter MVA circle during fault.');
assert(alphaQ_lvrt(3) > alphaQ_lvrt(2), ...
    'C1-LVRT must prioritize reactive support on weaker Wind node (higher beta_bar and deeper sag).');

% -------------------------------------------------------------------------
% Test 20: Group C1-LVRT (Mode 6) - Seamless Return to Mode 5 When Voltage >= 0.84 pu
% -------------------------------------------------------------------------
[outM5_norm] = stage2_coordinator_algorithm(status_pq2, cmdIn, 5, config);
[outM6_norm] = stage2_coordinator_algorithm(status_pq2, cmdIn, 6, config);
assert(max(abs(outM5_norm(:) - outM6_norm(:))) < 1e-6, ...
    'C1-LVRT must match Mode 5 Network-Aware P-Q dispatch when PCC voltage is above fault threshold.');

% -------------------------------------------------------------------------
% Test 21: BESS 3 pu Overload Capability Awareness (Mode 6)
% -------------------------------------------------------------------------
status_lvrt_3pu = status_lvrt;
status_lvrt_3pu(1, 11) = 1.0; % 100% of BESS 3 pu / 10 s overload budget available
[outLVRT_3pu] = stage2_coordinator_algorithm(status_lvrt_3pu, cmd_lvrt, 6, config);

% With BESS carrying primary 3 pu fault current, GFL reactive support is moderated:
assert(outLVRT_3pu(3, 2) < outLVRT_6(3, 2), ...
    'C1-LVRT with 3 pu BESS must moderate GFL reactive burden while BESS carries primary fault current.');
% More orthogonal headroom is preserved for renewable active power:
assert(outLVRT_3pu(3, 1) > outLVRT_6(3, 1), ...
    'C1-LVRT with 3 pu BESS must preserve more renewable active power generation during short faults.');
S_lvrt_wind_3pu = 0.94 * config(11) * (6200 / 10000);
assert(hypot(outLVRT_3pu(3,1), outLVRT_3pu(3,2)) <= S_lvrt_wind_3pu + 1.0, ...
    'C1-LVRT with 3 pu BESS must strictly respect the relaxed MVA boundary.');

% -------------------------------------------------------------------------
% Test 22: Dynamic Hand-off as BESS 10 s Overload Budget Depletes
% -------------------------------------------------------------------------
budgets = [1.0, 0.7, 0.3, 0.0];
q_wind_trace = zeros(size(budgets));
p_wind_trace = zeros(size(budgets));
for bIdx = 1:numel(budgets)
    st = status_lvrt;
    st(1, 11) = budgets(bIdx);
    out = stage2_coordinator_algorithm(st, cmd_lvrt, 6, config);
    q_wind_trace(bIdx) = out(3, 2);
    p_wind_trace(bIdx) = out(3, 1);
end
assert(all(diff(q_wind_trace) >= -1e-6), ...
    'Wind reactive power command must increase monotonically as BESS overload budget depletes.');
assert(all(diff(p_wind_trace) <= 1e-6), ...
    'Wind active power command must decrease monotonically and smoothly as BESS overload budget depletes.');

% -------------------------------------------------------------------------
% Test 23: Invariance Under Normal (Non-Sag) Conditions
% -------------------------------------------------------------------------
status_norm_3pu = status_pq2;
status_norm_3pu(1, 11) = 1.0;
[outM6_norm_3pu] = stage2_coordinator_algorithm(status_norm_3pu, cmdIn, 6, config);
assert(max(abs(outM6_norm(:) - outM6_norm_3pu(:))) < 1e-6, ...
    'BESS overload budget must not alter normal steady-state Mode 5/6 dispatch when voltage is nominal.');

fprintf('ALL_12_STAGE2_COORDINATOR_UNIT_TESTS_PASS=1\n');
fprintf('ALL_15_STAGE2_COORDINATOR_UNIT_TESTS_PASS=1\n');
fprintf('ALL_18_STAGE2_COORDINATOR_UNIT_TESTS_PASS=1\n');
fprintf('ALL_20_STAGE2_COORDINATOR_UNIT_TESTS_PASS=1\n');
fprintf('ALL_23_STAGE2_COORDINATOR_UNIT_TESTS_PASS=1\n');
end
