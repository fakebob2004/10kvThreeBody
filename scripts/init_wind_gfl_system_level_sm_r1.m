% Wind-GFL standalone commissioning parameters (5 MW / 6.25 MVA).
% The accepted PV-GFL R2.1 electrical/controller base is reused because the
% grid-side PCS, LCL filter, 0.69/10 kV transformer and strong-grid harness
% have the same project ratings.  Wind-specific source dynamics are kept in
% W1 so the simplified source can later be replaced without changing ports.
scriptDir=fileparts(mfilename('fullpath'));
run(fullfile(scriptDir,'init_pv_gfl_r2_1.m'));

W1=struct();
W1.revision='Wind-GFL-system-level-average-R1';
W1.base.S_VA=10e6;
W1.base.Vpcc_V=10e3;
W1.base.f_Hz=50;
W1.wind.P_rated_W=5e6;
W1.wind.S_pcs_VA=6.25e6;
W1.wind.Vll_low_V=690;
W1.wind.Vll_high_V=10e3;
W1.wind.nominal_wind_mps=11;
W1.wind.cut_in_mps=4;
W1.wind.cut_out_mps=23;
W1.wind.rotor_radius_m=70;
W1.wind.air_density_kgpm3=1.225;
W1.wind.source_ramp_up_Wps=20e6;
W1.wind.source_ramp_down_Wps=-20e6;
W1.wind.mechanical_tau_s=0.050;

% A short energy-buffer time constant represents the aggregate PMSG/MSC/DC
% path at system level.  The interface is deliberately replacement-ready.
W1.dc.nominal_V=1500;
% 0.20 F stores 225 kJ at 1500 V (45 ms at 5 MW).  This is a system-level
% aggregate for the converter DC bus, not a battery-energy representation.
% It keeps the short MSC/GSC power mismatch inside a realistic DC-voltage
% excursion while preserving a clean future replacement boundary.
W1.dc.C_equiv_F=0.200;
W1.dc.buffer_tau_s=0.002;
W1.dc.energy_buffer_J=0.5*W1.dc.C_equiv_F*W1.dc.nominal_V^2;

W1.control.Ibase_rms_A=W1.wind.S_pcs_VA/(sqrt(3)*W1.wind.Vll_low_V);
W1.control.Ilimit_peak_A=sqrt(2)*1.10*W1.control.Ibase_rms_A;
W1.control.pll_source='local Wind PCC 10 kV voltage';

% Standalone commissioning-grid tuning.  The PV commissioning shell had
% overridden the reference machine with a very fast 1% governor
% (0.02/0.03 s), which hunts against multi-megawatt converter steps.  For
% this wind branch use an explicit strong-source tuning: H=10 s, 1% droop
% and 0.05/0.10 s governor/turbine lags.
% turbine/governor scale.  These are test-grid values only; they are not
% wind-turbine or final islanded BESS-GFM parameters.
SM.inertia=10.0;
SM.damping=0.20;
SM.droop_p=1;
SM.governor_time_constant=0.05;
SM.time_constsnt_steamchest=0.10;

W1.command.P_available_base_W=5e6;
W1.command.P_available_step_W=0;
W1.command.P_available_step_time_s=.30;
W1.command.P_dispatch_base_W=2e6;
W1.command.P_dispatch_step_W=1e6;
W1.command.P_dispatch_step_time_s=.30;
W1.command.Q_base_var=0;
W1.command.Q_step_var=0;
W1.command.Q_step_time_s=.30;
W1.command.enable_off_time_s=10;
W1.command.enable_on_time_s=11;
W1.command.enable_drop=0;

W1.status.channel_map={ ...
    't_s','Ppcc_W','Qpcc_var','Ppcs_cmd_W','Qcmd_var','theta_rad','f_Hz', ...
    'Id_ref_Apk','Iq_ref_Apk','Ilimit_Apk','phase_error_rad', ...
    'Iactual_Apk','limit_factor','limit_active','Vpcc_ll_rms_V', ...
    'converter_enable','P_available_mechanical_W','P_dispatch_limited_W', ...
    'P_msc_dc_to_pcs_W','Vdc_energy_proxy_V','MPPT_capture_pu'};

% The inherited average grid-side model evaluates these accepted names.
S21.control.Ilimit_peak_A=W1.control.Ilimit_peak_A;
S1.pv.P_rated_W=W1.wind.P_rated_W;
S1.pv.S_pcs_VA=W1.wind.S_pcs_VA;
S1.pv.Vll_low_V=W1.wind.Vll_low_V;
S1.pv.Vll_high_V=W1.wind.Vll_high_V;
S1.control.Ilimit_A=W1.control.Ilimit_peak_A;
assignin('base','S1',S1);assignin('base','S21',S21);assignin('base','W1',W1);
assignin('base','SM',SM);
fprintf('Wind-GFL R1: 5 MW / 6.25 MVA, average PCS, 690 V / 10 kV, local PCC PLL\n');
