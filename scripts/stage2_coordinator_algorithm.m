function [commandOut, alphaOut, HOut, alphaQOut, HQOut] = stage2_coordinator_algorithm(status, commandIn, coordinatorEnable, config)
%#codegen
%STAGE2_COORDINATOR_ALGORITHM Hierarchical capability- and network-aware P-Q coordinator.
%
% Supported Strategies (coordinatorEnable):
%   0: GROUP A       - Autonomous Pass-Through (Natural AC coupling, physical safety clamp)
%   1: GROUP C0      - Capability-Constrained Priority Dispatch (Wind -> PV -> BESS, P-only)
%   2: GROUP B       - Fixed-Ratio Allocation (Proportional 50/50 renewable benchmark, P-only)
%   3: GROUP C1-P    - Capability-Weighted Adaptive P Coordination (Fixed Q = Q_base)
%   4: GROUP C1-PQ-L - Capability-Weighted P + Uncoupled Local-Voltage Q Allocation
%   5: GROUP C1-PQ-N - Two-Stage Capability- & Network-Aware P-Q Coordination
%
% Dimensions:
%   status:            [3 x 12] double: [BESS; PV; Wind]
%   commandIn:         [3 x 4]  double: [P_ref_W, Q_ref_var, enable, mode]
%   coordinatorEnable: [1 x 1]  double: 0 (A), 1 (C0), 2 (B), 3 (C1-P), 4 (C1-PQ local), 5 (C1-PQ network)
%   config:            [1 x 11] double: [MODE_AUTO, MODE_COORD, MODE_BLOCK,
%                                        SOC_min, SOC_max, Prated(1:3), Srated(1:3)]
%
% Outputs:
%   commandOut:        [3 x 4]  double: [P_cmd_W, Q_cmd_var, enable, mode]
%   alphaOut:          [3 x 1]  double: Active participation factors [alpha_bess; alpha_pv; alpha_wind]
%   HOut:              [3 x 1]  double: Active composite capability indices [H_bess; H_pv; H_wind]
%   alphaQOut:         [3 x 1]  double: Reactive participation factors [alphaQ_bess; alphaQ_pv; alphaQ_wind]
%   HQOut:             [3 x 1]  double: Reactive composite capability indices [HQ_bess; HQ_pv; HQ_wind]

% 1. Config Unpacking & Input Sanitization
modeAuto  = config(1);
modeCoord = config(2);
modeBlock = config(3);
socMin    = config(4);
socMax    = config(5);
pRating   = config(6:8);
sRating   = config(9:11);

commandOut = commandIn;
alphaOut   = zeros(3, 1);
HOut       = zeros(3, 1);
alphaQOut  = zeros(3, 1);
HQOut      = zeros(3, 1);

% Sanitize non-finite inputs
if ~isfinite(coordinatorEnable)
    coordinatorEnable = 0.0; % Safe fallback to autonomous
end

statClean = status;
for r = 1:3
    for c = 1:12
        if ~isfinite(statClean(r,c))
            statClean(r,c) = 0.0;
            if c == 8 % Health signal corrupted -> trip asset
                statClean(r,8) = 0.0;
            end
        end
    end
end

% 2. Safety and Health Check: Disabled or faulted assets
activeMask = ones(3, 1);
for r = 1:3
    health = statClean(r,8);
    en     = commandIn(r,3);
    if health < 0.5
        commandOut(r,:) = [0.0, 0.0, 0.0, modeBlock];
        activeMask(r)   = 0.0;
    elseif en < 0.5
        commandOut(r,:) = [0.0, 0.0, 0.0, modeAuto];
        activeMask(r)   = 0.0;
    end
end

% 3. Extract validated resource states
Pbess_act   = statClean(1,1);
Qbess_act   = statClean(1,2);
Ppv_act     = statClean(2,1);
Qpv_act     = statClean(2,2);
Pwind_act   = statClean(3,1);
Qwind_act   = statClean(3,2);

Ppv_avail   = max(0.0, min(pRating(2), statClean(2,5)));
Pwind_avail = max(0.0, min(pRating(3), statClean(3,5)));

soc_bess    = max(0.0, min(1.0, statClean(1,9)));
kI_bess     = max(0.0, min(1.0, statClean(1,7)));
kI_pv       = max(0.0, min(1.0, statClean(2,7)));
kI_wind     = max(0.0, min(1.0, statClean(3,7)));

