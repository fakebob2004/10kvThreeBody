%INIT_WIND_PMSG_TRANSIENT_R3 Parameters for the derived PMSG transient model.
% R3 retains the accepted physical DC link, switching GSC, transformer and
% grid from Wind_DirectDrive_SPWM_R2, while replacing the single-mass and
% average torque actuator with a two-mass shaft, explicit PMSG dq electrical
% states, and an averaged MSC field-oriented current controller.

root=fileparts(fileparts(mfilename('fullpath')));
run(fullfile(root,'parameters','init_wind_course_spwm_r2.m'));

% General transient-study scenario: below-rated start followed by a wind step.
Wind.wind_initial_mps=9.0;
Wind.wind_step_mps=1.5;
Wind.wind_step_time_s=0.12;
Wind.omega_initial_rad_s=Wind.lambda_opt*Wind.wind_initial_mps/Wind.rotor_radius_m;
Base.Simulation.StopTime=0.30;
Base.Simulation.MaxStep=1/(40*Converter.fsw);

Drive=struct();
Drive.J_total_kg_m2=3.0e7;
Drive.J_turbine_kg_m2=0.83*Drive.J_total_kg_m2;
Drive.J_generator_kg_m2=Drive.J_total_kg_m2-Drive.J_turbine_kg_m2;
Drive.torsional_frequency_Hz=1.5;
Drive.damping_ratio=0.08;
Drive.J_reduced=Drive.J_turbine_kg_m2*Drive.J_generator_kg_m2/ ...
    (Drive.J_turbine_kg_m2+Drive.J_generator_kg_m2);
Drive.K_shaft_Nm_per_rad=(2*pi*Drive.torsional_frequency_Hz)^2*Drive.J_reduced;
Drive.D_shaft_Nms_per_rad=2*Drive.damping_ratio* ...
    sqrt(Drive.K_shaft_Nm_per_rad*Drive.J_reduced);
Drive.B_turbine_Nms_per_rad=0.8*Wind.viscous_Nm_per_rad_s;
Drive.B_generator_Nms_per_rad=0.2*Wind.viscous_Nm_per_rad_s;

PMSG=struct();
PMSG.Sn_W=Wind.P_rated_W;
PMSG.pole_pairs=Wind.pole_pairs;
PMSG.Rs_ohm=Wind.pmsg_stator_R_ohm;
PMSG.Ld_H=Wind.pmsg_stator_L_H;
PMSG.Lq_H=Wind.pmsg_stator_L_H;
PMSG.rated_wind_mps=10.5;
PMSG.omega_rated_rad_s=Wind.lambda_opt*PMSG.rated_wind_mps/Wind.rotor_radius_m;
PMSG.psi_f_Wb=Base.Vll_lv*sqrt(2/3)/(PMSG.pole_pairs*PMSG.omega_rated_rad_s);
PMSG.current_base_peak_A=sqrt(2)*PMSG.Sn_W/(sqrt(3)*Base.Vll_lv);
PMSG.current_limit_A=1.25*PMSG.current_base_peak_A;
PMSG.torque_limit_Nm=1.5*PMSG.pole_pairs*PMSG.psi_f_Wb*PMSG.current_limit_A;
PMSG.msc_efficiency=0.985;
PMSG.loss_constant_W=0.003*PMSG.Sn_W;
PMSG.modulation_max=0.95;
PMSG.current_bandwidth_Hz=300;
PMSG.current_Kp=2*pi*PMSG.current_bandwidth_Hz*PMSG.Ld_H;
PMSG.current_Ki=2*pi*PMSG.current_bandwidth_Hz*PMSG.Rs_ohm;
PMSG.integrator_limit_V=250;

% Consistent initial MPPT, shaft-torque and electrical-current state.
PMSG.Init.omega_rad_s=Wind.omega_initial_rad_s;
PMSG.Init.torque_ref_Nm=min(Wind.Kopt_Nm_per_rad_s2* ...
    PMSG.Init.omega_rad_s^2,PMSG.torque_limit_Nm);
PMSG.Init.id_A=0;
PMSG.Init.iq_A=-PMSG.Init.torque_ref_Nm/(1.5*PMSG.pole_pairs*PMSG.psi_f_Wb);
PMSG.Init.vd_pi_V=0;
PMSG.Init.vq_pi_V=PMSG.Rs_ohm*PMSG.Init.iq_A;
PMSG.Init.shaft_angle_rad=(PMSG.Init.torque_ref_Nm+ ...
    Drive.B_generator_Nms_per_rad*PMSG.Init.omega_rad_s)/Drive.K_shaft_Nm_per_rad;

PMSG.Validation.current_tracking_fraction=0.10;
PMSG.Validation.vdc_min_V=1400;
PMSG.Validation.vdc_max_V=1600;
PMSG.Validation.speed_split_max_rad_s=0.10;

assignin('base','Base',Base);assignin('base','Converter',Converter);
assignin('base','Filter',Filter);assignin('base','Transformer',Transformer);
assignin('base','Grid',Grid);assignin('base','PV',PV);
assignin('base','Control',Control);assignin('base','Wind',Wind);
assignin('base','Drive',Drive);assignin('base','PMSG',PMSG);
fprintf(['PMSG transient R3 parameters: 5 MW, two-mass shaft, explicit dq ' ...
    'machine, averaged MSC current loop, switching 6.25 MVA GSC.\n']);
