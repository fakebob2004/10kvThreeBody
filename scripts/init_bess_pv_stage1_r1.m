% Stage 1: frozen R8 BESS-GFM plus the accepted PV-GFL R2.1 branch.
% The two sources share only the 10 kV conserving electrical network.
scriptDir=fileparts(mfilename('fullpath'));
run(fullfile(scriptDir,'init_bess_gfm_dynamic_r7.m'));
run(fullfile(scriptDir,'init_pv_gfl_r2_1.m'));

S1.revision='Stage1-R1-R8-plus-accepted-PV-R2.1';
S1.pv.P_initial_W=2e6;
S1.pv.P_final_W=3e6;
S1.pv.P_step_time_s=.30;
S1.pv.Q_ref_var=0;
S1.load.P_W=5e6;
S1.load.Q_var=1.5e6;

% Disable only the load-step scenario in the derived copy.
G.load.base_P_W=S1.load.P_W;
G.load.base_Q_var=S1.load.Q_var;
G.load.step_P_W=0;
G.load.step_Q_var=0;

S1.stage1.channel_map={ ...
    'bess_t_s','Pbess_W','Qbess_var','fbess_Hz','Vcmd_low_V','SOC_pu', ...
    'Vdc_V','Ibat_A','modulation','Pbat_W','duty','Idc_limited_A', ...
    'Ibess_ac_rms_A','bess_ac_limit_factor','load_step_command', ...
    'pv_t_s','Ppv_W','Qpv_var','Ppv_cmd_W','Qpv_cmd_var','pv_theta_rad', ...
    'fpv_Hz','Id_ref_Apk','Iq_ref_Apk','Ipv_limit_Apk','pv_phase_error_rad', ...
    'Ipv_actual_Apk','pv_limit_factor','pv_limit_active','Vpcc_ll_rms_V', ...
    'pv_converter_enable','Pload_W','Qload_var'};

assignin('base','G',G);assignin('base','S1',S1);assignin('base','S21',S21);
fprintf(['STAGE1 R1: fixed load %.1f MW + j%.1f Mvar, PV %.1f -> %.1f MW, ' ...
    'BESS-GFM establishes the 10 kV island bus.\n'], ...
    S1.load.P_W/1e6,S1.load.Q_var/1e6,S1.pv.P_initial_W/1e6,S1.pv.P_final_W/1e6);