% BESS short-term 3 pu / 10 s overload capability state:
% 1. Explicit status input: statClean(1, 11) conveys E_budget in [0, 1].
% 2. Mode setting: coordinatorEnable >= 6.25 signals 3.0 pu capability awareness (E_budget = 1.0).
%    - coordinatorEnable = 6.0: baseline 1.2 pu GFM (bess_overload_budget = 0.0)
%    - coordinatorEnable = 6.3: 3.0 pu / 10 s capability-aware (bess_overload_budget = 1.0)
if statClean(1, 11) > 0.001
    bess_overload_budget = max(0.0, min(1.0, statClean(1, 11)));
elseif coordinatorEnable >= 6.25
    bess_overload_budget = 1.0;
else
    bess_overload_budget = 0.0;
end

kIs = [kI_bess; kI_pv; kI_wind];

% Baseline commands from profile
Pbess_base = commandIn(1,1);
Ppv_base   = commandIn(2,1);
Pwind_base = commandIn(3,1);

% =========================================================================
% STRATEGY 0: GROUP A (Autonomous Pass-Through / Natural AC Coupling)
% =========================================================================
if coordinatorEnable < 0.5
    alphaOut = [1.0; 0.0; 0.0];
    for r = 1:3
        if commandOut(r,3) > 0.5
            kI = kIs(r);
            Seff = sRating(r) * kI;
            Pmax = min(pRating(r), Seff);

            if r == 1
                P = max(-Pmax, min(Pmax, commandIn(r,1)));
            else
                P = max(0.0, min(Pmax, commandIn(r,1)));
            end

            Q_desired = commandIn(r,2);
            Q_max = sqrt(max(0.0, Seff * Seff - P * P));
            Q = max(-Q_max, min(Q_max, Q_desired));

            commandOut(r,1) = P;
            commandOut(r,2) = Q;
            commandOut(r,4) = modeAuto;
        end
    end
    return;
end

% =========================================================================
% Power Balance & Deficit Formulation
% =========================================================================
% In droop-governed GFM microgrid, power deficit manifests as BESS power
% exceeding its scheduled baseline target.
P_deficit_island = Pbess_act - Pbess_base;

% =========================================================================
% STRATEGY 2: GROUP B (Fixed-Ratio 50/50 Allocation Benchmark)
% =========================================================================
if coordinatorEnable >= 1.5 && coordinatorEnable < 2.5
    % Blindly splits deficit 50/50 between PV and Wind without checking Pavail
    alphaOut   = [0.0; 0.5; 0.5];
    HOut       = [0.0; 0.5; 0.5];
    deltaP     = max(0.0, P_deficit_island);
    P_cmd_pv   = Ppv_base + 0.5 * deltaP;
    P_cmd_wind = Pwind_base + 0.5 * deltaP;
    P_cmd_bess = Pbess_base;

