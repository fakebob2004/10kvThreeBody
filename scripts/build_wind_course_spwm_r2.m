%BUILD_WIND_COURSE_SPWM_R2 Direct-drive wind generator course model.
% Creates a new asset; accepted Wind R1 and Stage-2 models are not modified.

scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
seed=fullfile(root,'references','course_seed','MYVSC_GFL_Inverter_B2_seed.slx');
model='Wind_DirectDrive_SPWM_R2';
modelFile=fullfile(root,'build',[model '.slx']);
assert(isfile(seed),'Missing local course seed: %s',seed);
run(fullfile(root,'parameters','init_wind_course_spwm_r2.m'));
if bdIsLoaded(model),close_system(model,0);end
copyfile(seed,modelFile,'f');load_system(modelFile);
load_system('fl_lib');load_system('ee_lib');load_system('nesl_utility');

set_param(model,'PreLoadFcn','');
initCmd=char("root=fileparts(fileparts(get_param(bdroot,'FileName'))); " + ...
    "run(fullfile(root,'parameters','init_wind_course_spwm_r2.m'));");
set_param(model,'InitFcn',initCmd,'StopTime','Base.Simulation.StopTime', ...
    'MaxStep','Base.Simulation.MaxStep','Solver','ode15s','MinStep','auto', ...
    'SignalLogging','on','SignalLoggingName','logsout', ...
    'Location',[30 50 1700 930]);

renameBlock(model,'GFL Controller B2','04 GFL Control and SPWM');
renameBlock(model,'Two-Level VSC','03 DC Link and Two-Level GSC');
renameBlock(model,'Grid Interface (Filter XFMR PCC)','05 Filter Transformer and PCC');
renameBlock(model,'Grid Equivalent and Source','06 Grid Equivalent and Source');
normalizeGridInterface(model);

aero=[model '/01 Wind Turbine Aerodynamics'];
msc=[model '/02 PMSG and MSC Average Model'];
add_block('built-in/Subsystem',aero,'Position',[45 70 350 240], ...
    'BackgroundColor','[0.84,0.94,0.82]','FontWeight','bold', ...
    'ContentPreviewEnabled','off');
buildAerodynamics(aero);
add_block('built-in/Subsystem',msc,'Position',[430 70 735 240], ...
    'BackgroundColor','[0.96,0.91,0.76]','FontWeight','bold', ...
    'ContentPreviewEnabled','off');
buildPMSGMSC(msc);

vsc=[model '/03 DC Link and Two-Level GSC'];
controller=[model '/04 GFL Control and SPWM'];
buildWindDCLink(vsc);
exposeConverterMeasurements(vsc);
buildClosedLoopController(controller);
moveSubsystemPortToSide(aero,'In1','RIGHT');
moveSubsystemPortToSide(msc,'Out1','LEFT');
moveSubsystemPortToSide(controller,'In1','RIGHT','first');
fprintf('WIND_BUILD_BLOCKS_OK=1\n');

set_param(vsc,'Position',[750 270 1025 440]);
set_param(controller,'Position',[400 315 675 485]);
set_param([model '/05 Filter Transformer and PCC'],'Position',[1110 270 1395 440]);
set_param([model '/06 Grid Equivalent and Source'],'Position',[1480 270 1735 440]);
wire(model,'01 Wind Turbine Aerodynamics/2', ...
    '02 PMSG and MSC Average Model/1','omega_rotor_rad_s');
wire(model,'02 PMSG and MSC Average Model/1', ...
    '01 Wind Turbine Aerodynamics/1','T_e_Nm');
wire(model,'02 PMSG and MSC Average Model/2', ...
    '03 DC Link and Two-Level GSC/1','P_msc_W');
wire(model,'02 PMSG and MSC Average Model/2', ...
    '04 GFL Control and SPWM/1','');
routeNamedLineShortest(model,'omega_rotor_rad_s');
routeNamedLineShortest(model,'T_e_Nm');
routeNamedLineShortest(model,'P_msc_W');
routeNamedLineShortest(model,'GateDrivePhysical');
routeNamedLineShortest(model,'VSC_AC_Terminal');
routeNamedLineShortest(model,'PCC_to_Grid');
fprintf('WIND_BUILD_TOP_WIRING_OK=1\n');

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(model,[45 535 1690 590],sprintf([ ...
    'DIRECT-DRIVE WIND GENERATOR COURSE MODEL — 5 MW / 6.25 MVA\n' ...
    'Cp(lambda,beta) + rotor inertia -> average PMSG/MSC -> physical 1500 V DC link -> 5 kHz SPWM two-level GSC -> 690 V/10 kV PCC']));
note(model,[50 610 1690 650], ...
    'Machine-side converter is an electromechanical-energy average model; the grid-side converter is a detailed switching bridge.');

for n={'wind_speed_mps','omega_rotor_rad_s','P_aero_W','T_e_Nm','P_msc_W', ...
        'Vdc_Meas','theta_PLL','omega_PLL','Id_cmd_raw','Iq_cmd_raw', ...
        'Id_ref_lim','Iq_ref_lim','Id_converter','Iq_converter', ...
        'Vd_pcc_lv','Vq_pcc_lv','Vabc_mod', ...
        'Gate_AH','Gate_AL','Gate_BH','Gate_BL','Gate_CH','Gate_CL','Vll_inv', ...
        'Iabc_Converter_Meas','P_PCC','Q_PCC', ...
        'brake_current_A'}
    enableNamedSignalLogging(model,n{1});
end
fprintf('WIND_BUILD_LOGGING_OK=1\n');
disableSubsystemPreviews(model);
fprintf('WIND_BUILD_PREVIEWS_OK=1\n');
set_param(model,'Description',sprintf([ ...
    'Course model: readable direct-drive wind turbine, averaged PMSG/MSC, ' ...
    'physical DC energy buffer, staged DC support and detailed SPWM GFL bridge.']));
save_system(model,modelFile);
fprintf('WIND_COURSE_SPWM_R2_PRECOMPILE_SAVE_OK=1\n');
set_param(model,'SimulationCommand','update');
fprintf('WIND_COURSE_SPWM_R2_COMPILE_OK=1\n');
save_system(model,modelFile);
skipRender=strcmp(getenv('WIND_SKIP_RENDER'),'1');
if ~skipRender
renderSystem(model,fullfile(root,'build','WIND_COURSE_R2_01_Top.png'));
renderSystem(aero,fullfile(root,'build','WIND_COURSE_R2_02_Aerodynamics.png'));
renderSystem(msc,fullfile(root,'build','WIND_COURSE_R2_03_PMSG_MSC.png'));
renderSystem(vsc,fullfile(root,'build','WIND_COURSE_R2_04_DC_GSC.png'));
renderSystem([vsc '/DC Control and Monitoring'], ...
    fullfile(root,'build','WIND_COURSE_R2_04B_DC_Control.png'));
renderSystem(controller,fullfile(root,'build','WIND_COURSE_R2_05_Control.png'));
renderSystem([controller '/01 Measurements and dq'], ...
    fullfile(root,'build','WIND_COURSE_R2_05A_Measurements_dq.png'));
renderSystem([controller '/02 Synchronization SRF-PLL'], ...
    fullfile(root,'build','WIND_COURSE_R2_05B_SRF_PLL.png'));
renderSystem([controller '/03 DC Voltage and Current Reference'], ...
    fullfile(root,'build','WIND_COURSE_R2_05C_DC_Reference.png'));
renderSystem([controller '/04 Circular Current Limiter'], ...
    fullfile(root,'build','WIND_COURSE_R2_05D_Current_Limiter.png'));
renderSystem([controller '/06 SPWM and Physical Gate Interface'], ...
    fullfile(root,'build','WIND_COURSE_R2_06_PWM_Gate_Order.png'));
renderSystem([controller '/05 dq Current Controller'], ...
    fullfile(root,'build','WIND_COURSE_R2_07_Current_Controller.png'));
renderSystem([model '/05 Filter Transformer and PCC'], ...
    fullfile(root,'build','WIND_COURSE_R2_08_Filter_Transformer_PCC.png'));
renderSystem([model '/06 Grid Equivalent and Source'], ...
    fullfile(root,'build','WIND_COURSE_R2_09_Grid_Equivalent.png'));
else
    fprintf('WIND_COURSE_SPWM_R2_RENDER_SKIPPED=1\n');
end
close_system(model,0);
fprintf('WIND_COURSE_SPWM_R2_BUILD_OK=1\nMODEL=%s\n',modelFile);

function normalizeGridInterface(model)
iface=[model '/05 Filter Transformer and PCC'];
old=[iface '/0.4 kV to 10 kV Step-Up Transformer'];
if getSimulinkBlockHandle(old)>0
    set_param(old,'Name','0.69 kV to 10 kV Step-Up Transformer');
end
% Preserve the functional package (filter + transformer + PCC sensing), but
% make its electrical path and both measurement conversions locally direct.
set_param([iface '/From_VSC'],'Position',[20 180 50 210]);
set_param([iface '/AC Filter Rf + Lf'],'Position',[120 140 270 250]);
set_param([iface '/0.69 kV to 10 kV Step-Up Transformer'], ...
    'Position',[360 115 580 275]);
set_param([iface '/PCC VI Sensor'],'Position',[675 140 795 250]);
set_param([iface '/Vabc PCC to Simulink'],'Position',[835 145 930 175], ...
    'ShowName','off');
set_param([iface '/Iabc PCC to Simulink'],'Position',[835 180 930 210], ...
    'ShowName','off');
set_param([iface '/Vabc_PCC_Meas Tag'],'Position',[960 147 1055 173], ...
    'ShowName','off');
set_param([iface '/Iabc_PCC_Meas Tag'],'Position',[960 182 1055 208], ...
    'ShowName','off');
set_param([iface '/To_Grid'],'Position',[1010 215 1040 245]);

