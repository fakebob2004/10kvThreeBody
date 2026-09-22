% Unified parameter set for the 10 kV PV-wind-BESS architecture.
% All AC RMS voltages are line-to-line. Per-unit impedances use V_LL^2/S_3ph.

P = struct();
P.meta.revision = 'R2-2026-09-18-AC-coupled';
P.meta.frequency_Hz = 50;
P.meta.omega_rad_s = 2*pi*P.meta.frequency_Hz;

%% System bases
P.base.S_VA = 10e6;
P.base.V10_V = 10e3;
P.base.V690_V = 690;
P.base.V400_V = 400;
% The DC-link base follows the inverter modulation requirement. 1500 V is
% retained below as an equipment ceiling, not as an operating reference.
P.base.Vdc_V = P.base.V690_V*sqrt(2)*2/sqrt(3)*1.15;
P.base.Vbattery_V = 1200;
P.base.I10_A = P.base.S_VA/(sqrt(3)*P.base.V10_V);
P.base.I690_A = P.base.S_VA/(sqrt(3)*P.base.V690_V);
P.base.I400_A = P.base.S_VA/(sqrt(3)*P.base.V400_V);
P.base.Idc_A = P.base.S_VA/P.base.Vdc_V;
P.base.Z10_ohm = P.base.V10_V^2/P.base.S_VA;
P.base.Z690_ohm = P.base.V690_V^2/P.base.S_VA;
P.base.Z400_ohm = P.base.V400_V^2/P.base.S_VA;
P.base.L10_H = P.base.Z10_ohm/P.meta.omega_rad_s;
P.base.C10_F = 1/(P.meta.omega_rad_s*P.base.Z10_ohm);

%% Ratings and normal operating points
P.rating.pv_W = 5e6;
P.rating.wind_W = 5e6;
P.rating.bess_W = 5e6;
P.rating.pv_pf = 0.90;
P.rating.pv_Q_var = P.rating.pv_W*tan(acos(P.rating.pv_pf));
P.rating.pv_S_VA = hypot(P.rating.pv_W, P.rating.pv_Q_var);
P.rating.unit_converter_VA = 6.3e6;
P.rating.main_load_W = 5e6;
P.rating.aux_load_W = 50e3;
P.rating.total_generation_W = P.rating.pv_W + P.rating.wind_W;

%% Separate DC architectures (PV and BESS are AC-coupled at the 10 kV bus)
% Match the MathWorks reference architecture: the PV array is designed so
% Vmpp is close to the inverter DC requirement and connects directly to its
% DC link. MPPT supplies Vdc_ref; Vpv is not an independently fixed source.
P.pv.ac_voltage_V = P.base.V690_V;
P.pv.vdc_modulation_margin = 1.15;
P.pv.vdc_ref_V = P.base.Vdc_V;
P.pv.vdc_max_V = 1500;
P.pv.vmpp_design_V = P.pv.vdc_ref_V;
P.pv.impp_design_A = P.rating.pv_W/P.pv.vmpp_design_V;
P.pv.mppt_step_V = 4e-3*P.pv.vdc_ref_V;
P.pv.mppt_sample_s = 0.5e-3;
% Capacitance scales the reference project's stored-energy/MVA ratio
% (0.85 mF, 7.812 kV, 50 MVA) to this 5 MW, 1.295 kV branch.
P.pv.reference_energy_time_s = 0.5*0.85e-3*(7812.239286)^2/50e6;
P.pv.dc_cap_F = 2*P.pv.reference_energy_time_s*P.rating.pv_W/P.pv.vdc_ref_V^2;

P.bess.battery_nominal_V = 1200;
P.bess.dc_link_ref_V = P.pv.vdc_ref_V;
P.bess.battery_energy_Wh = 4e6; % preserves original 400 V x 10,000 Ah energy
P.bess.battery_capacity_Ah = P.bess.battery_energy_Wh/P.bess.battery_nominal_V;
P.bess.battery_rated_A = P.rating.bess_W/P.bess.battery_nominal_V;
P.bess.battery_current_limit_A = 1.10*P.bess.battery_rated_A;
P.bess.dc_cap_F = P.pv.dc_cap_F;
P.bess.dc_dc_required = true;
P.bess.dc_dc_ratio_nominal = P.bess.dc_link_ref_V/P.bess.battery_nominal_V;

% Compatibility aliases for downstream scripts; these no longer describe a
% common PV+BESS DC bus.
P.dc.link_V = P.pv.vdc_ref_V;
P.dc.cap_F = P.pv.dc_cap_F;
P.dc.allowed_delta_pu = 0.05;
P.dc.energy_nominal_J = 0.5*P.dc.cap_F*P.dc.link_V^2;
P.dc.energy_band_J = 0.5*P.dc.cap_F*((1+P.dc.allowed_delta_pu)^2 - ...
    (1-P.dc.allowed_delta_pu)^2)*P.dc.link_V^2;