% =========================================================================
% STRATEGY 3: GROUP C1 (Capability-Weighted Adaptive Coordination)
% =========================================================================
elseif coordinatorEnable >= 2.5
    % 1. Detect renewable deficit if available power dropped below baseline
    pv_deficit   = max(0.0, Ppv_base - Ppv_avail);
    wind_deficit = max(0.0, Pwind_base - Pwind_avail);
    net_deficit  = max(0.0, P_deficit_island) + pv_deficit + wind_deficit;

    % 2. Upward active power headroom for each resource [BESS; PV; Wind]
    bess_dis_allowed = (soc_bess > (socMin + 0.02)) && (activeMask(1) > 0.5);
    bess_Pmax_eff    = min(pRating(1), sRating(1) * kI_bess);
    if bess_dis_allowed
        bess_headroom = max(0.0, bess_Pmax_eff - max(0.0, Pbess_base));
    else
        bess_headroom = 0.0;
    end
    pv_headroom   = max(0.0, min(Ppv_avail, pRating(2) * kI_pv) - Ppv_base) * activeMask(2);
    wind_headroom = max(0.0, min(Pwind_avail, pRating(3) * kI_wind) - Pwind_base) * activeMask(3);

    headrooms = [bess_headroom; pv_headroom; wind_headroom];

    % 3. Normalized capability components H_i^P, H_i^I, H_i^E in [0, 1]
    HP = zeros(3, 1);
    for r = 1:3
        HP(r) = min(1.0, max(0.0, headrooms(r) / max(1.0, pRating(r))));
    end

    S_acts = [sqrt(Pbess_act*Pbess_act + Qbess_act*Qbess_act); ...
              sqrt(Ppv_act*Ppv_act     + Qpv_act*Qpv_act);     ...
              sqrt(Pwind_act*Pwind_act + Qwind_act*Qwind_act)];
    HI = zeros(3, 1);
    for r = 1:3
        HI(r) = min(1.0, max(0.0, kIs(r) - S_acts(r) / max(1.0, sRating(r))));
    end

    soc_span = max(0.05, socMax - socMin);
    HE = [min(1.0, max(0.0, (soc_bess - socMin) / soc_span)); ...
          min(1.0, max(0.0, Ppv_avail / max(1.0, pRating(2)))); ...
          min(1.0, max(0.0, Pwind_avail / max(1.0, pRating(3))))];

    % 4. Composite capability score H_i = w_P*H_i^P + w_I*H_i^I + w_E*H_i^E
    % gated by upward power capability (headrooms(r) > 1.0 W) and clean preference rho_r
    wP  = 0.50;
    wI  = 0.30;
    wE  = 0.20;
    rho = [0.25; 1.00; 1.00]; % Prefer renewable headroom while allowing continuous BESS sharing

    for r = 1:3
        if headrooms(r) > 1.0 && activeMask(r) > 0.5
            HOut(r) = rho(r) * (wP * HP(r) + wI * HI(r) + wE * HE(r));
        else
            HOut(r) = 0.0;
        end
    end

    H_sum = HOut(1) + HOut(2) + HOut(3);
    if H_sum > 1e-9
        alphaOut = HOut / H_sum;
    else
        alphaOut = [bess_dis_allowed * 1.0; 0.0; 0.0];
    end

    % 5. Proportional allocation with iterative water-filling projection onto headrooms
    alloc = zeros(3, 1);
    rem_d = net_deficit;
    sat   = false(3, 1);
    for r = 1:3
        if headrooms(r) <= 1.0 || HOut(r) <= 1e-9
            sat(r) = true;
        end
    end

    for iter = 1:3
        if rem_d <= 1e-3
            break;
        end
        H_unsat = 0.0;
        for r = 1:3
            if ~sat(r)
                H_unsat = H_unsat + HOut(r);
            end
        end
        if H_unsat <= 1e-9
            break;
        end
        any_new_sat = false;
        for r = 1:3
            if ~sat(r)
                share = (HOut(r) / H_unsat) * rem_d;
                if alloc(r) + share >= headrooms(r)
                    rem_d = rem_d - (headrooms(r) - alloc(r));
                    alloc(r) = headrooms(r);
                    sat(r) = true;
                    any_new_sat = true;
                end
            end
        end
        if ~any_new_sat
            for r = 1:3
                if ~sat(r)
                    alloc(r) = alloc(r) + (HOut(r) / H_unsat) * rem_d;
                end
            end
            rem_d = 0.0;
            break;
        end
    end

    % If residual remains and BESS discharge is allowed, project onto BESS
    if rem_d > 0.0 && bess_dis_allowed
        alloc(1) = min(bess_headroom, alloc(1) + rem_d);
    end

    P_cmd_pv   = min(Ppv_avail, Ppv_base + alloc(2));
    P_cmd_wind = min(Pwind_avail, Pwind_base + alloc(3));

    if (Pbess_act > 0.0 || Ppv_act > 0.0 || Pwind_act > 0.0)
        P_cmd_bess = Pbess_base + alloc(1);
    else
        P_cmd_bess = Pbess_base;
    end

    if soc_bess <= socMin
        P_cmd_bess = min(0.0, P_cmd_bess);
    elseif soc_bess >= socMax
        P_cmd_bess = max(0.0, P_cmd_bess);
    end

