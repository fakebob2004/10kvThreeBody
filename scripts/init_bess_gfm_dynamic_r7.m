% Dynamic-control extension of the final 5 MW / 10 MWh BESS-GFM baseline.
run(fullfile(fileparts(mfilename('fullpath')),'init_bess_gfm_final_r6.m'));
G.revision = 'R7-BESS-GFM-dynamic-controls-2026-09-19';

% Average-value buck-boost plant with explicit LC dynamics.
G.dcdc.L_H = 0.4e-3;
G.dcdc.RL_ohm = 1.0e-3;
G.dcdc.C_F = G.dc.Cdc_F;
G.dcdc.RC_ohm = 2.0e-3;
G.dcdc.duty_ff = G.dc.Vdc_ref_V/(G.dc.Vbattery_V+G.dc.Vdc_ref_V);
G.dcdc.duty_min = 0.05;
G.dcdc.duty_max = 0.95;
G.dcdc.Imax_A = 1.10*G.dc.Irated_A;
G.dcdc.Iref_limit_A = round(1.08*G.dc.Irated_A); % exactly 4500 A
G.dcdc.power_ff_filter_s = 2.0e-3;

% Cascaded controller: 10 Hz voltage loop and 300 Hz current loop.
wv = 2*pi*10;
wi = 2*pi*300;
kpower = G.dc.Vbattery_V/G.dc.Vdc_ref_V;
Ctotal = G.dcdc.C_F;
Vgain = G.dc.Vbattery_V + G.dc.Vdc_ref_V;
G.dcdc.Kpv_A_per_V = 2*0.707*wv*Ctotal/kpower;
G.dcdc.Kiv_A_per_Vs = wv^2*Ctotal/kpower;
G.dcdc.Kpi_duty_per_A = G.dcdc.L_H*wi/Vgain;
G.dcdc.Kii_duty_per_As = G.dcdc.RL_ohm*wi/Vgain;
% Back-calculation tracking gains used by the hardened R8 packaging.
% R7 itself is left numerically unchanged; R8 closes these paths around
% the battery-current-reference and duty-ratio saturations.
G.dcdc.Kaw_v_per_s = wv;
G.dcdc.Kaw_i_per_s = wi;
G.dcdc.Iref_initial_A = 4.0e6/G.dc.Vbattery_V;
G.dcdc.current_sensor_s = 1.0e-4;

% Positive-sequence virtual impedance and current limits.
G.control.Rvirt_ohm = 0.02*G.ac.Vll_low_V^2/G.bess.S_VA;
G.control.Xvirt_ohm = 0.10*G.ac.Vll_low_V^2/G.bess.S_VA;
G.control.Iac_rated_A = G.bess.S_VA/(sqrt(3)*G.ac.Vll_low_V);
G.control.Iac_limit_A = 1.20*G.control.Iac_rated_A;

% 4 MW base load plus a 1 MW step at t=0.30 s.
G.load.base_P_W = 4.0e6;
G.load.base_Q_var = 1.2e6;
G.load.step_P_W = 1.0e6;
G.load.step_Q_var = 0.3e6;
G.load.step_time_s = 0.30;

fprintf(['R7 DCDC: Dff=%.4f, Imax=%.1f A, Kpv=%.3f, Kiv=%.3f, ' ...
    'Kpi=%.7f, Kii=%.7f\n'],G.dcdc.duty_ff,G.dcdc.Imax_A, ...
    G.dcdc.Kpv_A_per_V,G.dcdc.Kiv_A_per_Vs, ...
    G.dcdc.Kpi_duty_per_A,G.dcdc.Kii_duty_per_As);
assignin('base','G',G);
