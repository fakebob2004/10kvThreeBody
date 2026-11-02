%INIT_WIND_PMSG_TRANSIENT_R4 Corrected PMSG loss scale and active local PLL.
% R4 is derived from the immutable R3 evidence baseline.
root=fileparts(fileparts(mfilename('fullpath')));
run(fullfile(root,'parameters','init_wind_pmsg_transient_r3.m'));

% Calibrate stator resistance from a transparent rated copper-loss target.
% At 5 MW / 690 V, the inherited 0.015 ohm was 0.1575 pu and produced about
% 0.47 MW copper loss at the 9 m/s operating point.  A 2% rated copper-loss
% target gives a realistic loss scale without pretending to be OEM data.
PMSG.rated_copper_loss_fraction=0.02;
PMSG.rated_torque_Nm=PMSG.Sn_W/PMSG.omega_rated_rad_s;
PMSG.rated_iq_A=-PMSG.rated_torque_Nm/(1.5*PMSG.pole_pairs*PMSG.psi_f_Wb);
PMSG.Rs_ohm=PMSG.rated_copper_loss_fraction*PMSG.Sn_W/ ...
    (1.5*PMSG.rated_iq_A^2);
PMSG.current_Kp=2*pi*PMSG.current_bandwidth_Hz*PMSG.Ld_H;
PMSG.current_Ki=2*pi*PMSG.current_bandwidth_Hz*PMSG.Rs_ohm;
PMSG.Init.vq_pi_V=PMSG.Rs_ohm*PMSG.Init.iq_A;
PMSG.speed_floor_rad_s=0.10;

% R3 contained a working diagnostic SRF-PLL but drove control with a fixed
% nominal angle.  R4 uses the measured local PCC angle.  The bias rotates the
% inherited negative-d-axis lock to positive d and compensates prefilter lag.
Control.ActiveAngleSource='local PCC SRF-PLL';
Control.PLL.ControlAngleBias=-pi+atan(Base.f/Control.PLL.VoltagePrefilterHz);

% Acceptance thresholds used by both standalone and integration status.
PMSG.Validation.minimum_msc_efficiency=0.92;
PMSG.Validation.pll_frequency_min_Hz=49.5;
PMSG.Validation.pll_frequency_max_Hz=50.5;

assignin('base','Control',Control);assignin('base','PMSG',PMSG);
fprintf(['PMSG transient R4 parameters: Rs=%.6g ohm (%.3f pu), ' ...
    'rated copper loss %.1f%%, local PCC SRF-PLL active.\n'], ...
    PMSG.Rs_ohm,PMSG.Rs_ohm/(Base.Vll_lv^2/PMSG.Sn_W), ...
    100*PMSG.rated_copper_loss_fraction);