% =========================================================================
% STRATEGY 1: GROUP C0 (Capability-Constrained Priority Dispatch - Baseline C0)
% =========================================================================
else
    % 1. Detect renewable deficit if available power dropped below baseline
    pv_deficit   = max(0.0, Ppv_base - Ppv_avail);
    wind_deficit = max(0.0, Pwind_base - Pwind_avail);

    % Total net adjustment required
    net_deficit = max(0.0, P_deficit_island) + pv_deficit + wind_deficit;

    % 2. Calculate true operational headroom considering current limits
    pv_headroom   = max(0.0, min(Ppv_avail, pRating(2) * kI_pv) - Ppv_base) * activeMask(2);
    wind_headroom = max(0.0, min(Pwind_avail, pRating(3) * kI_wind) - Pwind_base) * activeMask(3);

    % 3. Prioritize clean renewable headroom (Wind -> PV)
    alloc_wind = min(wind_headroom, net_deficit);
    rem_deficit = net_deficit - alloc_wind;

    alloc_pv = min(pv_headroom, rem_deficit);
    rem_deficit = rem_deficit - alloc_pv;

    % 4. Residual deficit allocated to BESS within SOC bounds
    bess_dis_allowed = (soc_bess > (socMin + 0.02)) && (activeMask(1) > 0.5);
    alloc_bess = rem_deficit;
    if ~bess_dis_allowed
        alloc_bess = 0.0;
    end

    HOut = [bess_dis_allowed * 1.0; (pv_headroom > 1.0) * 1.0; (wind_headroom > 1.0) * 1.0];
    if net_deficit > 1.0
        alphaOut = [alloc_bess; alloc_pv; alloc_wind] / net_deficit;
    else
        alphaOut = [0.0; 0.0; 1.0];
    end

    % Clamped to actual real-time availability
    P_cmd_pv   = min(Ppv_avail, Ppv_base + alloc_pv);
    P_cmd_wind = min(Pwind_avail, Pwind_base + alloc_wind);
    
    % Dynamic reallocation to BESS if system is running online, else preserve base
    if (Pbess_act > 0.0 || Ppv_act > 0.0 || Pwind_act > 0.0)
        P_cmd_bess = Pbess_base + alloc_bess;
    else
        P_cmd_bess = Pbess_base;
    end

    % Absolute SOC protection clamp on BESS
    if soc_bess <= socMin
        P_cmd_bess = min(0.0, P_cmd_bess);
    elseif soc_bess >= socMax
        P_cmd_bess = max(0.0, P_cmd_bess);
    end
end

% =========================================================================
% STAGE 2: Reactive Power Capability & Network-Aware Coordination
% =========================================================================
P_cmds = [P_cmd_bess; P_cmd_pv; P_cmd_wind];
Q_cmds = [commandIn(1,2); commandIn(2,2); commandIn(3,2)];

persistent q_cmd_state p_lvrt_state fault_latch
if isempty(q_cmd_state)
    q_cmd_state  = zeros(3, 1);
    p_lvrt_state = [5.0e6; 5.0e6; 5.0e6];
    fault_latch  = false;
end

