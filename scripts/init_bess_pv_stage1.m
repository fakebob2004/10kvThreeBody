% Stage 1 parameters: frozen R8 BESS-GFM plus one independent PV-GFL branch.
% No wind source and no upper-level coordinator are enabled in this stage.
scriptDir = fileparts(mfilename('fullpath'));
run(fullfile(scriptDir,'init_bess_gfm_dynamic_r7.m'));

S1 = struct();
S1.revision = 'Stage1-BESS-GFM-plus-PV-GFL-baseline-2026-09-20';
S1.base.S_VA = 10e6;
S1.base.Vpcc_V = 10e3;
S1.base.f_Hz = 50;

% PV branch rating and independent DC/AC voltage levels.
S1.pv.P_rated_W = 5e6;
S1.pv.S_pcs_VA = 6.25e6;
S1.pv.Vll_low_V = 690;
S1.pv.Vll_high_V = 10e3;
S1.pv.Vdc_ref_V = S1.pv.Vll_low_V*sqrt(2)*2/sqrt(3)*1.15;
S1.pv.Vdc_ceiling_V = 1500;
S1.pv.Cdc_F = 3.09e-3;
S1.pv.dc_source_R_ohm = 0.01;
S1.pv.modulation_max = 0.98;
S1.pv.P_initial_W = 2e6;
S1.pv.P_final_W = 3e6;
S1.pv.P_step_time_s = 0.30;
S1.pv.Q_ref_var = 0;
S1.pv.Q_pf09_var = S1.pv.P_rated_W*tan(acos(0.90));
S1.pv.P_ramp_W_per_s = 20e6;

% Converter-side LCL and the dedicated 0.69/10 kV unit transformer.
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
S1.line.length_km = 1.0;
S1.line.R_ohm = 0.125*S1.line.length_km;
S1.line.L_H = 0.30e-3*S1.line.length_km;

% Local GFL controls.  These are deliberately independent of the BESS
% angle/frequency signal: the only functional coupling is the AC network.
% Use the same tested Simscape three-phase PLL wrapper and gains as the
% Renewable Energy Integration Design reference project, retuned only for
% this project's 50 Hz base frequency.
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

% Stage 1 experiment: fixed 5 MW island load and PV 2 -> 3 MW.  R8's load
% step branch is disabled only in the derived Stage 1 model, never in R8.
S1.load.P_W = 5e6;
S1.load.Q_var = 1.5e6;
S1.load.step_P_W = 0;
S1.expected.BESS_P_initial_W = S1.load.P_W-S1.pv.P_initial_W;
S1.expected.BESS_P_final_W = S1.load.P_W-S1.pv.P_final_W;

assert(S1.pv.Vdc_ref_V < S1.pv.Vdc_ceiling_V, ...
    'PV operating DC voltage exceeds the 1500 V equipment ceiling.');
assert(hypot(S1.pv.P_rated_W,S1.pv.Q_pf09_var) < S1.pv.S_pcs_VA, ...
    'PV PCS cannot support 5 MW at 0.9 power factor.');
assert(S1.filter.fres_Hz > 10*S1.base.f_Hz, ...
    'PV LCL resonance is too close to the fundamental.');

fprintf(['STAGE1: PV %.1f MW, %.2f MVA PCS, %.1f Vdc; ' ...
    'P step %.1f -> %.1f MW; expected BESS %.1f -> %.1f MW\n'], ...
    S1.pv.P_rated_W/1e6,S1.pv.S_pcs_VA/1e6,S1.pv.Vdc_ref_V, ...
    S1.pv.P_initial_W/1e6,S1.pv.P_final_W/1e6, ...
    S1.expected.BESS_P_initial_W/1e6,S1.expected.BESS_P_final_W/1e6);
assignin('base','G',G);
assignin('base','S1',S1);
