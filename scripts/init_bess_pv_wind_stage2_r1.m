% Stage 2 R1: frozen BESS-GFM + accepted PV-GFL + accepted Wind-GFL.
% Resource coupling is exclusively through the 10 kV conserving network.
scriptDir=fileparts(mfilename('fullpath'));
run(fullfile(scriptDir,'define_stage2_resource_api.m'));
run(fullfile(scriptDir,'init_wind_gfl_system_level_sm_r1.m'));
run(fullfile(scriptDir,'init_bess_pv_stage1_r1.m'));

S2=struct();
S2.revision='Stage2-R1-three-source-natural-AC-coupling';
S2.load.base_P_W=5e6;
S2.load.base_Q_var=1.5e6;
S2.load.step_P_W=1e6;
S2.load.step_Q_var=.3e6;
S2.load.step_time_s=.30;
S2.pv.P_base_W=2e6;
S2.pv.P_step_W=1e6;
S2.wind.P_available_W=5e6;
S2.wind.P_base_W=2e6;
S2.wind.P_step_W=0;
S2.event_time_s=.30;

G.load.base_P_W=S2.load.base_P_W;
G.load.base_Q_var=S2.load.base_Q_var;
G.load.step_P_W=0;
G.load.step_Q_var=0;
S1.load.P_W=S2.load.base_P_W;
S1.load.Q_var=S2.load.base_Q_var;
S1.pv.P_initial_W=S2.pv.P_base_W;
S1.pv.P_final_W=S2.pv.P_base_W+S2.pv.P_step_W;
S1.pv.P_step_time_s=S2.event_time_s;

S2.status.channel_map={ ...
    'bess_t_s','Pbess_W','Qbess_var','fbess_Hz','Vcmd_low_V','SOC_pu', ...
    'Vdc_bess_V','Ibat_A','modulation','Pbat_W','duty','Idc_limited_A', ...
    'Ibess_ac_rms_A','bess_limit_factor','load_step_command', ...
    'pv_t_s','Ppv_W','Qpv_var','Ppv_cmd_W','Qpv_cmd_var','pv_theta_rad', ...
    'fpv_Hz','Id_pv_Apk','Iq_pv_Apk','Ipv_limit_Apk','pv_phase_error_rad', ...
    'Ipv_actual_Apk','pv_limit_factor','pv_limit_active','Vpcc_pv_V', ...
    'pv_enable', ...
    'wind_t_s','Pwind_W','Qwind_var','Pwind_cmd_W','Qwind_cmd_var', ...
    'wind_theta_rad','fwind_Hz','Id_wind_Apk','Iq_wind_Apk', ...
    'Iwind_limit_Apk','wind_phase_error_rad','Iwind_actual_Apk', ...
    'wind_limit_factor','wind_limit_active','Vpcc_wind_V','wind_enable', ...
    'Pwind_available_W','Pwind_dispatch_W','Pwind_effective_W', ...
    'Vdc_wind_proxy_V','MPPT_capture_pu','Pload_base_W','Qload_base_var'};

assignin('base','G',G);assignin('base','S1',S1);assignin('base','S21',S21);
assignin('base','W1',W1);assignin('base','S2',S2);
fprintf(['STAGE2 R1 init: BESS-GFM + PV-GFL + Wind-GFL, fixed %.1f MW + j%.1f Mvar, ' ...
    '10 kV AC-only coupling.\n'],S2.load.base_P_W/1e6,S2.load.base_Q_var/1e6);