if coordinatorEnable >= 3.5
    V_star   = 10000.0;
    V_pcc    = [statClean(1,3); statClean(2,3); statClean(3,3)];
    is_sim   = (statClean(1, 10) > 500.0);

    % Gate reactive dispatch until after the 0-0.20 s island soft-start completes
    P_tot_act    = Pbess_act + Ppv_act + Pwind_act;
    is_energized = (statClean(2,3) > 2000.0 && statClean(3,3) > 2000.0) && ...
                   ((P_tot_act > 4.7e6) || (min(statClean(2,3), statClean(3,3)) < 8500.0 && P_tot_act > 2.0e6));

    for r = 1:3
        if V_pcc(r) < 1000.0
            V_pcc(r) = V_star;
        end
    end

    if is_energized
        % Local PCC voltage deficit demand phi(e_V,i) = max(0, (V* - V_PCC,i)/V* - db_V)
        % Pure negative-feedback voltage droop
        db_V  = 0.002;
        phi_V = zeros(3, 1);
        for r = 2:3
            eV_r     = max(0.0, min(0.25, (V_star - V_pcc(r)) / V_star));
            phi_V(r) = max(0.0, eV_r - db_V) * activeMask(r);
        end

        % Hysteresis-latched fault sag detection in EMT (prevents chattering when
        % fault Q-support + P de-loading lifts local PCC voltage near 8.5 kV)
        if is_sim
            is_fault_sag = (min(V_pcc(2), V_pcc(3)) < 8450.0) || ...
                           (fault_latch && min(V_pcc(2), V_pcc(3)) < 9150.0);
            fault_latch  = is_fault_sag;
            if is_fault_sag
                if coordinatorEnable < 4.5
                    Q_stab_max = 0.42e6;
                else
                    Q_stab_max = 0.52e6;
                end
            else
                Q_stab_max = 1.45e6;
            end
        else
            is_fault_sag = (min(V_pcc(2), V_pcc(3)) < 8500.0);
            Q_stab_max   = max(sRating(2), sRating(3));
        end

        S_gfl_tot  = sRating(2) + sRating(3);
        Q_target   = [commandIn(1,2); commandIn(2,2); commandIn(3,2)];
        Q_headroom = [sRating(1); Q_stab_max; Q_stab_max];

        if coordinatorEnable < 4.5
            % -------------------------------------------------------------
            % STRATEGY 4: GROUP C1-PQ LOCAL (Uncoupled Local-V Q Allocation)
            % -------------------------------------------------------------
            % Allocates Q strictly by local voltage error phi(e_V,i) without
            % P-coupled MVA headroom projection or network sensitivity beta_i.
            HQOut(1) = 0.0;
            HQOut(2) = phi_V(2);
            HQOut(3) = phi_V(3);
            HQ_sum   = HQOut(2) + HQOut(3);
            if HQ_sum > 1e-9
                alphaQOut(2) = HQOut(2) / HQ_sum;
                alphaQOut(3) = HQOut(3) / HQ_sum;
            end

            % Uncoupled local Q_i^cmd proportional to local voltage deficit (V* - V_i)
            K_QV_local  = 8.2;
            Q_req_local = K_QV_local * (0.5 * (phi_V(2) + phi_V(3))) * S_gfl_tot;
            Q_target(2) = min(Q_stab_max, max(0.0, commandIn(2,2) + alphaQOut(2) * Q_req_local));
            Q_target(3) = min(Q_stab_max, max(0.0, commandIn(3,2) + alphaQOut(3) * Q_req_local));

        elseif coordinatorEnable >= 5.5 && is_fault_sag
            % -------------------------------------------------------------
            % STRATEGY 6 (FAULT BRANCH): GROUP C1-LVRT (Q-Priority + Orthogonal P De-Loading)
            % -------------------------------------------------------------
            % 1. Grid-code dynamic reactive support prioritized during deep voltage sag (V_PCC < 0.84 pu).
            %    When BESS-GFM possesses short-term 3 pu overload capability (bess_overload_budget > 0),
            %    BESS carries primary formation current, allowing GFL K_LVRT to moderate from 1.45 to 0.80.
            %    As the 10 s overload budget depletes (1.0 -> 0.0), K_LVRT smoothly ramps up to 1.45.
            beta_bar = [0.0; 0.836; 1.000];
            K_LVRT   = 1.45 - 0.65 * bess_overload_budget;
            for r = 2:3
                sag_r       = max(0.0, 0.90 - V_pcc(r) / V_star);
                Q_target(r) = min(Q_stab_max, K_LVRT * beta_bar(r) * sag_r * sRating(r)) * activeMask(r);
                HQOut(r)    = (Q_target(r) / max(1.0, sRating(r))) * beta_bar(r);
            end
            HQ_sum = HQOut(2) + HQOut(3);
            if HQ_sum > 1e-9
                alphaQOut(2) = HQOut(2) / HQ_sum;
                alphaQOut(3) = HQOut(3) / HQ_sum;
            end

        else
            % -------------------------------------------------------------
            % STRATEGY 5 (AND STRATEGY 6 NORMAL/RECOVERY): GROUP C1-PQ NETWORK-AWARE
            % -------------------------------------------------------------
            % 1. Voltage-derated, P-coupled MVA circle reactive headroom:
            %    Q_i,headroom = sqrt(max(0, (gamma_S * S_i * kI_i * (V_i/V*))^2 - (P_i^cmd)^2))
            if is_sim
                gamma_S = 0.95; % Accounts for 0.69/10 kV transformer reactive voltage drop
            else
                gamma_S = 0.96;
            end
            Q_headroom = zeros(3, 1);
            for r = 2:3
                v_pu_r   = min(1.0, max(0.5, V_pcc(r) / V_star));
                S_eff_r  = gamma_S * sRating(r) * kIs(r) * v_pu_r;
                P_eff_r  = max(0.0, min(pRating(r), P_cmds(r)));
                q_mva_r  = sqrt(max(0.0, S_eff_r * S_eff_r - P_eff_r * P_eff_r));
                Q_headroom(r) = min(Q_stab_max, q_mva_r) * activeMask(r);
            end

            % 2. Small-signal network V/Q sensitivity weights beta_bar_i
            %    Derived from empirical dV_j / dQ_i on the asymmetric 10 kV network:
            %    S_VQ = [+341.9, +259.9; +260.0, +460.3] V/Mvar -> beta_bar = [0.836, 1.000]
            beta_bar = [0.0; 0.836; 1.000];

            % 3. Composite capability x demand x network effectiveness score H_i^Q
            for r = 2:3
                if Q_headroom(r) > 1.0 && activeMask(r) > 0.5
                    HQOut(r) = (Q_headroom(r) / max(1.0, sRating(r))) * phi_V(r) * beta_bar(r);
                else
                    HQOut(r) = 0.0;
                end
            end

            HQ_sum = HQOut(2) + HQOut(3);
            if HQ_sum > 1e-9
                alphaQOut(2) = HQOut(2) / HQ_sum;
                alphaQOut(3) = HQOut(3) / HQ_sum;
            end

            % 4. Coordinated reactive target & 2-pass water-filling onto Q_headroom
            K_QV_net  = 6.8;
            Q_req_net = K_QV_net * (0.5 * (beta_bar(2)*phi_V(2) + beta_bar(3)*phi_V(3))) * S_gfl_tot;
            q_alloc   = zeros(3, 1);
            rem_q     = max(0.0, Q_req_net);
            q_sat     = [true; (Q_headroom(2) <= 1.0 || alphaQOut(2) <= 1e-9); ...
                               (Q_headroom(3) <= 1.0 || alphaQOut(3) <= 1e-9)];

            for iter = 1:2
                if rem_q <= 1e-3
                    break;
                end
                a_unsat = 0.0;
                for r = 2:3
                    if ~q_sat(r)
                        a_unsat = a_unsat + alphaQOut(r);
                    end
                end
                if a_unsat <= 1e-9
                    break;
                end
                new_sat = false;
                for r = 2:3
                    if ~q_sat(r)
                        q_share = (alphaQOut(r) / a_unsat) * rem_q;
                        if q_alloc(r) + q_share >= Q_headroom(r)
                            rem_q = rem_q - (Q_headroom(r) - q_alloc(r));
                            q_alloc(r) = Q_headroom(r);
                            q_sat(r) = true;
                            new_sat = true;
                        end
                    end
                end
                if ~new_sat
                    for r = 2:3
                        if ~q_sat(r)
                            q_alloc(r) = q_alloc(r) + (alphaQOut(r) / a_unsat) * rem_q;
                        end
                    end
                    rem_q = 0.0;
                    break;
                end
            end

            Q_target(2) = min(Q_headroom(2), max(0.0, commandIn(2,2) + q_alloc(2)));
            Q_target(3) = min(Q_headroom(3), max(0.0, commandIn(3,2) + q_alloc(3)));
        end

        % Discrete-time command state filter with mode-dependent attack / retraction rates:
        % - Mode 4 (Uncoupled Local): fault boost (0.10) with lagging post-fault release (0.005) -> recovery overshoot
        % - Mode 5 (Network-Aware): uniform first-order smoothing (lambda_Q = 0.08)
        % - Mode 6 (C1-LVRT): fast fault attack (0.14) AND fast post-fault retraction (0.35) -> suppresses overshoot
        if is_sim
            for r = 2:3
                if coordinatorEnable >= 5.5
                    if is_fault_sag
                        lam_r = 0.14;
                    elseif q_cmd_state(r) > Q_target(r) + 0.10e6 || V_pcc(r) > 10020.0
                        lam_r = 0.35;
                    else
                        lam_r = 0.08;
                    end
                elseif coordinatorEnable < 4.5 && is_fault_sag
                    lam_r = 0.10;
                elseif coordinatorEnable < 4.5 && q_cmd_state(r) > Q_target(r) + 0.02e6
                    lam_r = 0.005;
                else
                    lam_r = 0.08;
                end
                q_cmd_state(r) = min(Q_headroom(r), (1.0 - lam_r) * q_cmd_state(r) + lam_r * Q_target(r));
                Q_cmds(r)      = q_cmd_state(r);
            end
        else
            Q_cmds(2) = Q_target(2);
            Q_cmds(3) = Q_target(3);
        end

        % In Mode 6 (C1-LVRT) during deep voltage sag, orthogonally de-load active power P_cmds(2:3)
        % onto the remaining voltage-derated MVA circle so sqrt(Id^2 + Iq^2) <= I_limit (k_I = 1.0).
        % With BESS 3 pu overload capability (bess_overload_budget > 0), active power de-loading is
        % relaxed (gamma_LVRT increases), avoiding premature renewable curtailment while BESS maintains bus.
        if coordinatorEnable >= 5.5 && is_fault_sag
            if is_sim
                gamma_LVRT = 0.80 + 0.05 * bess_overload_budget;
                for r = 2:3
                    v_pu_r          = min(0.85, max(0.74, V_pcc(r) / V_star));
                    S_lvrt_r        = gamma_LVRT * sRating(r) * v_pu_r;
                    P_max_lvrt_r    = sqrt(max(0.0, S_lvrt_r * S_lvrt_r - Q_cmds(r) * Q_cmds(r))) * activeMask(r);
                    p_lvrt_state(r) = 0.82 * p_lvrt_state(r) + 0.18 * min(P_cmds(r), P_max_lvrt_r);
                    P_cmds(r)       = min(P_cmds(r), p_lvrt_state(r));
                end
            else
                gamma_LVRT = 0.84 + 0.10 * bess_overload_budget;
                for r = 2:3
                    v_pu_r       = min(1.0, max(0.35, V_pcc(r) / V_star));
                    S_lvrt_r     = gamma_LVRT * sRating(r) * v_pu_r;
                    P_max_lvrt_r = sqrt(max(0.0, S_lvrt_r * S_lvrt_r - Q_cmds(r) * Q_cmds(r))) * activeMask(r);
                    P_cmds(r)    = min(P_cmds(r), P_max_lvrt_r);
                end
            end
            P_cmds(1) = min(P_cmds(1), 0.44 * pRating(1));
        elseif coordinatorEnable >= 5.5 && is_sim
            % Smooth post-fault active power recovery ramp (~30 ms time constant)
            for r = 2:3
                p_lvrt_state(r) = 0.84 * p_lvrt_state(r) + 0.16 * P_cmds(r);
                P_cmds(r)       = min(P_cmds(r), p_lvrt_state(r));
            end
        else
            p_lvrt_state(2) = P_cmds(2);
            p_lvrt_state(3) = P_cmds(3);
        end
    else
        q_cmd_state  = [0.0; 0.0; 0.0];
        p_lvrt_state = [5.0e6; 5.0e6; 5.0e6];
        fault_latch  = false;
    end
