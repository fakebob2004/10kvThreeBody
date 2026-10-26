%INIT_WIND_COURSE_SPWM_R2 Parameters for the direct-drive wind course model.
% The names Base/Converter/Filter/Transformer/Grid/Control are retained so
% the locally stored MYVSC seed can be rebuilt without hidden mask numbers.

Base=struct();
Base.Sn=6.25e6;
Base.f=50;
Base.omega=2*pi*Base.f;
Base.Vll_lv=690;
Base.Vll_hv=10e3;
Base.I_lv=Base.Sn/(sqrt(3)*Base.Vll_lv);
Base.I_hv=Base.Sn/(sqrt(3)*Base.Vll_hv);
Base.Z_lv=Base.Vll_lv^2/Base.Sn;
Base.Z_hv=Base.Vll_hv^2/Base.Sn;
Base.Simulation.StopTime=0.16;
Base.Simulation.MaxStep=1/(40*5e3);

Converter=struct();
Converter.Sn=Base.Sn;
Converter.Vll=Base.Vll_lv;
Converter.Vdc_nom=1500;
Converter.Cdc=0.20;
Converter.Cdc_esr=3e-3;
Converter.fsw=5e3;
Converter.Imax_pu=1.10;
Converter.Imax=Converter.Imax_pu*Base.I_lv;
Converter.IdqMax=Converter.Imax_pu*Base.Sn/Base.Vll_lv;
Converter.SwitchOnResistance=1e-3;
Converter.OffConductance=1e-6;
Converter.GateThresholdVoltage=0.5;
Converter.ModulationMax=0.95;

Filter=struct();
Filter.R=0.010*Base.Z_lv;
Filter.L=0.15*Base.Z_lv/Base.omega;

Transformer=struct();
Transformer.Sn=6.3e6;
Transformer.f=Base.f;
Transformer.Vll_primary=Base.Vll_lv;
Transformer.Vll_secondary=Base.Vll_hv;
Transformer.R1_pu=0.005;
Transformer.R2_pu=0.005;
Transformer.X1_pu=0.03;
Transformer.X2_pu=0.03;
Transformer.Xm_pu=500;

Grid=struct();
Grid.Vll=Base.Vll_hv;
Grid.f=Base.f;
Grid.phase_deg=0;
Grid.SCR=20;
Grid.XR=10;
Grid.Zmag=Base.Z_hv/Grid.SCR;
Grid.R=Grid.Zmag/sqrt(1+Grid.XR^2);
Grid.X=Grid.XR*Grid.R;
Grid.L=Grid.X/Base.omega;

PV=struct('Vdc',Converter.Vdc_nom,'Pnom',5e6, ...
    'SourceType','Wind averaged PMSG-MSC energy interface', ...
    'EnableDetailedPV',false);

Control=struct();
Control.Ts=1/(20*Converter.fsw);
Control.PWM.Ts=1/Converter.fsw;
Control.PWM.GatesOff=zeros(1,6);
Control.PWM.CarrierFrequency=Converter.fsw;
Control.PWM.CarrierPeriod=1/Converter.fsw;
Control.PWM.MaxStep=Base.Simulation.MaxStep;
Control.PWM.ModulationIndex=0.75;
Control.PWM.PhaseABC=[0 -2*pi/3 2*pi/3];
Control.PWM.SmokeStopTime=4/Converter.fsw;
Control.PWM.OperatingPointStopTime=0.08;
Control.PLL.Kp=-60;
Control.PLL.Ki=-1400;
Control.PLL.Vbase=Base.Vll_hv;
Control.PLL.OmegaNominal=Base.omega;
Control.PLL.OmegaMin=2*pi*45;
Control.PLL.OmegaMax=2*pi*55;
Control.PLL.VoltagePrefilterHz=200;
Control.PLL.Theta0=-pi/2-atan(Base.f/Control.PLL.VoltagePrefilterHz)+pi;
Control.PLL.ValidationStopTime=0.08;
Control.GridAngle.Omega=Base.omega;
% With zero source phase, the phase-a sinusoid corresponds to a cosine-frame
% initial angle of -90 deg; this makes PCC Vd positive and Vq approximately 0.
Control.GridAngle.Theta0=-pi/2;
Control.Measurement.PowerLPFHz=100;
Control.Current.BandwidthHz=200;
Control.Current.Kp=Filter.L*2*pi*Control.Current.BandwidthHz;
Control.Current.Ki=Filter.R*2*pi*Control.Current.BandwidthHz;
Control.Current.IntegratorLimitV=150;
Control.Vdc.Kp=2;
Control.Vdc.Ki=50;
Control.Vdc.IntegratorLimit=0.20*Converter.IdqMax;
Control.Q.Kp=0;
Control.Q.Ki=0;

Wind=struct();
Wind.P_rated_W=5e6;
Wind.S_pcs_VA=Converter.Sn;
Wind.rho_kg_m3=1.225;
Wind.rotor_radius_m=70;
Wind.rotor_area_m2=pi*Wind.rotor_radius_m^2;
Wind.lambda_opt=8.1;
Wind.Cp_max=0.48;
Wind.Cp_width=3.0;
Wind.wind_initial_mps=9.0;
Wind.wind_step_mps=1.0;
Wind.wind_step_time_s=0.08;
Wind.omega_initial_rad_s=Wind.lambda_opt*Wind.wind_initial_mps/Wind.rotor_radius_m;
Wind.inertia_kg_m2=3.0e7;
Wind.viscous_Nm_per_rad_s=1.0e5;
Wind.generator_efficiency=0.975;
Wind.msc_tau_s=0.010;
Wind.msc_ramp_Wps=50e6;
Wind.pole_pairs=60;
Wind.pmsg_stator_R_ohm=0.015;
Wind.pmsg_stator_L_H=0.35e-3;
Wind.msc_virtual_R_ohm=0.10;
Wind.pmsg_startup_s=0.020;
Wind.torque_max_Nm=Wind.P_rated_W/Wind.omega_initial_rad_s;
Wind.Kopt_Nm_per_rad_s2=0.5*Wind.rho_kg_m3*Wind.rotor_area_m2* ...
    Wind.Cp_max*Wind.rotor_radius_m^3/Wind.lambda_opt^3;
Wind.dc_current_limit_A=1.20*Wind.P_rated_W/Converter.Vdc_nom;
Wind.dc_voltage_floor_V=0.60*Converter.Vdc_nom;
Wind.precharge_R_ohm=1e-3;
Wind.precharge_open_time_s=0.100;
Wind.brake_on_V=1.08*Converter.Vdc_nom;
Wind.brake_off_V=1.04*Converter.Vdc_nom;
Wind.brake_R_ohm=0.50;
Wind.brake_current_limit_A=4000;
Wind.brake_switch_Ron_ohm=1e-3;
Wind.brake_switch_Goff_S=1e-6;
Wind.loss_constant_W=0.005*Wind.P_rated_W;
Wind.validation_tail_s=0.02;

assignin('base','Base',Base);assignin('base','Converter',Converter);
assignin('base','Filter',Filter);assignin('base','Transformer',Transformer);
assignin('base','Grid',Grid);assignin('base','PV',PV);
assignin('base','Control',Control);assignin('base','Wind',Wind);
fprintf(['Wind course SPWM R2 parameters: 5 MW turbine, 6.25 MVA PCS, ' ...
    '1500 Vdc, 690 V/10 kV, 5 kHz\n']);
