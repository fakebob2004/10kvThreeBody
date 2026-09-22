% 5 MW / 10 MWh GFM-BESS branch parameters for MYVSC C0.
% B1 remains on its original 100 kVA teaching base; these overrides apply
% only to GFM_Inverter_C0 after init_project has loaded the common defaults.
if ~exist('Base','var')
    Base=evalin('base','Base');Converter=evalin('base','Converter');
    Filter=evalin('base','Filter');Transformer=evalin('base','Transformer');
    Grid=evalin('base','Grid');PV=evalin('base','PV');Control=evalin('base','Control');
end
Base.Sn = 6.25e6;
Base.Vll_lv = 690;
Base.Vll_hv = 10e3;
Base.I_lv = Base.Sn/(sqrt(3)*Base.Vll_lv);
Base.I_hv = Base.Sn/(sqrt(3)*Base.Vll_hv);
Base.Z_lv = Base.Vll_lv^2/Base.Sn;
Base.Z_hv = Base.Vll_hv^2/Base.Sn;

Converter.Sn = 6.25e6;
Converter.Vll = Base.Vll_lv;
Converter.Vdc_nom = 1500;
Converter.Cdc = 0.05;
Converter.Cdc_esr = 3e-3;
Converter.fsw = 5e3;
Converter.Imax_pu = 1.20;
Converter.Imax = Converter.Imax_pu*Base.I_lv;

% MYVSC presently has one series RL filter block.  Use the sum of the
% previously designed LCL converter/grid inductors and winding loss.
Filter.R = (0.005+0.005)*Base.Z_lv;
Filter.L = (0.08+0.03)*Base.Z_lv/Base.omega;
Transformer.Sn = 6.3e6;
Transformer.Vll_primary = 690;
Transformer.Vll_secondary = 10e3;

Grid.Vll = 10e3;
Grid.SCR = 250e6/Base.Sn;
Grid.XR = 10;
Grid.Zmag = Base.Vll_hv^2/250e6;
Grid.R = Grid.Zmag/sqrt(1+Grid.XR^2);
Grid.X = Grid.XR*Grid.R;
Grid.L = Grid.X/Base.omega;
PV.Vdc = Converter.Vdc_nom;

Control.PWM.CarrierFrequency = Converter.fsw;
Control.PWM.CarrierPeriod = 1/Converter.fsw;
Control.PWM.MaxStep = 1/(50*Converter.fsw);
Control.PWM.Ts = 1/Converter.fsw;

GFM.BESS_P_W = 5e6;
GFM.BESS_S_VA = 6.25e6;
GFM.BESS_E_Wh = 10e6;
GFM.BatteryNominal_V = 1200;
GFM.BatteryCapacity_Ah = GFM.BESS_E_Wh/GFM.BatteryNominal_V;
GFM.SOC0 = 0.55;
GFM.Pref_W = 5e6;
GFM.Qref_var = 0;
GFM.Vll_ref_V = Base.Vll_lv;
GFM.omega0_rad_s = Base.omega;
GFM.mp_rad_s_per_W = 2*pi*0.50/GFM.BESS_P_W;   % 0.5 Hz at 5 MW
GFM.nq_V_per_var = 0.05*Base.Vll_lv/GFM.BESS_P_W;
GFM.power_lpf_Hz = 20;
GFM.omega_min_rad_s = 2*pi*49;
GFM.omega_max_rad_s = 2*pi*51;
GFM.Vll_min_V = 0.90*Base.Vll_lv;
GFM.Vll_max_V = 1.10*Base.Vll_lv;
GFM.modulation_max_pu = 0.95;
GFM.Ipeak_limit_A = sqrt(2)*Converter.Imax*Base.I_hv/Base.I_lv;
GFM.current_epsilon_A = 1e-3;
GFM.theta0_rad = 0;
GFM.phaseABC = [0 -2*pi/3 2*pi/3];
GFM.StopTime = 0.04;

assignin('base','Base',Base);assignin('base','Converter',Converter);
assignin('base','Filter',Filter);assignin('base','Transformer',Transformer);
assignin('base','Grid',Grid);assignin('base','PV',PV);
assignin('base','Control',Control);assignin('base','GFM',GFM);