P.dc.ride_through_5MW_s = P.dc.energy_band_J/P.rating.pv_W;

%% Converter-side 690 V LCL filter, one set per 6.3 MVA converter
P.filter.Sbase_VA = P.rating.unit_converter_VA;
P.filter.Vbase_V = P.base.V690_V;
P.filter.Zbase_ohm = P.filter.Vbase_V^2/P.filter.Sbase_VA;
P.filter.Ibase_A = P.filter.Sbase_VA/(sqrt(3)*P.filter.Vbase_V);
P.filter.x1_pu = 0.08;
P.filter.x2_pu = 0.03;
P.filter.r1_pu = 0.005;
P.filter.r2_pu = 0.005;
P.filter.capacitive_var_pu = 0.05;
P.filter.L1_H = P.filter.x1_pu*P.filter.Zbase_ohm/P.meta.omega_rad_s;
P.filter.L2_H = P.filter.x2_pu*P.filter.Zbase_ohm/P.meta.omega_rad_s;
P.filter.R1_ohm = P.filter.r1_pu*P.filter.Zbase_ohm;
P.filter.R2_ohm = P.filter.r2_pu*P.filter.Zbase_ohm;
P.filter.C_F = P.filter.capacitive_var_pu*P.filter.Sbase_VA / ...
    (P.meta.omega_rad_s*P.filter.Vbase_V^2);
P.filter.f_res_Hz = (1/(2*pi))*sqrt((P.filter.L1_H+P.filter.L2_H) / ...
    (P.filter.L1_H*P.filter.L2_H*P.filter.C_F));
P.filter.Rd_ohm = 1/(3*2*pi*P.filter.f_res_Hz*P.filter.C_F);

%% Transformers: total R=0.01 pu and X=0.06 pu, split equally by winding
P.transformer.unit.S_VA = 6.3e6;
P.transformer.unit.Vlow_V = 690;
P.transformer.unit.Vhigh_V = 10e3;
P.transformer.unit.ratio = P.transformer.unit.Vhigh_V/P.transformer.unit.Vlow_V;
P.transformer.unit.pu_Rw1 = 0.005;
P.transformer.unit.pu_Rw2 = 0.005;
P.transformer.unit.pu_Xl1 = 0.03;
P.transformer.unit.pu_Xl2 = 0.03;
P.transformer.load.S_VA = 6.3e6;
P.transformer.load.Vhigh_V = 10e3;
P.transformer.load.Vlow_V = 400;
P.transformer.load.ratio = P.transformer.load.Vhigh_V/P.transformer.load.Vlow_V;
P.transformer.load.pu_Rw1 = 0.005;
P.transformer.load.pu_Rw2 = 0.005;
P.transformer.load.pu_Xl1 = 0.03;
P.transformer.load.pu_Xl2 = 0.03;

%% 10 kV feeders (engineering starting values; replace with selected cable data)
P.line.pv.length_km = 1.0;
P.line.bess.length_km = 0.2;
P.line.wind.length_km = 1.0;
P.line.grid.length_km = 2.0;
P.line.R_ohm_per_km = 0.125;
P.line.L_H_per_km = 0.30e-3;
P.line.pv.R_ohm = P.line.R_ohm_per_km*P.line.pv.length_km;
P.line.pv.L_H = P.line.L_H_per_km*P.line.pv.length_km;
P.line.bess.R_ohm = P.line.R_ohm_per_km*P.line.bess.length_km;
P.line.bess.L_H = P.line.L_H_per_km*P.line.bess.length_km;
P.line.wind.R_ohm = P.line.R_ohm_per_km*P.line.wind.length_km;
P.line.wind.L_H = P.line.L_H_per_km*P.line.wind.length_km;
P.line.grid.R_ohm = P.line.R_ohm_per_km*P.line.grid.length_km;
P.line.grid.L_H = P.line.L_H_per_km*P.line.grid.length_km;

%% Utility equivalent at the 10 kV PCC
P.grid.Vll_V = 10e3;
P.grid.short_circuit_VA = 250e6;
P.grid.XR = 10;
P.grid.Z_ohm = P.grid.Vll_V^2/P.grid.short_circuit_VA;
P.grid.R_ohm = P.grid.Z_ohm/sqrt(1+P.grid.XR^2);
P.grid.X_ohm = P.grid.XR*P.grid.R_ohm;
P.grid.L_H = P.grid.X_ohm/P.meta.omega_rad_s;