from=get_param([iface '/From_VSC'],'PortHandles');
filter=get_param([iface '/AC Filter Rf + Lf'],'PortHandles');
xfmr=get_param([iface '/0.69 kV to 10 kV Step-Up Transformer'],'PortHandles');
sensor=get_param([iface '/PCC VI Sensor'],'PortHandles');
toGrid=get_param([iface '/To_Grid'],'PortHandles');
vconv=get_param([iface '/Vabc PCC to Simulink'],'PortHandles');
iconv=get_param([iface '/Iabc PCC to Simulink'],'PortHandles');
vtag=get_param([iface '/Vabc_PCC_Meas Tag'],'PortHandles');
itag=get_param([iface '/Iabc_PCC_Meas Tag'],'PortHandles');
routePhysicalLineDirect(from.RConn(1),filter.LConn(1));
routePhysicalLineDirect(filter.RConn(1),xfmr.LConn(1));
routePhysicalLineDirect(xfmr.RConn(1),sensor.LConn(1));
routePhysicalLineDirect(sensor.RConn(1),vconv.LConn(1));
routePhysicalLineDirect(sensor.RConn(2),iconv.LConn(1));
routePhysicalLineDirect(sensor.RConn(3),toGrid.RConn(1));
routePhysicalLineDirect(vconv.Outport(1),vtag.Inport(1));
routePhysicalLineDirect(iconv.Outport(1),itag.Inport(1));
anns=find_system(iface,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(iface,[45 305 1040 350], ...
    'Direct power path: Rf + Lf -> 0.69/10 kV Y-Y transformer -> PCC VI sensor. Measurements remain internal and logged.');

grid=[model '/06 Grid Equivalent and Source'];
source=[grid '/Ideal Three-Phase Grid Source'];
% Rg + Lg is modeled explicitly, so the ideal source must not add a second
% hidden Thevenin impedance inherited from the seed model.
set_param(source,'impedance_option','0','Orientation','left', ...
    'Position',[335 130 475 260]);
set_param([grid '/From_PCC'],'Position',[20 180 50 210]);
set_param([grid '/Grid Equivalent Rg + Lg'],'Position',[110 140 260 250]);
set_param([grid '/Grid Neutral Ground'],'Position',[470 270 510 310], ...
    'Orientation','down');

fromPcc=get_param([grid '/From_PCC'],'PortHandles');
gridZ=get_param([grid '/Grid Equivalent Rg + Lg'],'PortHandles');
gridSource=get_param(source,'PortHandles');
gridGround=get_param([grid '/Grid Neutral Ground'],'PortHandles');
routePhysicalLineDirect(fromPcc.RConn(1),gridZ.LConn(1));
routePhysicalLineDirect(gridZ.RConn(1),gridSource.RConn(1));
routePhysicalLineDirect(gridSource.LConn(1),gridGround.LConn(1));
anns=find_system(grid,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(grid,[45 330 700 375], ...
    'Single Thevenin impedance: explicit SCR-based Rg + Lg followed by an ideal grounded-wye source (internal source impedance OFF).');
end

function buildAerodynamics(sys)
% Arrange the diagram as two compact left-to-right signal-flow lanes.
% Boundary blocks are placed next to their source/consumer so the primary
% output and feedback stubs remain short even when the subsystem is resized.
inport(sys,'Electromagnetic Torque Te',1,[705 315 735 335]);
outport(sys,'Aerodynamic Power',1,[1040 75 1070 95]);
outport(sys,'Rotor Speed omega',2,[365 270 395 290]);
outport(sys,'Wind Speed',3,[245 90 275 110]);
set_param([sys '/Electromagnetic Torque Te'],'Orientation','left');
set_param([sys '/Rotor Speed omega'],'Orientation','left');
add_block('simulink/Sources/Constant',[sys '/Initial Wind Speed'], ...
    'Position',[25 30 135 60],'Value','Wind.wind_initial_mps');
add_block('simulink/Sources/Step',[sys '/Wind Speed Step'], ...
    'Position',[25 90 135 120],'Time','Wind.wind_step_time_s', ...
    'Before','0','After','Wind.wind_step_mps');
add_block('simulink/Math Operations/Sum',[sys '/Wind Speed Profile'], ...
    'Position',[175 40 210 110],'Inputs','++');
add_block('simulink/Signal Routing/Mux',[sys '/lambda inputs'], ...
    'Position',[315 45 320 125],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[sys '/Tip-Speed Ratio lambda'], ...
    'Position',[355 60 490 100], ...
    'Expr','2*u(1)*Wind.rotor_radius_m/(u(2)+0.1+abs(u(2)-0.1))');
add_block('simulink/User-Defined Functions/Fcn',[sys '/Cp Curve'], ...
    'Position',[525 60 655 100], ...
    'Expr','Wind.Cp_max*exp(-((u-Wind.lambda_opt)/Wind.Cp_width)^2)');
add_block('simulink/Signal Routing/Mux',[sys '/Power inputs'], ...
    'Position',[690 45 695 125],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[sys '/Aerodynamic Power Equation'], ...
    'Position',[730 60 865 100], ...
    'Expr','0.5*Wind.rho_kg_m3*Wind.rotor_area_m2*u(1)*u(2)^3');
add_block('simulink/Discontinuities/Saturation',[sys '/Aerodynamic Power Limit'], ...
    'Position',[900 60 1010 100],'LowerLimit','0', ...
    'UpperLimit','1.10*Wind.P_rated_W');
add_block('simulink/Signal Routing/Mux',[sys '/Torque inputs'], ...
    'Position',[920 225 925 305],'Inputs','2','Orientation','left');
add_block('simulink/User-Defined Functions/Fcn',[sys '/Mechanical Torque'], ...
    'Position',[745 245 880 285],'Orientation','left', ...
    'Expr','2*u(1)/(u(2)+0.2+abs(u(2)-0.2))');
add_block('simulink/Math Operations/Gain',[sys '/Viscous Torque'], ...
    'Position',[490 325 585 355],'Gain','Wind.viscous_Nm_per_rad_s');
add_block('simulink/Math Operations/Sum',[sys '/Net Rotor Torque'], ...
    'Position',[620 245 655 315],'Inputs','+--','Orientation','left');
add_block('simulink/Math Operations/Gain',[sys '/Inverse Inertia'], ...
    'Position',[515 260 580 300],'Gain','1/Wind.inertia_kg_m2', ...
    'Orientation','left');
add_block('simulink/Continuous/Integrator',[sys '/Rotor Inertia'], ...
    'Position',[440 255 480 305],'Orientation','left', ...
    'InitialCondition','Wind.omega_initial_rad_s');
wire(sys,'Initial Wind Speed/1','Wind Speed Profile/1','');
wire(sys,'Wind Speed Step/1','Wind Speed Profile/2','');
wire(sys,'Wind Speed Profile/1','Wind Speed/1','wind_speed_mps');
wire(sys,'Wind Speed Profile/1','lambda inputs/2','');
wire(sys,'lambda inputs/1','Tip-Speed Ratio lambda/1','lambda_tsr');
wire(sys,'Tip-Speed Ratio lambda/1','Cp Curve/1','Cp');
wire(sys,'Cp Curve/1','Power inputs/1','');
wire(sys,'Wind Speed Profile/1','Power inputs/2','');
wire(sys,'Power inputs/1','Aerodynamic Power Equation/1','');
wire(sys,'Aerodynamic Power Equation/1','Aerodynamic Power Limit/1','');
wire(sys,'Aerodynamic Power Limit/1','Aerodynamic Power/1','P_aero_W');
wire(sys,'Aerodynamic Power Limit/1','Torque inputs/1','');
wire(sys,'Torque inputs/1','Mechanical Torque/1','');
wire(sys,'Mechanical Torque/1','Net Rotor Torque/1','');
wire(sys,'Electromagnetic Torque Te/1','Net Rotor Torque/2','');
wire(sys,'Viscous Torque/1','Net Rotor Torque/3','');
wire(sys,'Net Rotor Torque/1','Inverse Inertia/1','');
wire(sys,'Inverse Inertia/1','Rotor Inertia/1','');
wire(sys,'Rotor Inertia/1','Rotor Speed omega/1','omega_rotor_rad_s');
wire(sys,'Rotor Inertia/1','Viscous Torque/1','');
hOmegaTorque=wire(sys,'Rotor Inertia/1','Torque inputs/2','');
wire(sys,'Rotor Inertia/1','lambda inputs/1','');
% Rotor speed is reused by the mechanical-torque division.  Route this
% feedback outside the mechanical state chain instead of cutting across the
% inertia, damping, and net-torque signals.
rotorPorts=get_param([sys '/Rotor Inertia'],'PortHandles');
torqueMuxPorts=get_param([sys '/Torque inputs'],'PortHandles');
omegaSrc=get_param(rotorPorts.Outport(1),'Position');
omegaTorqueDst=get_param(torqueMuxPorts.Inport(2),'Position');
set_param(hOmegaTorque,'Points',[omegaSrc;410 omegaSrc(2);410 385; ...
    955 385;955 omegaTorqueDst(2);omegaTorqueDst]);
note(sys,[65 410 1015 455], ...
    'P_aero = 0.5*rho*A*Cp(lambda)*v^3; J*domega/dt = T_aero - T_e - B*omega. Pitch is fixed at 0 deg for below-rated course tests.');
end

function buildPMSGMSC(sys)
% Two compact left-to-right lanes: torque command/actuator above and
% electromechanical power conversion below. Outputs sit by their sources.
inport(sys,'Rotor Speed omega',1,[20 85 50 105]);
outport(sys,'Electromagnetic Torque Te',1,[565 80 595 100]);
outport(sys,'MSC DC Power',2,[825 195 855 215]);
add_block('simulink/User-Defined Functions/Fcn',[sys '/MPPT Torque Law'], ...
    'Position',[90 70 220 110], ...
    'Expr',['0.5*(Wind.Kopt_Nm_per_rad_s2*u^2+Wind.torque_max_Nm-' ...
    'abs(Wind.Kopt_Nm_per_rad_s2*u^2-Wind.torque_max_Nm))']);
add_block('simulink/Continuous/Transfer Fcn',[sys '/MSC Torque Response'], ...
    'Position',[255 70 375 110],'Numerator','1', ...
    'Denominator','[Wind.msc_tau_s 1]');
add_block('simulink/Discontinuities/Saturation',[sys '/MSC Torque Limit'], ...
    'Position',[410 70 530 110],'LowerLimit','0', ...
    'UpperLimit','Wind.torque_max_Nm');
add_block('simulink/Math Operations/Product',[sys '/Air-Gap Power'], ...
    'Position',[310 185 360 225]);
add_block('simulink/Math Operations/Gain',[sys '/Generator and MSC Efficiency'], ...
    'Position',[395 185 520 225],'Gain','Wind.generator_efficiency');
add_block('simulink/Math Operations/Bias',[sys '/Auxiliary Loss'], ...
    'Position',[550 185 640 225],'Bias','-Wind.loss_constant_W');
add_block('simulink/Discontinuities/Saturation',[sys '/MSC Power Limit'], ...
    'Position',[670 185 790 225],'LowerLimit','0', ...
    'UpperLimit','Wind.P_rated_W');
wire(sys,'Rotor Speed omega/1','MPPT Torque Law/1','');
wire(sys,'MPPT Torque Law/1','MSC Torque Response/1','T_e_ref_Nm');
wire(sys,'MSC Torque Response/1','MSC Torque Limit/1','');
wire(sys,'MSC Torque Limit/1','Electromagnetic Torque Te/1','T_e_Nm');
wire(sys,'MSC Torque Limit/1','Air-Gap Power/1','');
wire(sys,'Rotor Speed omega/1','Air-Gap Power/2','');
wire(sys,'Air-Gap Power/1','Generator and MSC Efficiency/1','P_airgap_W');
wire(sys,'Generator and MSC Efficiency/1','Auxiliary Loss/1','');
wire(sys,'Auxiliary Loss/1','MSC Power Limit/1','');
wire(sys,'MSC Power Limit/1','MSC DC Power/1','P_msc_W');
note(sys,[70 300 830 345], ...
    'Average PMSG/MSC: T_e*=Kopt*omega^2, limited torque actuator, P_msc=eta*T_e*omega-P_loss. No machine-side switching ripple is claimed.');
end

function buildWindDCLink(sys)
old=[sys '/Controllable DC Source'];deleteBlockAndLines(old);
deleteBlockAndLines([sys '/Vdc_Meas Tag']);
anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
% The physical stage uses one straight positive rail (y=115) and one
% straight negative rail (y=205). Every shunt device is vertical.
set_param([sys '/DC-Link Capacitor'],'Position',[560 130 640 190], ...
    'Orientation','down');
set_param([sys '/DC Negative Reference'],'Position',[750 250 790 290], ...
    'Orientation','down');
set_param([sys '/Solver Configuration'],'Position',[70 250 120 300], ...
    'Orientation','up');
set_param([sys '/Vdc Sensor'],'Position',[375 130 465 190], ...
    'Orientation','down');
set_param([sys '/Vdc to Simulink'],'Position',[415 390 515 430]);
set_param([sys '/Two-Level Three-Phase Bridge'], ...
    'Position',[850 70 970 250],'Orientation','left');
set_param([sys '/Gate Drive'],'Position',[1005 100 1035 130], ...
    'Orientation','left');
set_param([sys '/Converter AC Measurement'],'Position',[1020 145 1210 265]);
set_param([sys '/AC_Terminal'],'Position',[1250 190 1280 220]);
inport(sys,'Pmsc',1,[470 475 500 495]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
    [sys '/MSC Current Injection'],'Position',[700 130 785 190]);
add_block('ee_lib/Sources/Voltage Source',[sys '/DC Precharge Source'], ...
    'Position',[60 130 130 190],'dc_voltage','Converter.Vdc_nom', ...
    'Orientation','down');
add_block(sprintf('ee_lib/Semiconductors &\nConverters/Ideal Semiconductor\nSwitch'), ...
    [sys '/Precharge Disconnect Switch'],'Position',[235 25 315 100], ...
    'Orientation','down', ...
    'Ron','Wind.brake_switch_Ron_ohm','Goff','Wind.brake_switch_Goff_S', ...
    'Vth','0.5');
add_block('ee_lib/Passive/Resistor',[sys '/Precharge Resistor'], ...
    'Position',[335 87 405 143],'R','Wind.precharge_R_ohm');
add_block('simulink/Sources/Step',[sys '/Precharge Open Command'], ...
    'Position',[80 20 185 50],'Time','Wind.precharge_open_time_s', ...
    'Before','1','After','0');
add_block('nesl_utility/Simulink-PS Converter',[sys '/Precharge Gate to Physical'], ...
    'Position',[190 5 225 65],'Unit','1');

ctrl=[sys '/DC Control and Monitoring'];
add_block('built-in/Subsystem',ctrl,'Position',[535 360 915 530], ...
    'BackgroundColor','[0.86,0.92,1.00]','FontWeight','bold', ...
    'ContentPreviewEnabled','off');
buildDCControlAndMonitoring(ctrl);
moveSubsystemPortToSide(ctrl,'Out1','TOP');
add_block('nesl_utility/Simulink-PS Converter',[sys '/MSC Current to Physical'], ...
    'Position',[675 265 775 325],'Unit','A','Orientation','up');
add_block('simulink/Sinks/Terminator',[sys '/Sampled Vdc Monitor'], ...
    'Position',[960 445 980 465]);
add_block('simulink/Sinks/Terminator',[sys '/Brake Current Monitor'], ...
    'Position',[960 500 980 520]);
cap=get_param([sys '/DC-Link Capacitor'],'PortHandles');
inj=get_param([sys '/MSC Current Injection'],'PortHandles');
ips=get_param([sys '/MSC Current to Physical'],'PortHandles');
pre=get_param([sys '/DC Precharge Source'],'PortHandles');
psw=get_param([sys '/Precharge Disconnect Switch'],'PortHandles');
rpre=get_param([sys '/Precharge Resistor'],'PortHandles');
pgate=get_param([sys '/Precharge Gate to Physical'],'PortHandles');
sen=get_param([sys '/Vdc Sensor'],'PortHandles');
vdcConv=get_param([sys '/Vdc to Simulink'],'PortHandles');
bridge=get_param([sys '/Two-Level Three-Phase Bridge'],'PortHandles');
gate=get_param([sys '/Gate Drive'],'PortHandles');
meas=get_param([sys '/Converter AC Measurement'],'PortHandles');
gnd=get_param([sys '/DC Negative Reference'],'PortHandles');
solver=get_param([sys '/Solver Configuration'],'PortHandles');
disconnectPortLines([cap.LConn(1) cap.RConn(1) sen.LConn(1) sen.RConn(2) ...
    bridge.RConn(1) bridge.RConn(2) gnd.LConn(1) solver.RConn(1)]);

% Build each rail from short consecutive segments. With every electrical
% terminal on y=115 or y=205, Simulink renders one positive and one negative
% horizontal conductor instead of several parallel autorouted branches.
add_line(sys,ips.RConn(1),inj.RConn(1),'autorouting','on');
add_line(sys,pre.LConn(1),psw.RConn(1),'autorouting','on');
add_line(sys,psw.RConn(2),rpre.LConn(1),'autorouting','on');
add_line(sys,rpre.RConn(1),sen.LConn(1),'autorouting','on');
add_line(sys,sen.LConn(1),cap.LConn(1),'autorouting','on');
add_line(sys,cap.LConn(1),inj.LConn(1),'autorouting','on');
add_line(sys,inj.LConn(1),bridge.RConn(1),'autorouting','on');
add_line(sys,pre.RConn(1),sen.RConn(2),'autorouting','on');
add_line(sys,sen.RConn(2),cap.RConn(1),'autorouting','on');
add_line(sys,cap.RConn(1),inj.RConn(2),'autorouting','on');
add_line(sys,inj.RConn(2),bridge.RConn(2),'autorouting','on');
add_line(sys,gnd.LConn(1),inj.RConn(2),'autorouting','on');
add_line(sys,solver.RConn(1),pre.RConn(1),'autorouting','on');
add_line(sys,pgate.RConn(1),psw.LConn(1),'autorouting','on');
gateConn=[gate.LConn gate.RConn];
routePhysicalLineDirect(gateConn(1),bridge.LConn(1));
routePhysicalLineDirect(meas.LConn(1),bridge.LConn(2));
routePhysicalLineDirect(sen.RConn(1),vdcConv.LConn(1));
wire(sys,'Vdc to Simulink/1','DC Control and Monitoring/1','Vdc_Meas');
wire(sys,'Pmsc/1','DC Control and Monitoring/2','P_msc_W');
wire(sys,'DC Control and Monitoring/1','MSC Current to Physical/1','I_msc_A');
wire(sys,'DC Control and Monitoring/2','Sampled Vdc Monitor/1','Vdc_msc_sampled');
wire(sys,'DC Control and Monitoring/3','Brake Current Monitor/1','brake_current_A');
wire(sys,'Precharge Open Command/1','Precharge Gate to Physical/1','precharge_gate');
note(sys,[55 590 1160 650],sprintf([ ...
    'Physical path: precharge branch -> DC rail (Cdc, Vdc sensor and MSC current injection) -> two-level bridge -> AC measurement.\n' ...
    'The MSC injects I=Pmsc/Vdc; the 1500 V support contactor opens at 100 ms, after which Cdc carries the energy mismatch.']));
end

function buildDCControlAndMonitoring(sys)
inport(sys,'Vdc Measured',1,[20 170 50 190]);
inport(sys,'Pmsc',2,[20 55 50 75]);
outport(sys,'I_msc Command',1,[710 70 740 90]);
outport(sys,'Sampled Vdc',2,[190 170 220 190]);
outport(sys,'Brake Current',3,[575 315 605 335]);
add_block('simulink/Discrete/Unit Delay',[sys '/Sampled DC Voltage'], ...
    'Position',[100 160 140 190],'SampleTime','Control.Ts', ...
    'InitialCondition','Converter.Vdc_nom');
add_block('simulink/Signal Routing/Mux',[sys '/MSC Current Inputs'], ...
    'Position',[185 45 190 115],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[sys '/P over Vdc'], ...
    'Position',[230 60 365 100], ...
    'Expr','2*u(1)/(u(2)+Wind.dc_voltage_floor_V+abs(u(2)-Wind.dc_voltage_floor_V))');
add_block('simulink/Discontinuities/Saturation',[sys '/MSC DC Current Limit'], ...
    'Position',[405 60 525 100],'LowerLimit','0', ...
    'UpperLimit','Wind.dc_current_limit_A');
add_block('simulink/Math Operations/Gain',[sys '/Injection Sign'], ...
    'Position',[565 60 630 100],'Gain','1');
add_block('simulink/Discontinuities/Relay',[sys '/Brake Hysteresis'], ...
    'Position',[205 270 310 310],'OnSwitchValue','Wind.brake_on_V', ...
    'OffSwitchValue','Wind.brake_off_V','OnOutputValue','1','OffOutputValue','0');
add_block('simulink/Math Operations/Gain',[sys '/Vdc over Brake R'], ...
    'Position',[205 335 310 365],'Gain','1/Wind.brake_R_ohm');
add_block('simulink/Math Operations/Product',[sys '/Brake Current Estimate'], ...
    'Position',[365 295 410 330]);
add_block('simulink/Signal Routing/Goto',[sys '/Vdc Measurement to GFL'], ...
    'Position',[100 215 215 245],'GotoTag','Vdc_Meas', ...
    'TagVisibility','global');
wire(sys,'Pmsc/1','MSC Current Inputs/1','');
wire(sys,'Vdc Measured/1','Sampled DC Voltage/1','');
hVdcTag=wire(sys,'Vdc Measured/1','Vdc Measurement to GFL/1','');
hSampleMux=wire(sys,'Sampled DC Voltage/1','MSC Current Inputs/2','');
wire(sys,'Sampled DC Voltage/1','Sampled Vdc/1','');
delayPorts=get_param([sys '/Sampled DC Voltage'],'PortHandles');
muxPorts=get_param([sys '/MSC Current Inputs'],'PortHandles');
sampleSrc=get_param(delayPorts.Outport(1),'Position');
sampleDst=get_param(muxPorts.Inport(2),'Position');
set_param(hSampleMux,'Points',[sampleSrc;160 sampleSrc(2);160 130; ...
    sampleDst(1)-20 130;sampleDst(1)-20 sampleDst(2);sampleDst]);
wire(sys,'MSC Current Inputs/1','P over Vdc/1','');
wire(sys,'P over Vdc/1','MSC DC Current Limit/1','');
wire(sys,'MSC DC Current Limit/1','Injection Sign/1','');
wire(sys,'Injection Sign/1','I_msc Command/1','');
wire(sys,'Vdc Measured/1','Brake Hysteresis/1','');
wire(sys,'Vdc Measured/1','Vdc over Brake R/1','');
wire(sys,'Brake Hysteresis/1','Brake Current Estimate/1','');
wire(sys,'Vdc over Brake R/1','Brake Current Estimate/2','');
wire(sys,'Brake Current Estimate/1','Brake Current/1','');
note(sys,[80 410 690 450], ...
    'MSC current command plus two explicit monitor outputs: sampled Vdc and estimated brake current.');
end

function exposeConverterMeasurements(vsc)
meas=[vsc '/Converter AC Measurement'];
replaceTerminatorWithGoto(meas,'Vabc Internal Monitor','Vabc_Converter_Meas');
replaceTerminatorWithGoto(meas,'Iabc Internal Monitor','Iabc_Converter_Meas');
end

function buildClosedLoopController(sys)
anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
% Remove inherited top-level Simulink signal lines through ordinary Outports.
% Do not scan generic line source handles: Simscape conserving connections
% also have valid handles and the gate physical network must remain intact.
blocks=find_system(sys,'SearchDepth',1,'Type','Block');
signalLines=[];
for k=2:numel(blocks)
    ports=get_param(blocks{k},'PortHandles');
    for port=ports.Outport(:).'
        line=get_param(port,'Line');
        if line>0,signalLines(end+1)=line;end %#ok<AGROW>
    end
end
if ~isempty(signalLines),delete_line(unique(signalLines));end

inport(sys,'Pmsc',1,[20 490 50 510]);
fromBlock(sys,'Converter Current abc','Iabc_Converter_Meas',[750 600 880 630]);
fromBlock(sys,'PCC Voltage for Outer Control','Vabc_PCC_Meas',[20 570 155 600]);
fromBlock(sys,'PCC Voltage for Current Control','Vabc_PCC_Meas',[750 565 880 595]);
fromBlock(sys,'DC-Link Voltage for Current Control','Vdc_Meas',[750 670 880 700]);
set_param([sys '/Converter Current abc'],'ShowName','off');
set_param([sys '/PCC Voltage for Outer Control'],'ShowName','off');
set_param([sys '/PCC Voltage for Current Control'],'ShowName','off');
set_param([sys '/DC-Link Voltage for Current Control'],'ShowName','off');
oldPwm=[sys '/05 Open-Loop Modulation and PWM'];
set_param(oldPwm,'Name','06 SPWM and Physical Gate Interface');
pwm=[sys '/06 SPWM and Physical Gate Interface'];
replaceOpenLoopReferenceWithInput(pwm);
buildFlattenedPWM(pwm);
internalizeControllerDiagnostics(sys);
set_param(pwm,'Position',[1240 455 1500 610]);

% Three visual bands: synchronization/measurement, the main control chain,
% and the nominal-angle baseline.  Boundary sources sit beside their first
% consumers so the generated diagram stays readable after every rebuild.
set_param([sys '/DC-Link Voltage'],'Position',[20 525 145 555]);
set_param([sys '/02 Synchronization SRF-PLL'],'Position',[190 50 380 145]);
set_param([sys '/01 Measurements and dq'],'Position',[190 190 380 300]);
set_param([sys '/Gate Drive'],'Position',[1530 515 1560 545], ...
    'Orientation','left');
pwmPorts=get_param(pwm,'PortHandles');
gatePorts=get_param([sys '/Gate Drive'],'PortHandles');
routePhysicalLineDirect(pwmPorts.RConn(1),gatePorts.RConn(1));

outer=[sys '/03 DC Voltage and Current Reference'];
limiter=[sys '/04 Circular Current Limiter'];
inner=[sys '/05 dq Current Controller'];
add_block('built-in/Subsystem',outer,'Position',[205 330 445 465], ...
    'BackgroundColor','[0.96,0.91,0.76]','ContentPreviewEnabled','off');
buildOuterReference(outer);
add_block('built-in/Subsystem',limiter,'Position',[505 330 705 465], ...
    'BackgroundColor','[1.00,0.82,0.65]','ContentPreviewEnabled','off');
buildCircularLimiter(limiter);
add_block('built-in/Subsystem',inner,'Position',[760 330 970 530], ...
    'BackgroundColor','[0.82,0.90,1.00]','ContentPreviewEnabled','off');
buildCurrentController(inner);
set_param(outer,'Position',[190 470 440 630]);
set_param(limiter,'Position',[520 485 730 620]);
set_param(inner,'Position',[900 490 1130 700]);
add_block('simulink/Math Operations/Bias',[sys '/PLL Angle Alignment'], ...
    'Position',[155 745 255 775],'Bias','0');
add_block('simulink/Sources/Constant',[sys '/Nominal Grid Omega'], ...
    'Position',[20 745 90 775],'Value','Control.GridAngle.Omega');
add_block('simulink/Continuous/Integrator',[sys '/Nominal Grid Angle'], ...
    'Position',[105 740 140 780], ...
    'InitialCondition','Control.GridAngle.Theta0');
add_block('simulink/Signal Routing/Goto',[sys '/Control Angle Distribution'], ...
    'Position',[280 745 400 775],'GotoTag','CONTROL_ANGLE', ...
    'TagVisibility','local','ShowName','off');
fromBlock(sys,'Control Angle for Outer','CONTROL_ANGLE',[20 605 155 635]);
fromBlock(sys,'Control Angle for Inner','CONTROL_ANGLE',[750 635 880 665]);
set_param([sys '/Control Angle for Outer'],'ShowName','off');
set_param([sys '/Control Angle for Inner'],'ShowName','off');

wire(sys,'Pmsc/1','03 DC Voltage and Current Reference/1','P_msc_W');
wire(sys,'DC-Link Voltage/1','03 DC Voltage and Current Reference/2','Vdc_Meas');
wire(sys,'PCC Voltage for Outer Control/1','03 DC Voltage and Current Reference/3','');
wire(sys,'Nominal Grid Omega/1','Nominal Grid Angle/1','');
wire(sys,'Nominal Grid Angle/1','PLL Angle Alignment/1','theta_nominal');
wire(sys,'PLL Angle Alignment/1','Control Angle Distribution/1','theta_control');
wire(sys,'Control Angle for Outer/1','03 DC Voltage and Current Reference/4','');
wire(sys,'03 DC Voltage and Current Reference/1','04 Circular Current Limiter/1','Id_cmd_raw');
wire(sys,'03 DC Voltage and Current Reference/2','04 Circular Current Limiter/2','Iq_cmd_raw');
wire(sys,'04 Circular Current Limiter/1','05 dq Current Controller/1','Id_ref_lim');
wire(sys,'04 Circular Current Limiter/2','05 dq Current Controller/2','Iq_ref_lim');
wire(sys,'PCC Voltage for Current Control/1','05 dq Current Controller/3','');
wire(sys,'Converter Current abc/1','05 dq Current Controller/4','');
wire(sys,'Control Angle for Inner/1','05 dq Current Controller/5','');
wire(sys,'DC-Link Voltage for Current Control/1','05 dq Current Controller/6','');
wire(sys,'05 dq Current Controller/1','06 SPWM and Physical Gate Interface/1','Vabc_mod');

add_block('simulink/Sinks/Terminator',[sys '/Id Monitor'],'Position',[1150 590 1170 610]);
add_block('simulink/Sinks/Terminator',[sys '/Iq Monitor'],'Position',[1150 660 1170 680]);
add_block('simulink/Sinks/Terminator',[sys '/Limit Active Monitor'],'Position',[650 635 670 655]);
wire(sys,'05 dq Current Controller/2','Id Monitor/1','Id_converter');
wire(sys,'05 dq Current Controller/3','Iq Monitor/1','Iq_converter');
wire(sys,'04 Circular Current Limiter/3','Limit Active Monitor/1','CurrentLimitActive');
note(sys,[470 75 1170 155], ...
    ['PCC voltage/current enter 01 and 02 internally from module 05 measurement tags. ' ...
     'Diagnostic dq, P/Q and PLL states are terminated and logged inside their owning modules.']);
note(sys,[1000 180 1550 235], ...
    'The active controller uses the known 50 Hz ideal-grid angle; the internal SRF-PLL remains logged for later reconnection.');
end

function buildOuterReference(sys)
inport(sys,'Pmsc',1,[20 45 50 65]);
inport(sys,'Vdc',2,[20 115 50 135]);
inport(sys,'Vabc PCC',3,[20 240 50 260]);
inport(sys,'theta',4,[20 325 50 345]);
outport(sys,'Id raw',1,[720 100 750 120]);
outport(sys,'Iq raw',2,[720 305 750 325]);
add_block('simulink/Math Operations/Gain',[sys '/Refer PCC Voltage to 690 V'], ...
    'Position',[85 225 225 265], ...
    'Gain','Base.Vll_lv/Base.Vll_hv');
add_block('simulink/Math Operations/Gain',[sys '/Clarke Voltage'], ...
    'Position',[270 220 385 270], ...
    'Gain','sqrt(2/3)*[1 -0.5 -0.5;0 sqrt(3)/2 -sqrt(3)/2]''', ...
    'Multiplication','Matrix(u*K)');
add_block('built-in/Subsystem',[sys '/Park Voltage'], ...
    'Position',[430 205 560 280],'ContentPreviewEnabled','off');
buildAlphaBetaToDQ([sys '/Park Voltage']);
add_block('simulink/Signal Routing/Demux',[sys '/Separate Vdq'], ...
    'Position',[600 205 605 280],'Outputs','2');
add_block('simulink/Signal Routing/Mux',[sys '/P over Vd inputs'], ...
    'Position',[420 30 425 100],'Inputs','2','ShowName','off');
add_block('simulink/User-Defined Functions/Fcn',[sys '/P over Vd Feedforward'], ...
    'Position',[465 45 595 85], ...
    'Expr','2*u(1)/(abs(u(2))+100+abs(abs(u(2))-100))');
add_block('simulink/Sources/Constant',[sys '/Vdc Reference'], ...
    'Position',[90 90 195 120],'Value','Converter.Vdc_nom');
add_block('simulink/Math Operations/Sum',[sys '/Vdc Error'], ...
    'Position',[240 95 275 145],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[sys '/Vdc Kp'], ...
    'Position',[315 85 385 115],'Gain','Control.Vdc.Kp');
add_block('simulink/Math Operations/Gain',[sys '/Vdc Ki'], ...
    'Position',[315 140 385 170],'Gain','Control.Vdc.Ki');
add_block('simulink/Continuous/Integrator',[sys '/Vdc Integral'], ...
    'Position',[420 135 455 175]);
add_block('simulink/Discontinuities/Saturation',[sys '/Vdc Integral Limit'], ...
    'Position',[485 135 600 175], ...
    'LowerLimit','-Control.Vdc.IntegratorLimit', ...
    'UpperLimit','Control.Vdc.IntegratorLimit');
add_block('simulink/Math Operations/Sum',[sys '/Id Raw Sum'], ...
    'Position',[650 75 685 135],'Inputs','+++');
add_block('simulink/Sources/Constant',[sys '/Iq Zero'], ...
    'Position',[610 300 670 330],'Value','0');
wire(sys,'Vabc PCC/1','Refer PCC Voltage to 690 V/1','');
wire(sys,'Refer PCC Voltage to 690 V/1','Clarke Voltage/1','');
wire(sys,'Clarke Voltage/1','Park Voltage/1','');
wire(sys,'theta/1','Park Voltage/2','');
wire(sys,'Park Voltage/1','Separate Vdq/1','');
wire(sys,'Pmsc/1','P over Vd inputs/1','');
wire(sys,'Separate Vdq/1','P over Vd inputs/2','Vd_grid_lv');
wire(sys,'P over Vd inputs/1','P over Vd Feedforward/1','');
wire(sys,'Vdc/1','Vdc Error/1','');
wire(sys,'Vdc Reference/1','Vdc Error/2','');
wire(sys,'Vdc Error/1','Vdc Kp/1','');
wire(sys,'Vdc Error/1','Vdc Ki/1','');
wire(sys,'Vdc Ki/1','Vdc Integral/1','');
wire(sys,'Vdc Integral/1','Vdc Integral Limit/1','');
wire(sys,'P over Vd Feedforward/1','Id Raw Sum/1','');
wire(sys,'Vdc Kp/1','Id Raw Sum/2','');
wire(sys,'Vdc Integral Limit/1','Id Raw Sum/3','');
wire(sys,'Id Raw Sum/1','Id raw/1','');
wire(sys,'Iq Zero/1','Iq raw/1','');
note(sys,[80 345 680 385], ...
    'Sensor current is positive converter-to-grid: Id*=Pmsc/Vd+PI(Vdc-Vdc*); Iq*=0 for unity-power-factor export.');
end

function buildCircularLimiter(sys)
inport(sys,'Id raw',1,[20 80 50 100]);
inport(sys,'Iq raw',2,[20 220 50 240]);
outport(sys,'Id limited',1,[690 80 720 100]);
outport(sys,'Iq limited',2,[690 220 720 240]);
outport(sys,'Limit active',3,[690 310 720 330]);
add_block('simulink/Math Operations/Product',[sys '/Id squared'], ...
    'Position',[100 65 145 105],'Inputs','2');
add_block('simulink/Math Operations/Product',[sys '/Iq squared'], ...
    'Position',[100 205 145 245],'Inputs','2');
add_block('simulink/Math Operations/Sum',[sys '/Magnitude squared'], ...
    'Position',[190 120 225 175],'Inputs','++');
add_block('simulink/Math Operations/Sqrt',[sys '/Magnitude'], ...
    'Position',[270 125 315 170]);
add_block('simulink/User-Defined Functions/Fcn',[sys '/Scale factor'], ...
    'Position',[360 125 485 165], ...
    'Expr',['0.5*(1+2*Converter.IdqMax/(u+1e-6+abs(u-1e-6))-' ...
    'abs(1-2*Converter.IdqMax/(u+1e-6+abs(u-1e-6))))']);
add_block('simulink/Math Operations/Product',[sys '/Limit Id'], ...
    'Position',[590 70 635 110]);
add_block('simulink/Math Operations/Product',[sys '/Limit Iq'], ...
    'Position',[590 210 635 250]);
add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
    [sys '/Limiter Active'],'Position',[565 300 645 340], ...
    'const','0.999999','relop','<');
add_block('simulink/Signal Routing/Goto',[sys '/Id Raw Distribution'], ...
    'Position',[165 20 265 45],'GotoTag','ID_RAW_LOCAL', ...
    'TagVisibility','local','ShowName','off');
add_block('simulink/Signal Routing/From',[sys '/Id Raw at Limiter'], ...
    'Position',[500 70 570 95],'GotoTag','ID_RAW_LOCAL','ShowName','off');
add_block('simulink/Signal Routing/Goto',[sys '/Iq Raw Distribution'], ...
    'Position',[165 270 265 295],'GotoTag','IQ_RAW_LOCAL', ...
    'TagVisibility','local','ShowName','off');
add_block('simulink/Signal Routing/From',[sys '/Iq Raw at Limiter'], ...
    'Position',[500 225 570 250],'GotoTag','IQ_RAW_LOCAL','ShowName','off');
wire(sys,'Id raw/1','Id squared/1','');wire(sys,'Id raw/1','Id squared/2','');
wire(sys,'Id raw/1','Id Raw Distribution/1','');
wire(sys,'Iq raw/1','Iq squared/1','');wire(sys,'Iq raw/1','Iq squared/2','');
wire(sys,'Iq raw/1','Iq Raw Distribution/1','');
wire(sys,'Id squared/1','Magnitude squared/1','');
wire(sys,'Iq squared/1','Magnitude squared/2','');
wire(sys,'Magnitude squared/1','Magnitude/1','');
wire(sys,'Magnitude/1','Scale factor/1','CurrentUtilization');
wire(sys,'Id Raw at Limiter/1','Limit Id/1','');wire(sys,'Scale factor/1','Limit Id/2','');
wire(sys,'Iq Raw at Limiter/1','Limit Iq/1','');wire(sys,'Scale factor/1','Limit Iq/2','');
wire(sys,'Limit Id/1','Id limited/1','');wire(sys,'Limit Iq/1','Iq limited/1','');
wire(sys,'Scale factor/1','Limiter Active/1','');
wire(sys,'Limiter Active/1','Limit active/1','');
note(sys,[80 375 650 415], ...
    'Circular physical limit preserves dq direction: [Id,Iq]_lim=min(1,Imax/|I*|)[Id,Iq].');
end

function buildCurrentController(sys)
inport(sys,'Id ref',1,[370 250 400 270]);
inport(sys,'Iq ref',2,[370 350 400 370]);
inport(sys,'Vabc PCC',3,[20 70 50 90]);
inport(sys,'Iabc converter',4,[20 470 50 490]);
inport(sys,'theta',5,[20 560 50 580]);
inport(sys,'Vdc',6,[1180 350 1210 370]);
outport(sys,'Vabc mod',1,[1460 285 1490 305]);
outport(sys,'Id',2,[470 455 500 475]);
outport(sys,'Iq',3,[470 495 500 515]);
K='sqrt(2/3)*[1 -0.5 -0.5;0 sqrt(3)/2 -sqrt(3)/2]''';
add_block('simulink/Math Operations/Gain',[sys '/Refer PCC Voltage to 690 V'], ...
    'Position',[90 50 225 95], ...
    'Gain','Base.Vll_lv/Base.Vll_hv');
add_block('simulink/Math Operations/Gain',[sys '/Clarke Voltage'], ...
    'Position',[265 50 370 100],'Gain',K,'Multiplication','Matrix(u*K)');
add_block('simulink/Math Operations/Gain',[sys '/Clarke Current'], ...
    'Position',[90 450 225 500],'Gain',K,'Multiplication','Matrix(u*K)');
add_block('built-in/Subsystem',[sys '/Park Voltage'], ...
    'Position',[410 35 535 115],'ContentPreviewEnabled','off');
buildAlphaBetaToDQ([sys '/Park Voltage']);
add_block('built-in/Subsystem',[sys '/Park Current'], ...
    'Position',[265 440 390 520],'ContentPreviewEnabled','off');
buildAlphaBetaToDQ([sys '/Park Current']);
add_block('simulink/Signal Routing/Demux',[sys '/Separate Vdq'], ...
    'Position',[575 35 580 115],'Outputs','2');
add_block('simulink/Signal Routing/Demux',[sys '/Separate Idq'], ...
    'Position',[430 440 435 520],'Outputs','2');
add_block('simulink/Math Operations/Sum',[sys '/Id Error'], ...
    'Position',[450 245 490 305],'Inputs','+-','IconShape','rectangular');
add_block('simulink/Math Operations/Sum',[sys '/Iq Error'], ...
    'Position',[450 345 490 405],'Inputs','+-','IconShape','rectangular');
for ax={'d','q'}
    a=ax{1};y=245+100*strcmp(a,'q');
    add_block('simulink/Math Operations/Gain',[sys '/Kp ' a], ...
        'Position',[520 y 580 y+30],'Gain','Control.Current.Kp');
    add_block('simulink/Math Operations/Gain',[sys '/Ki ' a], ...
        'Position',[520 y+40 580 y+70],'Gain','Control.Current.Ki');
    add_block('simulink/Continuous/Integrator',[sys '/Integral ' a], ...
        'Position',[620 y+40 655 y+75]);
    add_block('simulink/Discontinuities/Saturation',[sys '/Integral Limit ' a], ...
        'Position',[670 y+40 710 y+75], ...
        'LowerLimit','-Control.Current.IntegratorLimitV', ...
        'UpperLimit','Control.Current.IntegratorLimitV');
    add_block('simulink/Math Operations/Sum',[sys '/PI ' a], ...
        'Position',[740 y 780 y+80],'Inputs','++', ...
        'IconShape','rectangular');
end
add_block('simulink/Math Operations/Gain',[sys '/omega L Iq'], ...
    'Position',[600 610 700 640],'Gain','Base.omega*Filter.L');
add_block('simulink/Math Operations/Gain',[sys '/omega L Id'], ...
    'Position',[600 560 700 590],'Gain','Base.omega*Filter.L');
add_block('simulink/Math Operations/Sum',[sys '/Vd Command'], ...
    'Position',[940 245 975 320],'Inputs','++-');
add_block('simulink/Math Operations/Sum',[sys '/Vq Command'], ...
    'Position',[940 345 980 425],'Inputs','+++', ...
    'IconShape','rectangular');
add_block('simulink/Signal Routing/Mux',[sys '/Vdq Command'], ...
    'Position',[1005 250 1010 420],'Inputs','2');
add_block('built-in/Subsystem',[sys '/Inverse Park and Clarke'], ...
    'Position',[1040 260 1150 390],'ContentPreviewEnabled','off');
buildDQToABC([sys '/Inverse Park and Clarke']);
add_block('simulink/Math Operations/Gain',[sys '/Two times Vabc'], ...
    'Position',[1170 275 1260 315],'Gain','2');
add_block('simulink/Math Operations/Divide',[sys '/Normalize by Vdc'], ...
    'Position',[1290 275 1330 325],'Inputs','*/');
add_block('simulink/Discontinuities/Saturation',[sys '/Modulation Limit'], ...
    'Position',[1360 275 1440 315], ...
    'LowerLimit','-Converter.ModulationMax','UpperLimit','Converter.ModulationMax');
add_block('simulink/Signal Routing/Goto',[sys '/Theta Distribution'], ...
    'Position',[90 595 205 625],'GotoTag','THETA_INNER', ...
    'TagVisibility','local','ShowName','off');
add_block('simulink/Signal Routing/From',[sys '/Theta at Park Voltage'], ...
    'Position',[300 115 400 140],'GotoTag','THETA_INNER','ShowName','off');
add_block('simulink/Signal Routing/From',[sys '/Theta at Park Current'], ...
    'Position',[150 525 255 550],'GotoTag','THETA_INNER','ShowName','off');
add_block('simulink/Signal Routing/From',[sys '/Theta at Inverse Transform'], ...
    'Position',[1030 535 1140 560],'GotoTag','THETA_INNER','ShowName','off');
wire(sys,'Vabc PCC/1','Refer PCC Voltage to 690 V/1','');
wire(sys,'Refer PCC Voltage to 690 V/1','Clarke Voltage/1','');
wire(sys,'Clarke Voltage/1','Park Voltage/1','');
wire(sys,'Theta at Park Voltage/1','Park Voltage/2','');
wire(sys,'Park Voltage/1','Separate Vdq/1','');
wire(sys,'Iabc converter/1','Clarke Current/1','');
wire(sys,'Clarke Current/1','Park Current/1','');
wire(sys,'Theta at Park Current/1','Park Current/2','');
wire(sys,'Park Current/1','Separate Idq/1','');
wire(sys,'Id ref/1','Id Error/1','');wire(sys,'Separate Idq/1','Id Error/2','');
wire(sys,'Iq ref/1','Iq Error/1','');wire(sys,'Separate Idq/2','Iq Error/2','');
wire(sys,'Id Error/1','Kp d/1','');wire(sys,'Id Error/1','Ki d/1','');
wire(sys,'Ki d/1','Integral d/1','');wire(sys,'Kp d/1','PI d/1','');
wire(sys,'Integral d/1','Integral Limit d/1','');
wire(sys,'Integral Limit d/1','PI d/2','');
wire(sys,'Iq Error/1','Kp q/1','');wire(sys,'Iq Error/1','Ki q/1','');
wire(sys,'Ki q/1','Integral q/1','');wire(sys,'Kp q/1','PI q/1','');
wire(sys,'Integral q/1','Integral Limit q/1','');
wire(sys,'Integral Limit q/1','PI q/2','');
wire(sys,'Separate Idq/1','omega L Id/1','');
wire(sys,'Separate Idq/2','omega L Iq/1','');
wire(sys,'Separate Vdq/1','Vd Command/1','Vd_pcc_lv');wire(sys,'PI d/1','Vd Command/2','');
hIqDecouple=wire(sys,'omega L Iq/1','Vd Command/3','');
wire(sys,'Separate Vdq/2','Vq Command/1','Vq_pcc_lv');wire(sys,'PI q/1','Vq Command/2','');
hIdDecouple=wire(sys,'omega L Id/1','Vq Command/3','');
% Correct cross-coupling is inherently reversed between the ordered Id/Iq
% sources and Vd/Vq destinations. Keep both wires local and give them clearly
% separated vertical lanes. They cross once without a junction; this is much
% easier to read than two nearly coincident lines routed around the full area.
idGain=get_param([sys '/omega L Id'],'PortHandles');
iqGain=get_param([sys '/omega L Iq'],'PortHandles');
vdSum=get_param([sys '/Vd Command'],'PortHandles');
vqSum=get_param([sys '/Vq Command'],'PortHandles');
idSrc=get_param(idGain.Outport(1),'Position');
iqSrc=get_param(iqGain.Outport(1),'Position');
vdDst=get_param(vdSum.Inport(3),'Position');
vqDst=get_param(vqSum.Inport(3),'Position');
set_param(hIdDecouple,'Points',[idSrc;800 idSrc(2); ...
    800 vqDst(2);vqDst]);
set_param(hIqDecouple,'Points',[iqSrc;850 iqSrc(2); ...
    850 vdDst(2);vdDst]);
wire(sys,'Vd Command/1','Vdq Command/1','Vd_ctrl');
wire(sys,'Vq Command/1','Vdq Command/2','Vq_ctrl');
wire(sys,'Vdq Command/1','Inverse Park and Clarke/1','');
wire(sys,'Theta at Inverse Transform/1','Inverse Park and Clarke/2','');
wire(sys,'theta/1','Theta Distribution/1','');
wire(sys,'Inverse Park and Clarke/1','Two times Vabc/1','');
wire(sys,'Two times Vabc/1','Normalize by Vdc/1','');
wire(sys,'Vdc/1','Normalize by Vdc/2','');
wire(sys,'Normalize by Vdc/1','Modulation Limit/1','');
wire(sys,'Modulation Limit/1','Vabc mod/1','');
wire(sys,'Separate Idq/1','Id/1','');wire(sys,'Separate Idq/2','Iq/1','');
note(sys,[170 690 1450 735], ...
    'For converter-to-grid sensor current: Vd*=Vgd+PI_d-omega*L*Iq; Vq*=Vgq+PI_q+omega*L*Id; mabc is limited to +/-0.95.');
end

function buildAlphaBetaToDQ(sys)
inport(sys,'alpha beta',1,[20 70 50 90]);inport(sys,'theta',2,[20 175 50 195]);
outport(sys,'dq',1,[500 105 530 125]);
add_block('simulink/Signal Routing/Demux',[sys '/Separate alpha beta'], ...
    'Position',[80 45 85 125],'Outputs','2');
add_block('simulink/Math Operations/Trigonometric Function',[sys '/cos theta'], ...
    'Position',[90 155 140 190],'Operator','cos');
add_block('simulink/Math Operations/Trigonometric Function',[sys '/sin theta'], ...
    'Position',[90 210 140 245],'Operator','sin');
names={'alpha cos','beta sin','alpha sin','beta cos'};
for k=1:4,y=25+50*k;add_block('simulink/Math Operations/Product',[sys '/' names{k}], ...
        'Position',[200 y 245 y+28]);end
add_block('simulink/Math Operations/Sum',[sys '/d'], ...
    'Position',[300 75 335 125],'Inputs','++');
add_block('simulink/Math Operations/Sum',[sys '/q'], ...
    'Position',[300 175 335 225],'Inputs','-+');
add_block('simulink/Signal Routing/Mux',[sys '/dq vector'], ...
    'Position',[415 75 420 225],'Inputs','2');
wire(sys,'alpha beta/1','Separate alpha beta/1','');
wire(sys,'theta/1','cos theta/1','');wire(sys,'theta/1','sin theta/1','');
wire(sys,'Separate alpha beta/1','alpha cos/1','');wire(sys,'cos theta/1','alpha cos/2','');
wire(sys,'Separate alpha beta/2','beta sin/1','');wire(sys,'sin theta/1','beta sin/2','');
wire(sys,'Separate alpha beta/1','alpha sin/1','');wire(sys,'sin theta/1','alpha sin/2','');
wire(sys,'Separate alpha beta/2','beta cos/1','');wire(sys,'cos theta/1','beta cos/2','');
wire(sys,'alpha cos/1','d/1','');wire(sys,'beta sin/1','d/2','');
wire(sys,'alpha sin/1','q/1','');wire(sys,'beta cos/1','q/2','');
wire(sys,'d/1','dq vector/1','');wire(sys,'q/1','dq vector/2','');
wire(sys,'dq vector/1','dq/1','');
end

function buildDQToABC(sys)
inport(sys,'dq',1,[20 70 50 90]);inport(sys,'theta',2,[20 175 50 195]);
outport(sys,'abc',1,[590 105 620 125]);
add_block('simulink/Signal Routing/Demux',[sys '/Separate dq'], ...
    'Position',[80 45 85 125],'Outputs','2');
add_block('simulink/Math Operations/Trigonometric Function',[sys '/cos theta'], ...
    'Position',[90 155 140 190],'Operator','cos');
add_block('simulink/Math Operations/Trigonometric Function',[sys '/sin theta'], ...
    'Position',[90 210 140 245],'Operator','sin');
names={'d cos','q sin','d sin','q cos'};
for k=1:4,y=25+50*k;add_block('simulink/Math Operations/Product',[sys '/' names{k}], ...
        'Position',[200 y 245 y+28]);end
add_block('simulink/Math Operations/Sum',[sys '/alpha'], ...
    'Position',[300 75 335 125],'Inputs','+-');
add_block('simulink/Math Operations/Sum',[sys '/beta'], ...
    'Position',[300 175 335 225],'Inputs','++');
add_block('simulink/Signal Routing/Mux',[sys '/alpha beta'], ...
    'Position',[395 75 400 225],'Inputs','2');
add_block('simulink/Math Operations/Gain',[sys '/Inverse Clarke'], ...
    'Position',[450 90 545 145], ...
    'Gain','sqrt(2/3)*[1 -0.5 -0.5;0 sqrt(3)/2 -sqrt(3)/2]', ...
    'Multiplication','Matrix(u*K)');
wire(sys,'dq/1','Separate dq/1','');
wire(sys,'theta/1','cos theta/1','');wire(sys,'theta/1','sin theta/1','');
wire(sys,'Separate dq/1','d cos/1','');wire(sys,'cos theta/1','d cos/2','');
wire(sys,'Separate dq/2','q sin/1','');wire(sys,'sin theta/1','q sin/2','');
wire(sys,'Separate dq/1','d sin/1','');wire(sys,'sin theta/1','d sin/2','');
wire(sys,'Separate dq/2','q cos/1','');wire(sys,'cos theta/1','q cos/2','');
wire(sys,'d cos/1','alpha/1','');wire(sys,'q sin/1','alpha/2','');
wire(sys,'d sin/1','beta/1','');wire(sys,'q cos/1','beta/2','');
wire(sys,'alpha/1','alpha beta/1','');wire(sys,'beta/1','alpha beta/2','');
wire(sys,'alpha beta/1','Inverse Clarke/1','');wire(sys,'Inverse Clarke/1','abc/1','');
end

function replaceOpenLoopReferenceWithInput(pwm)
old=[pwm '/Three-Phase Modulation Reference'];
p=get_param(old,'PortHandles');
for h=p.Outport(:).'
    ln=get_param(h,'Line');if ln>0,delete_line(ln);end
end
delete_block(old);
inport(pwm,'Vabc mod',1,[25 115 55 135]);
add_block('simulink/Discrete/Unit Delay',[pwm '/Digital PWM Delay'], ...
    'Position',[95 100 135 140],'SampleTime','Control.PWM.Ts', ...
    'InitialCondition','zeros(3,1)');
set_param([pwm '/Vabc Mod Internal Monitor'],'Position',[165 155 185 175]);
set_param([pwm '/Carrier Internal Monitor'],'Position',[265 315 285 335]);
set_param([pwm '/Vabc Mod Internal Monitor'],'ShowName','off');
set_param([pwm '/Carrier Internal Monitor'],'ShowName','off');
wire(pwm,'Vabc mod/1','Digital PWM Delay/1','');
wire(pwm,'Digital PWM Delay/1','Carrier Comparison PWM/1','Vabc_mod_delayed');
wire(pwm,'Vabc mod/1','Vabc Mod Internal Monitor/1','Vabc_mod');
routeNamedLineShortest(pwm,'Vabc_mod');
routeNamedLineShortest(pwm,'PWM_Carrier');
anns=find_system(pwm,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(pwm,[75 385 850 425], ...
    'Digital delay -> explicit 5 kHz carrier comparison -> [AH AL BH BL CH CL] physical gate interface.');
end

function buildFlattenedPWM(pwm)
% Expose the carrier comparisons and six physical gate conversions directly
% in this subsystem.  The two inherited wrapper subsystems add no semantic
% boundary and make the switching path harder to inspect.
carrier=[pwm '/Carrier Comparison PWM'];
iface=[pwm '/Six-Gate Physical Interface'];
convTemplate=[iface '/Gate 1 to Physical Signal'];
muxTemplate=[iface '/Six-Pulse Gate Multiplexer'];
gateY=[55 115 175 235 295 355];
for k=1:6
    add_block(convTemplate,[pwm sprintf('/Gate %d to Physical Signal',k)], ...
        'Position',[730 gateY(k) 830 gateY(k)+26]);
end
add_block(muxTemplate,[pwm '/Six-Pulse Gate Multiplexer'], ...
    'Position',[890 40 980 415]);
deleteBlockAndLines(carrier);
deleteBlockAndLines(iface);
deleteBlockAndLines([pwm '/Vabc Mod Internal Monitor']);
deleteBlockAndLines([pwm '/Carrier Internal Monitor']);

set_param([pwm '/Vabc mod'],'Position',[20 210 50 230]);
set_param([pwm '/Digital PWM Delay'],'Position',[80 195 120 235]);
set_param([pwm '/Triangular Carrier'],'Position',[60 475 225 525]);
set_param([pwm '/Gate Drive'],'Position',[1040 210 1070 240], ...
    'Orientation','left');
vabcIn=get_param([pwm '/Vabc mod'],'PortHandles');
vabcLine=get_param(vabcIn.Outport(1),'Line');
if vabcLine>0
    delayPorts=get_param([pwm '/Digital PWM Delay'],'PortHandles');
    a=get_param(vabcIn.Outport(1),'Position');
    b=get_param(delayPorts.Inport(1),'Position');
    set_param(vabcLine,'Name','Vabc_mod','Points',[a;b]);
end

add_block('simulink/Signal Routing/Demux',[pwm '/abc References'], ...
    'Position',[165 50 170 410],'Outputs','3');
add_block('simulink/Signal Routing/Goto',[pwm '/Carrier Distribution'], ...
    'Position',[255 485 365 515],'GotoTag','PWM_CARRIER', ...
    'TagVisibility','local','ShowName','off');
phases={'A','B','C'};phaseY=[55 185 315];gateOrder=cell(1,6);
for k=1:3
    a=phases{k};yy=phaseY(k);
    add_block('simulink/Signal Routing/From',[pwm '/Carrier ' a], ...
        'Position',[235 yy+45 315 yy+65],'GotoTag','PWM_CARRIER', ...
        'ShowName','off');
    add_block('simulink/Logic and Bit Operations/Relational Operator', ...
        [pwm '/Compare Phase ' a],'Position',[350 yy 400 yy+45], ...
        'Operator','>=');
    add_block('simulink/Logic and Bit Operations/Logical Operator', ...
        [pwm '/' a ' Low = NOT High'],'Position',[440 yy+55 495 yy+85], ...
        'Operator','NOT');
    add_block('simulink/Signal Attributes/Data Type Conversion', ...
        [pwm '/G' lower(a) 'H double'],'Position',[540 yy 630 yy+30], ...
        'OutDataTypeStr','double');
    add_block('simulink/Signal Attributes/Data Type Conversion', ...
        [pwm '/G' lower(a) 'L double'],'Position',[540 yy+55 630 yy+85], ...
        'OutDataTypeStr','double');
    wire(pwm,sprintf('abc References/%d',k),['Compare Phase ' a '/1'],['m_' lower(a)]);
    wire(pwm,['Carrier ' a '/1'],['Compare Phase ' a '/2'],'');
    wire(pwm,['Compare Phase ' a '/1'],['G' lower(a) 'H double/1'],['G' lower(a) 'H']);
    wire(pwm,['Compare Phase ' a '/1'],[a ' Low = NOT High/1'],'');
    wire(pwm,[a ' Low = NOT High/1'],['G' lower(a) 'L double/1'],['G' lower(a) 'L']);
    gateOrder{2*k-1}=['G' lower(a) 'H double'];
    gateOrder{2*k}=['G' lower(a) 'L double'];
end
wire(pwm,'Digital PWM Delay/1','abc References/1','Vabc_mod_delayed');
wire(pwm,'Triangular Carrier/1','Carrier Distribution/1','');
gateSignals={'Gate_AH','Gate_AL','Gate_BH','Gate_BL','Gate_CH','Gate_CL'};
for k=1:6
    wire(pwm,[gateOrder{k} '/1'], ...
        sprintf('Gate %d to Physical Signal/1',k),gateSignals{k});
end
physMux=get_param([pwm '/Six-Pulse Gate Multiplexer'],'PortHandles');
for k=1:6
    conv=get_param([pwm sprintf('/Gate %d to Physical Signal',k)],'PortHandles');
    add_line(pwm,conv.RConn(1),physMux.LConn(k),'autorouting','on');
end
gateOut=get_param([pwm '/Gate Drive'],'PortHandles');
add_line(pwm,physMux.RConn(1),gateOut.RConn(1),'autorouting','on');
anns=find_system(pwm,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(pwm,[170 580 1010 625], ...
    ['Digital delay -> three carrier comparisons -> six direct AH/AL/BH/BL/CH/CL ' ...
     'Simulink-PS conversions -> physical gate multiplexer.']);
end

function internalizeControllerDiagnostics(sys)
% Measurement inputs originate in the PCC and enter through model-wide tags.
% Diagnostic outputs stay visible to logs without consuming controller-level
% ports or requiring separate sink-only wrapper subsystems.
meas=[sys '/01 Measurements and dq'];
pll=[sys '/02 Synchronization SRF-PLL'];
replaceTopBlock(meas,'Vabc','simulink/Signal Routing/From');
set_param([meas '/Vabc'],'GotoTag','Vabc_PCC_Meas','ShowName','off');
replaceTopBlock(meas,'Iabc','simulink/Signal Routing/From');
set_param([meas '/Iabc'],'GotoTag','Iabc_PCC_Meas','ShowName','off');
replaceTopBlock(meas,'theta','simulink/Signal Routing/From');
set_param([meas '/theta'],'GotoTag','THETA_PLL_DIAG','ShowName','off');

replaceTopBlock(pll,'Vabc PCC','simulink/Signal Routing/From');
set_param([pll '/Vabc PCC'],'GotoTag','Vabc_PCC_Meas','ShowName','off');
replaceTopBlock(pll,'theta','simulink/Signal Routing/Goto');
set_param([pll '/theta'],'GotoTag','THETA_PLL_DIAG', ...
    'TagVisibility','global','ShowName','off');

internalSinks={meas,'Vdq','Vdq_PCC';meas,'Idq','Idq_PCC'; ...
    meas,'P','P_PCC';meas,'Q','Q_PCC';pll,'omega','omega_PLL'; ...
    pll,'Vd PLL','Vd_PLL';pll,'Vq PLL','Vq_PLL'};
for k=1:size(internalSinks,1)
    owner=internalSinks{k,1};name=internalSinks{k,2};sig=internalSinks{k,3};
    replaceTopBlock(owner,name,'simulink/Sinks/Terminator');
    set_param([owner '/' name],'Name',[name ' Internal Monitor'], ...
        'ShowName','off');
    sink=get_param([owner '/' name ' Internal Monitor'],'PortHandles');
    line=get_param(sink.Inport(1),'Line');
    if line>0
        set_param(line,'Name',sig);
        src=get_param(line,'SrcPortHandle');
        try
            set_param(src,'DataLogging','on','DataLoggingNameMode','Custom', ...
                'DataLoggingName',sig);
        catch
        end
    end
end
thetaGoto=get_param([pll '/theta'],'PortHandles');
thetaLine=get_param(thetaGoto.Inport(1),'Line');
if thetaLine>0
    set_param(thetaLine,'Name','theta_PLL');
    src=get_param(thetaLine,'SrcPortHandle');
    try
        set_param(src,'DataLogging','on','DataLoggingNameMode','Custom', ...
            'DataLoggingName','theta_PLL');
    catch
    end
end
for name={'PCC Voltage abc','PCC Current abc','PLL Diagnostics', ...
        'Measurement Diagnostics'}
    path=[sys '/' name{1}];
    if getSimulinkBlockHandle(path)>0,deleteBlockAndLines(path);end
end
end

function replaceTopBlock(sys,name,libraryBlock)
old=[sys '/' name];
assert(getSimulinkBlockHandle(old)>0,'Missing block to internalize: %s',old);
replaced=replace_block(sys,'SearchDepth',1,'Name',name,libraryBlock,'noprompt');
assert(~isempty(replaced),'Failed to replace block: %s',old);
end

function replaceTerminatorWithGoto(sys,termName,tag)
term=[sys '/' termName];if getSimulinkBlockHandle(term)<=0,return,end
p=get_param(term,'PortHandles');line=get_param(p.Inport,'Line');
src=get_param(line,'SrcPortHandle');pos=get_param(term,'Position');
delete_line(line);delete_block(term);
g=[sys '/' tag ' Tag'];
add_block('simulink/Signal Routing/Goto',g,'Position', ...
    [pos(1) pos(2) pos(1)+110 pos(2)+25], ...
    'GotoTag',tag,'TagVisibility','global');
gp=get_param(g,'PortHandles');lh=add_line(sys,src,gp.Inport(1),'autorouting','on');
set_param(lh,'Name',tag);
end

function deleteBlockAndLines(path)
p=get_param(path,'PortHandles');fields={'Inport','Outport','LConn','RConn'};lines=[];
for f=1:numel(fields)
    h=p.(fields{f});
    for k=1:numel(h)
        try
            ln=get_param(h(k),'Line');
            if ln>0,lines(end+1)=ln;end %#ok<AGROW>
        catch
        end
    end
end
if ~isempty(lines),delete_line(unique(lines));end
delete_block(path);
end

function disconnectPortLines(portHandles)
lines=[];
for k=1:numel(portHandles)
    try
        line=get_param(portHandles(k),'Line');
        if line>0,lines(end+1)=line;end %#ok<AGROW>
    catch
    end
end
for line=unique(lines)
    try,delete_line(line);catch,end
end
end

function routePhysicalLineDirect(portA,portB)
line=get_param(portA,'Line');
if isempty(line)||line<0,line=get_param(portB,'Line');end
assert(~isempty(line)&&line>0,'Physical connection is missing.');
a=get_param(portA,'Position');
b=get_param(portB,'Position');
set_param(line,'Points',[a;b]);
end

function renameBlock(parent,old,new)
p=[parent '/' old];assert(getSimulinkBlockHandle(p)>0,'Missing block: %s',p);
set_param(p,'Name',new);
end
function inport(s,n,p,pos),add_block('simulink/Ports & Subsystems/In1',[s '/' n],'Port',num2str(p),'Position',pos);end
function outport(s,n,p,pos),add_block('simulink/Ports & Subsystems/Out1',[s '/' n],'Port',num2str(p),'Position',pos);end
function fromBlock(s,n,tag,pos),add_block('simulink/Signal Routing/From',[s '/' n],'Position',pos,'GotoTag',tag);end
function h=wire(s,a,b,n),h=add_line(s,a,b,'autorouting','on');if ~isempty(n),set_param(h,'Name',n);end,end
function note(s,pos,t),a=Simulink.Annotation(s,t);a.Position=pos;a.FontSize=10;a.ForegroundColor='blue';end

function enableNamedSignalLogging(model,name)
lines=find_system(model,'FindAll','on','Type','line');
for k=1:numel(lines)
    if strcmp(get_param(lines(k),'Name'),name)
        src=get_param(lines(k),'SrcPortHandle');
        try
            set_param(src,'DataLogging','on','DataLoggingNameMode','Custom', ...
                'DataLoggingName',name);
            return
        catch
        end
    end
end
error('Named log signal not found or not loggable: %s',name);
end

function disableSubsystemPreviews(model)
b=find_system(model,'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem');
for k=1:numel(b),try,set_param(b{k},'ContentPreviewEnabled','off');catch,end,end
end

function moveSubsystemPortToSide(blockPath,identifier,side,order)
% Programmatically configure flexible subsystem-boundary port placement.
% The connector must be taken from the active specification; connector
% objects created by a separate factory instance are not accepted by it.
if nargin<4,order='last';end
block=getSimulinkBlockHandle(blockPath);
assert(block>0,'Missing subsystem for port placement: %s',blockPath);
spec=flexibleportplacement.specification.Factory.getSpecifiction(block);
sideNames={'LEFT','RIGHT','TOP','BOTTOM'};
connector=[];
for k=1:numel(sideNames)
    candidates=spec.SideData.(sideNames{k});
    for j=1:numel(candidates)
        if strcmp(candidates(j).Identifier,identifier)
            connector=candidates(j);
            break
        end
    end
    if ~isempty(connector),break,end
end
assert(~isempty(connector),'Port %s not found on %s',identifier,blockPath);
spec.moveConnectorToSide(connector,side);
if strcmp(order,'first')
    while true
        before=spec.SideData.(side);
        idx=find(arrayfun(@(x)strcmp(x.Identifier,identifier),before),1);
        if isempty(idx)||idx<=1,break,end
        spec.decreaseConnectorIndex(connector);
    end
end
spec.applySpec();
end

function routeNamedLineShortest(model,name)
lines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line','Name',name);
for k=1:numel(lines)
    src=get_param(lines(k),'SrcPortHandle');dst=get_param(lines(k),'DstPortHandle');
    if isempty(src)||src<0||isempty(dst),continue,end
    if numel(dst)>1,dst=dst(1);end
    a=get_param(src,'Position');b=get_param(dst,'Position');
    if a(2)==b(2)
        points=[a;b];
    else
        xm=round((a(1)+b(1))/2);
        points=[a;xm a(2);xm b(2);b];
    end
    set_param(lines(k),'Points',points);
end
end

function renderSystem(sys,file)
try
    open_system(sys);set_param(sys,'ZoomFactor','FitSystem');
    try,set_param(sys,'ScrollbarOffset',[0 0]);catch,end
    drawnow;
    print(['-s' sys],'-dpng','-r150',file);
catch ME
    warning('Render failed for %s: %s',sys,ME.message);
end
end