else
    q_cmd_state  = [0.0; 0.0; 0.0];
    p_lvrt_state = [5.0e6; 5.0e6; 5.0e6];
    fault_latch  = false;
end

% =========================================================================
% Circular MVA Limiter & Final Command Assembly
% =========================================================================
for r = 1:3
    if commandOut(r,3) < 0.5
        continue; % Disabled or faulted
    end

    kI = kIs(r);
    Seff = sRating(r) * kI;
    Pmax = min(pRating(r), Seff);

    if r == 1
        % BESS bidirectional
        P = max(-Pmax, min(Pmax, P_cmds(1)));
    else
        % PV & Wind unipolar generation
        P = max(0.0, min(Pmax, P_cmds(r)));
    end

    Q_desired = Q_cmds(r);
    if coordinatorEnable >= 3.5 && coordinatorEnable < 4.5 && r >= 2
        % In Mode 4 (Uncoupled Local-V Q Control), Q_desired is only bounded by
        % standalone converter reactive rating; overcurrent is left to the
        % inner hardware current circle limiter (which scales Id and Iq together).
        Q_max = 1.15 * sRating(r);
    else
        % Coupled supervisory MVA circle projection
        Q_max = sqrt(max(0.0, Seff * Seff - P * P));
    end
    Q = max(-Q_max, min(Q_max, Q_desired));

    commandOut(r,1) = P;
    commandOut(r,2) = Q;
    commandOut(r,4) = modeCoord;
end

end
