% Parameters for the standalone PV-GFL / strong-machine commissioning model.
% The electrical ratings are the project ratings.  The controller topology
% follows the teammate 864 model (PLL -> dq -> P/Q -> current PI), while all
% gains are recalculated for the 690 V / 6.25 MVA branch.
scriptDir = fileparts(mfilename('fullpath'));
run(fullfile(scriptDir,'init_pv_gfl_sm_commissioning.m'));

S1 = struct();
S1.revision = 'PV-GFL-864-logic-average-VSC-strong-SM-R1';
S1.base.S_VA = 10e6;
S1.base.Vpcc_V = 10e3;
S1.base.f_Hz = 50;

S1.pv.P_rated_W = 5e6;
S1.pv.S_pcs_VA = 6.25e6;
S1.pv.Vll_low_V = 690;
S1.pv.Vll_high_V = 10e3;
S1.pv.Vdc_ref_V = S1.pv.Vll_low_V*sqrt(2)*2/sqrt(3)*1.15;
S1.pv.Vdc_ceiling_V = 1500;
S1.pv.Cdc_F = 3.09e-3;
S1.pv.dc_source_R_ohm = 0.01;
S1.pv.modulation_max = 0.98;

% Commissioning starts at zero current.  The validation script changes
% these workspace fields for the 0->2 MW, 2->3 MW and Q-step cases.
S1.pv.P_initial_W = 0;
S1.pv.P_final_W = 0;
S1.pv.P_step_time_s = 0.30;
S1.pv.Q_ref_var = 0;
S1.pv.Q_step_var = 0;
S1.pv.Q_step_time_s = 0.30;
S1.pv.Q_pf09_var = S1.pv.P_rated_W*tan(acos(0.90));
S1.pv.P_ramp_W_per_s = 20e6;

w0 = 2*pi*S1.base.f_Hz;
Zpcs = S1.pv.Vll_low_V^2/S1.pv.S_pcs_VA;
S1.filter.L1_H = 0.08*Zpcs/w0;
S1.filter.L2_H = 0.03*Zpcs/w0;
S1.filter.R1_ohm = 0.005*Zpcs;
S1.filter.R2_ohm = 0.005*Zpcs;
S1.filter.C_F = 0.05*S1.pv.S_pcs_VA/(w0*S1.pv.Vll_low_V^2);
S1.filter.fres_Hz = (1/(2*pi))*sqrt((S1.filter.L1_H+S1.filter.L2_H)/ ...
    (S1.filter.L1_H*S1.filter.L2_H*S1.filter.C_F));
S1.filter.Rd_ohm = 1/(3*2*pi*S1.filter.fres_Hz*S1.filter.C_F);
S1.transformer.S_VA = 6.3e6;
S1.transformer.R_pu = 0.01;
S1.transformer.X_pu = 0.06;

% 864 used a 3 mH low-power filter.  It is not numerically scaled.  Gains
% below use the actual per-unit-sized project filter and a 150 Hz bandwidth.
S1.control.pll_Kp = 100;
S1.control.pll_Ki = 1000;
S1.control.pll_sample_s = 1e-5;
S1.control.pll_initial_phase_rad = pi/6;
S1.control.current_bandwidth_Hz = 150;
wi = 2*pi*S1.control.current_bandwidth_Hz;
S1.control.current_Kp = S1.filter.L1_H*wi;
S1.control.current_Ki = S1.filter.R1_ohm*wi;
S1.control.Ibase_A = S1.pv.S_pcs_VA/(sqrt(3)*S1.pv.Vll_low_V);
S1.control.Ilimit_A = 1.10*S1.control.Ibase_A;
S1.control.power_filter_s = 1/(2*pi*20);
S1.control.sensor_filter_s = 20e-6;

% The copied strong-grid PLL originally measured the 10 kV PCC.  In this
% self-contained branch it measures the transformer low-voltage side, so
% its normalization base and initial local phase must be changed together.
Control.PLL.Vbase = S1.pv.Vll_low_V;
Control.PLL.Theta0 = S1.control.pll_initial_phase_rad;
Control.PLL.Kp = 200;
Control.PLL.Ki = 5000;
% Commissioning source is intentionally strong on the sub-second GFL test
% horizon; these values are not the later islanded-machine study settings.
SM.governor_time_constant = 0.02;
SM.time_constsnt_steamchest = 0.03;
SM.droop_p = 1;

assert(S1.pv.Vdc_ref_V < S1.pv.Vdc_ceiling_V);
assert(hypot(S1.pv.P_rated_W,S1.pv.Q_pf09_var) < S1.pv.S_pcs_VA);
assert(S1.filter.fres_Hz > 10*S1.base.f_Hz);
assignin('base','S1',S1);
assignin('base','Control',Control);
assignin('base','SM',SM);
fprintf('PV-GFL R1: 5 MW / 6.25 MVA, %.1f Vdc, 690 V / 10 kV, current PI %.1f Hz\n', ...
    S1.pv.Vdc_ref_V,S1.control.current_bandwidth_Hz);