%% Controller starting values (continuous-time, normalized dq/pu conventions)
P.control.f_switch_Hz = 5e3;
P.control.f_current_Hz = 500;
P.control.f_outer_Hz = 20;
P.control.f_pll_Hz = 20;
P.control.damping = 0.707;
P.control.current_limit_pu = 1.20;
P.control.effective_R_pu = 0.02;
P.control.effective_X_pu = 0.17;
P.control.effective_R_ohm = P.control.effective_R_pu*P.filter.Zbase_ohm;
P.control.effective_L_H = P.control.effective_X_pu*P.filter.Zbase_ohm/P.meta.omega_rad_s;
wi = 2*pi*P.control.f_current_Hz;
wo = 2*pi*P.control.f_outer_Hz;
wpll = 2*pi*P.control.f_pll_Hz;
P.control.current_Kp = P.control.effective_L_H*wi;
P.control.current_Ki = P.control.effective_R_ohm*wi;
P.control.dc_energy_time_s = 0.5*P.pv.dc_cap_F*P.pv.vdc_ref_V^2/P.rating.unit_converter_VA;
P.control.vdc_Kp_pu = 2*P.control.damping*wo*(2*P.control.dc_energy_time_s);
P.control.vdc_Ki_pu = wo^2*(2*P.control.dc_energy_time_s);
P.control.pll_Kp_pu = 2*P.control.damping*wpll;
P.control.pll_Ki_pu = wpll^2;
P.control.gfm_P_f_droop_pu = 0.01; % 0.5 Hz at 1 pu active-power change
P.control.gfm_Q_V_droop_pu = 0.10; % 5% voltage at 0.5 pu reactive-power change
P.control.virtual_R_pu = 0.02;
P.control.virtual_X_pu = 0.10;
P.control.power_filter_Hz = 10;

%% Useful currents
P.current.pv_690_A = P.rating.pv_S_VA/(sqrt(3)*P.base.V690_V);
P.current.wind_690_A = P.rating.wind_W/(sqrt(3)*P.base.V690_V);
P.current.bess_690_A = P.rating.bess_W/(sqrt(3)*P.base.V690_V);
P.current.pv_10kV_A = P.rating.pv_S_VA/(sqrt(3)*P.base.V10_V);
P.current.wind_10kV_A = P.rating.wind_W/(sqrt(3)*P.base.V10_V);
P.current.bess_10kV_A = P.rating.bess_W/(sqrt(3)*P.base.V10_V);
P.current.combined_10kV_A = hypot(P.rating.total_generation_W, ...
    P.rating.pv_Q_var)/(sqrt(3)*P.base.V10_V);
P.current.load_400V_A = P.rating.main_load_W/(sqrt(3)*P.base.V400_V);

%% Design checks
assert(P.rating.pv_S_VA < P.rating.unit_converter_VA, 'PV converter is undersized.');
assert(P.pv.vdc_ref_V < P.pv.vdc_max_V, 'PV DC reference exceeds the 1500 V ceiling.');
assert(P.filter.f_res_Hz > 10*P.meta.frequency_Hz, 'LCL resonance is too low.');
assert(P.filter.f_res_Hz < 0.5*P.control.f_switch_Hz, 'LCL resonance is too high.');
assert(P.control.f_outer_Hz < 0.15*P.control.f_current_Hz, ...
    'Outer-loop bandwidth should remain below 15%% of current-loop bandwidth.');

fprintf('10 kV base: I=%.2f A, Z=%.4f ohm\n', P.base.I10_A, P.base.Z10_ohm);
fprintf('Unit transformer ratios: 10k/690=%.4f, 10k/400=%.1f\n', ...
    P.transformer.unit.ratio, P.transformer.load.ratio);
fprintf('LCL: L1=%.3f uH, L2=%.3f uH, C=%.3f mF, Rd=%.4f ohm, fres=%.1f Hz\n', ...
    1e6*P.filter.L1_H, 1e6*P.filter.L2_H, 1e3*P.filter.C_F, ...
    P.filter.Rd_ohm, P.filter.f_res_Hz);
fprintf('PV direct DC: Vmpp_ref=%.1f V, C=%.3f mF, MPPT step=%.2f V\n', ...
    P.pv.vdc_ref_V, 1e3*P.pv.dc_cap_F, P.pv.mppt_step_V);
fprintf('BESS separate DC: Vbat=%.1f V, Vdc_ref=%.1f V, DC/DC ratio=%.4f\n', ...
    P.bess.battery_nominal_V, P.bess.dc_link_ref_V, P.bess.dc_dc_ratio_nominal);
fprintf('PI starts: current Kp=%.6g, Ki=%.6g; Vdc pu Kp=%.6g, Ki=%.6g\n', ...
    P.control.current_Kp, P.control.current_Ki, ...
    P.control.vdc_Kp_pu, P.control.vdc_Ki_pu);

assignin('base', 'P', P);
