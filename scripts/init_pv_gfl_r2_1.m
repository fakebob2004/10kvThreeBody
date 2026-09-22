% R2.1 standalone commissioning parameters.  R2 remains unchanged.
scriptDir=fileparts(mfilename('fullpath'));
run(fullfile(scriptDir,'init_pv_gfl_864_average_sm.m'));

S21=struct();
S21.revision='PV-GFL-R2.1-readable-standalone';
S21.control.Ibase_rms_A=S1.pv.S_pcs_VA/(sqrt(3)*S1.pv.Vll_low_V);
S21.control.Ilimit_peak_A=sqrt(2)*1.10*S21.control.Ibase_rms_A;
S21.command.enable_off_time_s=10;
S21.command.enable_on_time_s=11;
S21.command.enable_drop=0;
S21.status.channel_map={ ...
    't_s','P_W','Q_var','Pcmd_W','Qcmd_var','theta_rad','f_Hz', ...
    'Id_ref_Apk','Iq_ref_Apk','Ilimit_Apk','phase_error_rad', ...
    'Iactual_Apk','limit_factor','limit_active','Vpcc_ll_rms_V','converter_enable'};

% R2 used an RMS base directly on peak dq currents.  R2.1 makes the unit
% convention explicit and leaves the accepted R2 file untouched.
S1.control.Ilimit_A=S21.control.Ilimit_peak_A;
assignin('base','S1',S1);assignin('base','S21',S21);
fprintf('PV-GFL R2.1: current limit %.1f Apeak (1.10 pu of %.1f Arms)\n', ...
    S21.control.Ilimit_peak_A,S21.control.Ibase_rms_A);
