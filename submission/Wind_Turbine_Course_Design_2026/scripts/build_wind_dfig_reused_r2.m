%BUILD_WIND_DFIG_REUSED_R2 Derive DFIG R2 from the accepted average plant.
% Reused verbatim: turbine aerodynamics/inertia, physical DC-link and average
% GSC, GFL controller, filter/transformer/PCC, and grid equivalent.  Only the
% PMSG/MSC block is replaced by a modular wound-rotor DFIG plus average RSC,
% and a stator-current injection interface is added at the existing 690 V bus.

scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
source=fullfile(root,'models','resources','Wind_DirectDrive_Average.slx');
model='Wind_DFIG_Reused_R2';modelFile=fullfile(root,'build',[model '.slx']);
assert(isfile(source),'Missing accepted average source: %s',source);
run(fullfile(root,'parameters','init_wind_dfig_reused_r2.m'));
if bdIsLoaded(model),close_system(model,0);end
copyfile(source,modelFile,'f');load_system(modelFile);
load_system('ee_lib');load_system('nesl_utility');

set_param(model,'PreLoadFcn','', ...
    'InitFcn',char("root=fileparts(fileparts(get_param(bdroot,'FileName'))); " + ...
    "run(fullfile(root,'parameters','init_wind_dfig_reused_r2.m'));"), ...
    'StopTime','DFIG.Simulation.StopTime','MaxStep','Base.Simulation.MaxStep', ...
    'Description',['DFIG R2 derived from Wind_DirectDrive_Average. Retains the ' ...
    'accepted physical DC/GSC/filter/transformer/PCC/grid chain and replaces ' ...
    'only PMSG/MSC with modular dq DFIG plus average RSC.']);

old=[model '/02 PMSG and MSC Average Model'];
assert(getSimulinkBlockHandle(old)>0,'Expected reused PMSG/MSC boundary is missing.');
delete_block(old);
dfig=[model '/02 DFIG and Average RSC'];
add_block('built-in/Subsystem',dfig,'Position',[430 70 735 240], ...
    'BackgroundColor','[0.96 0.86 0.55]','FontWeight','bold', ...
    'ContentPreviewEnabled','off');
buildDFIGAssembly(dfig);
moveSubsystemPortToSide(dfig,'Out1','LEFT','last');
moveSubsystemPortToSide(dfig,'Out3','RIGHT','first');
% Keep all ports on LEFT/RIGHT so Simulink renders horizontal port labels
% instead of rotated text that collides with the block frame.

iface=[model '/05 Filter Transformer and PCC'];
addStatorInjection(iface);

% Preserve the proven downstream hierarchy and place only the new machine
% above it.  Each semantic path receives its own routing band.
set_param([model '/01 Wind Turbine Aerodynamics'],'Position',[45 70 350 240]);
set_param(dfig,'Position',[430 70 735 240]);
set_param([model '/04 GFL Control'],'Position',[430 330 705 500]);
set_param([model '/03 DC Link and Average GSC'],'Position',[815 285 1090 455]);
set_param(iface,'Position',[1170 285 1455 455]);
set_param([model '/06 Grid Equivalent and Source'],'Position',[1535 285 1790 455]);

rewire(model,'01 Wind Turbine Aerodynamics/2','02 DFIG and Average RSC/1','omega_turbine_rad_s');
rewire(model,'02 DFIG and Average RSC/1','01 Wind Turbine Aerodynamics/1','T_e_turbine_Nm');
rewire(model,'02 DFIG and Average RSC/2','03 DC Link and Average GSC/1','P_rotor_to_dc_W');
rewire(model,'02 DFIG and Average RSC/2','04 GFL Control/1','');
rewire(model,'02 DFIG and Average RSC/3','05 Filter Transformer and PCC/1','Iabc_DFIG_stator_injection');

% Rebuild only affected signal routes. Existing physical GSC->filter->grid and
% controller->GSC connections remain exactly the accepted ones.
for n={'omega_turbine_rad_s','T_e_turbine_Nm','P_rotor_to_dc_W','Iabc_DFIG_stator_injection', ...
        'GateDrivePhysical','VSC_AC_Terminal','PCC_to_Grid'}
    routeNamedLineShortest(model,n{1});
end
routeRotorPowerTree(model);
routeStatorInjectionLine(model);
for n={'omega_turbine_rad_s','T_e_turbine_Nm','P_rotor_to_dc_W', ...
        'Iabc_DFIG_stator_injection','Vabc_PCC_Meas','Iabc_PCC_Meas', ...
        'Vdc_Meas','P_PCC','Q_PCC'}
    enableNamedSignalLogging(model,n{1});
end
disableSubsystemPreviews(model);

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(model,[45 535 1780 595],sprintf([ ...
    'DFIG R2 — REUSED ACCEPTED AVERAGE PLANT\n' ...
    'Upper band: reused turbine -> new geared DFIG/RSC -> stator injection at the reused 690 V transformer bus.\n' ...
    'Lower band: signed rotor slip power -> reused physical DC link + average GSC -> reused filter/transformer/PCC/grid.']));
note(model,[50 625 1780 675],[ ...
    'Only subsystem 02 and the local stator-current injection branch inside subsystem 05 are new. ' ...
    'Subsystems 01, 03, 04, 05 main path, and 06 retain the accepted implementation.']);

save_system(model,modelFile);set_param(model,'SimulationCommand','update');save_system(model,modelFile);
% Render only the 02 DFIG region to inspect layout and save tokens.
renderSystem(dfig,fullfile(root,'build','WIND_DFIG_R2_02_DFIG_RSC.png'));
renderSystem([dfig '/02 Wound-Rotor DFIG dq Plant'],fullfile(root,'build','WIND_DFIG_R2_02A_DFIG_Plant.png'));
renderSystem([dfig '/03 Rotor-Side Average Converter Control'],fullfile(root,'build','WIND_DFIG_R2_02B_RSC_Control.png'));
close_system(model,0);
fprintf('WIND_DFIG_REUSED_R2_BUILD_OK=1\nMODEL=%s\n',modelFile);

%% ========================================================================
%  02 DFIG AND AVERAGE RSC (5 Clean Modular Subsystems)
%  ========================================================================
function buildDFIGAssembly(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Turbine Rotor Speed'], ...
    'Port','1','Position',[35 130 65 150]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Turbine-Side Electromagnetic Torque'], ...
    'Port','1','Position',[35 235 65 255],'Orientation','left');
add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Power to DC Link'], ...
    'Port','2','Position',[1155 435 1185 455]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Stator Current Injection abc'], ...
    'Port','3','Position',[1155 80 1185 100]);

% 01 Gearbox and MPPT Torque
gbMppt=[sys '/01 Gearbox and MPPT Torque'];
add_block('built-in/Subsystem',gbMppt,'Position',[165 85 375 295], ...
    'BackgroundColor','[0.88 0.95 0.88]','ContentPreviewEnabled','off');
buildGearboxAndMPPT(gbMppt);
moveSubsystemPortToSide(gbMppt,'Out1','LEFT','last');
moveSubsystemPortToSide(gbMppt,'In2','RIGHT','last');

% 02 Wound-Rotor DFIG dq Plant
plant=[sys '/02 Wound-Rotor DFIG dq Plant'];
add_block('built-in/Subsystem',plant,'Position',[465 55 755 275], ...
    'BackgroundColor','[0.97 0.90 0.72]','ContentPreviewEnabled','off');
buildModularDFIGPlant(plant);
moveSubsystemPortToSide(plant,'Out3','LEFT','last');

% 03 Rotor-Side Average Converter Control
rsc=[sys '/03 Rotor-Side Average Converter Control'];
add_block('built-in/Subsystem',rsc,'Position',[465 385 755 585], ...
    'BackgroundColor','[0.96 0.86 0.55]','ContentPreviewEnabled','off');
buildModularRSC(rsc);

% 04 dq to abc Stator Injection
dqAbc=[sys '/04 dq to abc Stator Injection'];
add_block('built-in/Subsystem',dqAbc,'Position',[865 35 1095 145], ...
    'BackgroundColor','[0.85 0.93 0.98]','ContentPreviewEnabled','off');
buildDqToAbc(dqAbc);

% 05 Average RSC Slip Power
slipPwr=[sys '/05 Average RSC Slip Power'];
add_block('built-in/Subsystem',slipPwr,'Position',[865 385 1095 505], ...
    'BackgroundColor','[0.90 0.88 0.96]','ContentPreviewEnabled','off');
buildRotorSlipPower(slipPwr);

% Wire external ports
wire(sys,'Turbine Rotor Speed/1','01 Gearbox and MPPT Torque/1','');
wire(sys,'01 Gearbox and MPPT Torque/1','Turbine-Side Electromagnetic Torque/1','');
wire(sys,'02 Wound-Rotor DFIG dq Plant/1','04 dq to abc Stator Injection/1','');
wire(sys,'04 dq to abc Stator Injection/1','Stator Current Injection abc/1','');
wire(sys,'05 Average RSC Slip Power/1','Rotor Power to DC Link/1','');

% Inter-subsystem connections with dedicated orthogonal corridors
hWmPlant=wire(sys,'01 Gearbox and MPPT Torque/2','02 Wound-Rotor DFIG dq Plant/1','');
hWmCtrl=wire(sys,'01 Gearbox and MPPT Torque/2','03 Rotor-Side Average Converter Control/2','');
hTmCtrl=wire(sys,'01 Gearbox and MPPT Torque/3','03 Rotor-Side Average Converter Control/1','');
hTeBack=wire(sys,'02 Wound-Rotor DFIG dq Plant/3','01 Gearbox and MPPT Torque/2','');
hVrPlant=wire(sys,'03 Rotor-Side Average Converter Control/1','02 Wound-Rotor DFIG dq Plant/2','');
hVrPwr=wire(sys,'03 Rotor-Side Average Converter Control/1','05 Average RSC Slip Power/1','');
hIrCtrl=wire(sys,'02 Wound-Rotor DFIG dq Plant/2','03 Rotor-Side Average Converter Control/3','');
hIrPwr=wire(sys,'02 Wound-Rotor DFIG dq Plant/2','05 Average RSC Slip Power/2','');
hFluxCtrl=wire(sys,'02 Wound-Rotor DFIG dq Plant/4','03 Rotor-Side Average Converter Control/4','');

gbPorts=get_param(gbMppt,'PortHandles');
plantPorts=get_param(plant,'PortHandles');
ctrlPorts=get_param(rsc,'PortHandles');
pwrPorts=get_param(slipPwr,'PortHandles');

% 1. Generator speed w_m to Plant In1 and RSC In2
wmSrc=get_param(gbPorts.Outport(2),'Position');
wmPlantDst=get_param(plantPorts.Inport(1),'Position');
wmCtrlDst=get_param(ctrlPorts.Inport(2),'Position');
set_param(hWmPlant,'Points',[wmSrc;420 wmSrc(2);420 wmPlantDst(2);wmPlantDst]);
set_param(hWmCtrl,'Points',[wmSrc;420 wmSrc(2);420 wmCtrlDst(2);wmCtrlDst]);

% 2. MPPT torque command Tm* to RSC In1
tmSrc=get_param(gbPorts.Outport(3),'Position');
tmCtrlDst=get_param(ctrlPorts.Inport(1),'Position');
set_param(hTmCtrl,'Points',[tmSrc;400 tmSrc(2);400 tmCtrlDst(2);tmCtrlDst]);

% 3. Electromagnetic torque Te from Plant Out3 (LEFT) directly to Gearbox In2 (RIGHT)
teSrc=get_param(plantPorts.Outport(3),'Position');
teDst=get_param(gbPorts.Inport(2),'Position');
set_param(hTeBack,'Points',[teSrc;440 teSrc(2);440 teDst(2);teDst]);

% 4. Rotor voltage command Vrdq from RSC Out1 to Slip Power In1 and Plant In2 (corridor y=315)
vrSrc=get_param(ctrlPorts.Outport(1),'Position');
vrPwrDst=get_param(pwrPorts.Inport(1),'Position');
vrPlantDst=get_param(plantPorts.Inport(2),'Position');
set_param(hVrPwr,'Points',[vrSrc;805 vrSrc(2);805 vrPwrDst(2);vrPwrDst]);
set_param(hVrPlant,'Points',[vrSrc;805 vrSrc(2);805 315;435 315;435 vrPlantDst(2);vrPlantDst]);

% 5. Rotor current Irdq from Plant Out2 to Slip Power In2 and RSC In3 (corridor y=335)
irSrc=get_param(plantPorts.Outport(2),'Position');
irPwrDst=get_param(pwrPorts.Inport(2),'Position');
irCtrlDst=get_param(ctrlPorts.Inport(3),'Position');
set_param(hIrPwr,'Points',[irSrc;825 irSrc(2);825 irPwrDst(2);irPwrDst]);
set_param(hIrCtrl,'Points',[irSrc;825 irSrc(2);825 335;382 335;382 irCtrlDst(2);irCtrlDst]);

% 6. Rotor flux Psi_rdq from Plant Out4 to RSC In4 (corridor y=355)
flxSrc=get_param(plantPorts.Outport(4),'Position');
flxCtrlDst=get_param(ctrlPorts.Inport(4),'Position');
set_param(hFluxCtrl,'Points',[flxSrc;785 flxSrc(2);785 355;364 355;364 flxCtrlDst(2);flxCtrlDst]);

note(sys,[65 620 1120 665],[ ...
    'Modular DFIG & Average RSC Architecture: (01) Gearbox & MPPT Torque Interface, ' ...
    '(02) Wound-Rotor DFIG dq Plant, (03) Rotor-Side Average Converter Control, ' ...
    '(04) Stator dq-to-abc Current Injection, and (05) Average RSC Slip Power Interface.']);
end

%% ------------------------------------------------------------------------
%  01 Gearbox and MPPT Torque
%  ------------------------------------------------------------------------
function buildGearboxAndMPPT(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Turbine Rotor Speed rad_s'], ...
    'Port','1','Position',[35 75 65 95]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Generator Torque Te Nm'], ...
    'Port','2','Position',[35 235 65 255]);

add_block('simulink/Ports & Subsystems/Out1',[sys '/Turbine-Side Torque Nm'], ...
    'Port','1','Position',[435 235 465 255]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Generator Speed rad_s'], ...
    'Port','2','Position',[435 75 465 95]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/MPPT Torque Reference Nm'], ...
    'Port','3','Position',[435 155 465 175]);

add_block('simulink/Math Operations/Gain',[sys '/Gearbox Speed Ratio'], ...
    'Position',[185 65 310 105],'Gain','DFIG.Drive.gearRatio');
add_block('simulink/Math Operations/Math Function',[sys '/Turbine Speed Squared'], ...
    'Position',[145 145 205 185],'Operator','square');
add_block('simulink/Math Operations/Gain',[sys '/Optimal MPPT Torque Gain'], ...
    'Position',[255 145 385 185], ...
    'Gain','Wind.Kopt_Nm_per_rad_s2/(DFIG.Drive.gearRatio*DFIG.Wind.etaGear)');
add_block('simulink/Math Operations/Gain',[sys '/Torque Referred to Turbine'], ...
    'Position',[185 225 335 265], ...
    'Gain','DFIG.Drive.gearRatio*DFIG.Wind.etaGear');

wire(sys,'Turbine Rotor Speed rad_s/1','Gearbox Speed Ratio/1','');
wire(sys,'Gearbox Speed Ratio/1','Generator Speed rad_s/1','');
wire(sys,'Turbine Rotor Speed rad_s/1','Turbine Speed Squared/1','');
wire(sys,'Turbine Speed Squared/1','Optimal MPPT Torque Gain/1','');
wire(sys,'Optimal MPPT Torque Gain/1','MPPT Torque Reference Nm/1','');
wire(sys,'Generator Torque Te Nm/1','Torque Referred to Turbine/1','');
wire(sys,'Torque Referred to Turbine/1','Turbine-Side Torque Nm/1','');
end

%% ------------------------------------------------------------------------
%  02 Wound-Rotor DFIG dq Plant (4 Modular Subsystems)
%  ------------------------------------------------------------------------
function buildModularDFIGPlant(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Generator Mechanical Speed rad_s'], ...
    'Port','1','Position',[35 265 65 285]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Voltage dq V'], ...
    'Port','2','Position',[35 225 65 245]);

add_block('simulink/Ports & Subsystems/Out1',[sys '/Stator Current dq A'], ...
    'Port','1','Position',[1055 116 1085 136]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Current dq A'], ...
    'Port','2','Position',[1055 168 1085 188]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Electromagnetic Torque Nm'], ...
    'Port','3','Position',[1055 245 1085 265]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Flux dq Wb'], ...
    'Port','4','Position',[1055 340 1085 360]);

sVolt=[sys '/01 Stator Voltage Equations'];
add_block('built-in/Subsystem',sVolt,'Position',[165 65 405 175], ...
    'BackgroundColor','[0.92 0.96 0.99]','ContentPreviewEnabled','off');
buildStatorVoltageEqs(sVolt);

rVolt=[sys '/02 Rotor Voltage Equations'];
add_block('built-in/Subsystem',rVolt,'Position',[165 215 405 375], ...
    'BackgroundColor','[0.98 0.93 0.84]','ContentPreviewEnabled','off');
buildRotorVoltageEqs(rVolt);

fluxMat=[sys '/03 Flux Integrator and Inductance Matrix'];
add_block('built-in/Subsystem',fluxMat,'Position',[485 100 745 310], ...
    'BackgroundColor','[0.90 0.96 0.90]','ContentPreviewEnabled','off');
buildFluxAndInductanceMatrix(fluxMat);

teSub=[sys '/04 Electromagnetic Torque'];
add_block('built-in/Subsystem',teSub,'Position',[825 205 1010 305], ...
    'BackgroundColor','[0.95 0.90 0.96]','ContentPreviewEnabled','off');
buildElectromagneticTorque(teSub);

% Forward connections
wire(sys,'Rotor Voltage dq V/1','02 Rotor Voltage Equations/1','');
wire(sys,'Generator Mechanical Speed rad_s/1','02 Rotor Voltage Equations/2','');
wire(sys,'01 Stator Voltage Equations/1','03 Flux Integrator and Inductance Matrix/1','');
wire(sys,'02 Rotor Voltage Equations/1','03 Flux Integrator and Inductance Matrix/2','');
wire(sys,'03 Flux Integrator and Inductance Matrix/1','Stator Current dq A/1','');
wire(sys,'03 Flux Integrator and Inductance Matrix/2','Rotor Current dq A/1','');
hPsirOut=wire(sys,'03 Flux Integrator and Inductance Matrix/4','Rotor Flux dq Wb/1','');
wire(sys,'03 Flux Integrator and Inductance Matrix/1','04 Electromagnetic Torque/1','');
wire(sys,'03 Flux Integrator and Inductance Matrix/3','04 Electromagnetic Torque/2','');
wire(sys,'04 Electromagnetic Torque/1','Electromagnetic Torque Nm/1','');

% Clean top & bottom feedback corridors (never crossing blocks or titles)
hIsFb=wire(sys,'03 Flux Integrator and Inductance Matrix/1','01 Stator Voltage Equations/1','');
hPsisFb=wire(sys,'03 Flux Integrator and Inductance Matrix/3','01 Stator Voltage Equations/2','');
hIrFb=wire(sys,'03 Flux Integrator and Inductance Matrix/2','02 Rotor Voltage Equations/3','');
hPsirFb=wire(sys,'03 Flux Integrator and Inductance Matrix/4','02 Rotor Voltage Equations/4','');

svPorts=get_param(sVolt,'PortHandles');
rvPorts=get_param(rVolt,'PortHandles');
fmPorts=get_param(fluxMat,'PortHandles');
psirOutPorts=get_param([sys '/Rotor Flux dq Wb'],'PortHandles');

isSrc=get_param(fmPorts.Outport(1),'Position');
isDst=get_param(svPorts.Inport(1),'Position');
set_param(hIsFb,'Points',[isSrc;775 isSrc(2);775 24;130 24;130 isDst(2);isDst]);

psisSrc=get_param(fmPorts.Outport(3),'Position');
psisDst=get_param(svPorts.Inport(2),'Position');
set_param(hPsisFb,'Points',[psisSrc;790 psisSrc(2);790 40;115 40;115 psisDst(2);psisDst]);

irSrc=get_param(fmPorts.Outport(2),'Position');
irDst=get_param(rvPorts.Inport(3),'Position');
set_param(hIrFb,'Points',[irSrc;775 irSrc(2);775 408;130 408;130 irDst(2);irDst]);

psirSrc=get_param(fmPorts.Outport(4),'Position');
psirOutDst=get_param(psirOutPorts.Inport(1),'Position');
psirDst=get_param(rvPorts.Inport(4),'Position');
set_param(hPsirOut,'Points',[psirSrc;805 psirSrc(2);805 psirOutDst(2);psirOutDst]);
pBranch=get_param(hPsirFb,'Points');xTap=pBranch(1,1);yTap=pBranch(1,2);
set_param(hPsirFb,'Points',[xTap yTap;xTap 424;115 424;115 psirDst(2);psirDst]);

note(sys,[65 465 1030 505],[ ...
    'Synchronous-Frame Wound-Rotor DFIG State Model: (01) Stator Flux ODEs, ' ...
    '(02) Slip-Frame Rotor Flux ODEs, (03) 4th-Order Flux Integrator & Inverse Inductance Matrix, ' ...
    'and (04) Air-Gap Electromagnetic Torque.']);
end

function buildStatorVoltageEqs(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Stator Current dq A'], ...
    'Port','1','Position',[30 105 60 125]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Stator Flux dq Wb'], ...
    'Port','2','Position',[30 215 60 235]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/dPsi_sdq_dt'], ...
    'Port','1','Position',[645 140 675 160]);

add_block('simulink/Sources/Constant',[sys '/Stator Grid Voltage dq'], ...
    'Position',[30 35 145 65],'Value','DFIG.Grid.Vdq');
add_block('simulink/Signal Routing/Demux',[sys '/Demux Vs'], ...
    'Position',[185 25 190 75],'Outputs','2','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Demux Is'], ...
    'Position',[185 90 190 140],'Outputs','2','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Demux Psis'], ...
    'Position',[185 200 190 250],'Outputs','2','ShowName','off');

add_block('simulink/Math Operations/Gain',[sys '/Rs ids'], ...
    'Position',[255 80 345 110],'Gain','DFIG.Machine.Rs');
add_block('simulink/Math Operations/Gain',[sys '/Rs iqs'], ...
    'Position',[255 125 345 155],'Gain','DFIG.Machine.Rs');
add_block('simulink/Math Operations/Gain',[sys '/ws psiqs'], ...
    'Position',[255 230 345 260],'Gain','DFIG.Base.ws');
add_block('simulink/Math Operations/Gain',[sys '/ws psids'], ...
    'Position',[255 185 345 215],'Gain','DFIG.Base.ws');

add_block('simulink/Math Operations/Sum',[sys '/d_psids_sum'], ...
    'Position',[445 65 485 135],'Inputs','+-+','IconShape','rectangular');
add_block('simulink/Math Operations/Sum',[sys '/d_psiqs_sum'], ...
    'Position',[445 170 485 240],'Inputs','+--','IconShape','rectangular');
add_block('simulink/Signal Routing/Mux',[sys '/Mux dPsi_s'], ...
    'Position',[565 100 570 200],'Inputs','2','ShowName','off');

wire(sys,'Stator Grid Voltage dq/1','Demux Vs/1','');
wire(sys,'Stator Current dq A/1','Demux Is/1','');
wire(sys,'Stator Flux dq Wb/1','Demux Psis/1','');
wire(sys,'Demux Is/1','Rs ids/1','');
wire(sys,'Demux Is/2','Rs iqs/1','');
wire(sys,'Demux Psis/1','ws psids/1','');
wire(sys,'Demux Psis/2','ws psiqs/1','');

wire(sys,'Demux Vs/1','d_psids_sum/1','');
wire(sys,'Rs ids/1','d_psids_sum/2','');
wire(sys,'ws psiqs/1','d_psids_sum/3','');

wire(sys,'Demux Vs/2','d_psiqs_sum/1','');
wire(sys,'Rs iqs/1','d_psiqs_sum/2','');
wire(sys,'ws psids/1','d_psiqs_sum/3','');

wire(sys,'d_psids_sum/1','Mux dPsi_s/1','');
wire(sys,'d_psiqs_sum/1','Mux dPsi_s/2','');
wire(sys,'Mux dPsi_s/1','dPsi_sdq_dt/1','');
end

function buildRotorVoltageEqs(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Voltage dq V'], ...
    'Port','1','Position',[30 45 60 65]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Generator Speed rad_s'], ...
    'Port','2','Position',[30 285 60 305]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Current dq A'], ...
    'Port','3','Position',[30 115 60 135]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Flux dq Wb'], ...
    'Port','4','Position',[30 200 60 220]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/dPsi_rdq_dt'], ...
    'Port','1','Position',[685 135 715 155]);

add_block('simulink/Signal Routing/Demux',[sys '/Demux Vr'], ...
    'Position',[155 30 160 80],'Outputs','2','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Demux Ir'], ...
    'Position',[155 100 160 150],'Outputs','2','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Demux Psir'], ...
    'Position',[155 185 160 235],'Outputs','2','ShowName','off');

add_block('simulink/Sources/Constant',[sys '/Synchronous Speed'], ...
    'Position',[95 245 195 275],'Value','DFIG.Base.ws');
add_block('simulink/Math Operations/Gain',[sys '/Pole Pairs'], ...
    'Position',[95 280 195 310],'Gain','DFIG.Machine.p');
add_block('simulink/Math Operations/Sum',[sys '/Slip Speed'], ...
    'Position',[235 255 270 305],'Inputs','+-','IconShape','rectangular');

add_block('simulink/Math Operations/Gain',[sys '/Rr idr'], ...
    'Position',[295 85 385 115],'Gain','DFIG.Machine.Rr');
add_block('simulink/Math Operations/Gain',[sys '/Rr iqr'], ...
    'Position',[295 130 385 160],'Gain','DFIG.Machine.Rr');
add_block('simulink/Math Operations/Product',[sys '/wSlip psiqr'], ...
    'Position',[315 225 370 260],'Inputs','**');
add_block('simulink/Math Operations/Product',[sys '/wSlip psidr'], ...
    'Position',[315 180 370 215],'Inputs','**');

add_block('simulink/Math Operations/Sum',[sys '/d_psidr_sum'], ...
    'Position',[475 65 515 135],'Inputs','+-+','IconShape','rectangular');
add_block('simulink/Math Operations/Sum',[sys '/d_psiqr_sum'], ...
    'Position',[475 170 515 240],'Inputs','+--','IconShape','rectangular');
add_block('simulink/Signal Routing/Mux',[sys '/Mux dPsi_r'], ...
    'Position',[595 95 600 195],'Inputs','2','ShowName','off');

wire(sys,'Rotor Voltage dq V/1','Demux Vr/1','');
wire(sys,'Rotor Current dq A/1','Demux Ir/1','');
wire(sys,'Rotor Flux dq Wb/1','Demux Psir/1','');
wire(sys,'Generator Speed rad_s/1','Pole Pairs/1','');
wire(sys,'Synchronous Speed/1','Slip Speed/1','');
wire(sys,'Pole Pairs/1','Slip Speed/2','');

wire(sys,'Demux Ir/1','Rr idr/1','');
wire(sys,'Demux Ir/2','Rr iqr/1','');
wire(sys,'Demux Psir/1','wSlip psidr/1','');
wire(sys,'Slip Speed/1','wSlip psidr/2','');
wire(sys,'Demux Psir/2','wSlip psiqr/1','');
wire(sys,'Slip Speed/1','wSlip psiqr/2','');

wire(sys,'Demux Vr/1','d_psidr_sum/1','');
wire(sys,'Rr idr/1','d_psidr_sum/2','');
wire(sys,'wSlip psiqr/1','d_psidr_sum/3','');

wire(sys,'Demux Vr/2','d_psiqr_sum/1','');
wire(sys,'Rr iqr/1','d_psiqr_sum/2','');
wire(sys,'wSlip psidr/1','d_psiqr_sum/3','');

wire(sys,'d_psidr_sum/1','Mux dPsi_r/1','');
wire(sys,'d_psiqr_sum/1','Mux dPsi_r/2','');
wire(sys,'Mux dPsi_r/1','dPsi_rdq_dt/1','');
end

function buildFluxAndInductanceMatrix(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/dPsi_sdq_dt'], ...
    'Port','1','Position',[35 100 65 120]);
add_block('simulink/Ports & Subsystems/In1',[sys '/dPsi_rdq_dt'], ...
    'Port','2','Position',[35 160 65 180]);

add_block('simulink/Ports & Subsystems/Out1',[sys '/Stator Current dq A'], ...
    'Port','1','Position',[645 75 675 95]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Current dq A'], ...
    'Port','2','Position',[645 125 675 145]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Stator Flux dq Wb'], ...
    'Port','3','Position',[645 195 675 215]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Flux dq Wb'], ...
    'Port','4','Position',[645 245 675 265]);

add_block('simulink/Signal Routing/Mux',[sys '/Mux State Derivative'], ...
    'Position',[135 85 140 195],'Inputs','2','ShowName','off');
add_block('simulink/Continuous/Integrator',[sys '/Flux State Integrator'], ...
    'Position',[205 115 265 165],'InitialCondition','DFIG.Initial.flux');
add_block('simulink/Math Operations/Gain',[sys '/Flux to Current Matrix'], ...
    'Position',[355 80 485 140],'Gain','DFIG.Machine.CurrentFromFlux', ...
    'Multiplication','Matrix(K*u)');
add_block('simulink/Signal Routing/Demux',[sys '/Split Stator Rotor Current'], ...
    'Position',[545 60 550 160],'Outputs','[2 2]','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Split Stator Rotor Flux'], ...
    'Position',[545 180 550 280],'Outputs','[2 2]','ShowName','off');

wire(sys,'dPsi_sdq_dt/1','Mux State Derivative/1','');
wire(sys,'dPsi_rdq_dt/1','Mux State Derivative/2','');
wire(sys,'Mux State Derivative/1','Flux State Integrator/1','');
wire(sys,'Flux State Integrator/1','Flux to Current Matrix/1','');
wire(sys,'Flux State Integrator/1','Split Stator Rotor Flux/1','');
wire(sys,'Flux to Current Matrix/1','Split Stator Rotor Current/1','');

wire(sys,'Split Stator Rotor Current/1','Stator Current dq A/1','');
wire(sys,'Split Stator Rotor Current/2','Rotor Current dq A/1','');
wire(sys,'Split Stator Rotor Flux/1','Stator Flux dq Wb/1','');
wire(sys,'Split Stator Rotor Flux/2','Rotor Flux dq Wb/1','');
end

function buildElectromagneticTorque(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Stator Current dq A'], ...
    'Port','1','Position',[35 70 65 90]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Stator Flux dq Wb'], ...
    'Port','2','Position',[35 160 65 180]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Electromagnetic Torque Nm'], ...
    'Port','1','Position',[565 115 595 135]);

add_block('simulink/Signal Routing/Demux',[sys '/Demux Is'], ...
    'Position',[125 55 130 105],'Outputs','2','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Demux Psis'], ...
    'Position',[125 145 130 195],'Outputs','2','ShowName','off');
add_block('simulink/Math Operations/Product',[sys '/psids iqs'], ...
    'Position',[235 65 290 105],'Inputs','**');
add_block('simulink/Math Operations/Product',[sys '/psiqs ids'], ...
    'Position',[235 140 290 180],'Inputs','**');
add_block('simulink/Math Operations/Sum',[sys '/Air-Gap Flux Cross Product'], ...
    'Position',[345 95 385 155],'Inputs','+-','IconShape','rectangular');
add_block('simulink/Math Operations/Gain',[sys '/Torque Constant 1.5p'], ...
    'Position',[425 105 520 145],'Gain','1.5*DFIG.Machine.p');

wire(sys,'Stator Current dq A/1','Demux Is/1','');
wire(sys,'Stator Flux dq Wb/1','Demux Psis/1','');
wire(sys,'Demux Psis/1','psids iqs/1','');
wire(sys,'Demux Is/2','psids iqs/2','');
wire(sys,'Demux Psis/2','psiqs ids/1','');
wire(sys,'Demux Is/1','psiqs ids/2','');
wire(sys,'psids iqs/1','Air-Gap Flux Cross Product/1','');
wire(sys,'psiqs ids/1','Air-Gap Flux Cross Product/2','');
wire(sys,'Air-Gap Flux Cross Product/1','Torque Constant 1.5p/1','');
wire(sys,'Torque Constant 1.5p/1','Electromagnetic Torque Nm/1','');
end

%% ------------------------------------------------------------------------
%  03 Rotor-Side Average Converter Control (4 Modular Subsystems)
%  Inspired by Simscape Renewable Energy Machine Converter Control:
%    01 Stator-Flux Current Reference
%    02 Circular Rotor Current Limiter
%    03 Slip and EMF Pre-Control
%    04 Dual-Axis PI and Bridge Limiter
%  ------------------------------------------------------------------------
function buildModularRSC(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Generator Torque Reference Nm'], ...
    'Port','1','Position',[30 105 60 125]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Generator Mechanical Speed rad_s'], ...
    'Port','2','Position',[30 315 60 335]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Current dq A'], ...
    'Port','3','Position',[30 220 60 240]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Flux dq Wb'], ...
    'Port','4','Position',[30 365 60 385]);

add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Voltage Command dq V'], ...
    'Port','1','Position',[1055 200 1085 220]);

refSub=[sys '/01 Stator-Flux Current Reference'];
add_block('built-in/Subsystem',refSub,'Position',[125 65 345 165], ...
    'BackgroundColor','[0.88 0.95 0.88]','ContentPreviewEnabled','off');
buildRSCCurrentReference(refSub);

limSub=[sys '/02 Circular Rotor Current Limiter'];
add_block('built-in/Subsystem',limSub,'Position',[415 65 645 165], ...
    'BackgroundColor','[0.98 0.93 0.82]','ContentPreviewEnabled','off');
buildRSCCircularLimiter(limSub);

preSub=[sys '/03 Slip and EMF Pre-Control'];
add_block('built-in/Subsystem',preSub,'Position',[415 245 645 400], ...
    'BackgroundColor','[0.88 0.93 0.98]','ContentPreviewEnabled','off');
buildRSCSlipPreControl(preSub);

piSub=[sys '/04 Dual-Axis PI and Bridge Limiter'];
add_block('built-in/Subsystem',piSub,'Position',[735 110 995 310], ...
    'BackgroundColor','[0.96 0.88 0.78]','ContentPreviewEnabled','off');
buildRSCDualPIController(piSub);

wire(sys,'Generator Torque Reference Nm/1','01 Stator-Flux Current Reference/1','');
wire(sys,'01 Stator-Flux Current Reference/1','02 Circular Rotor Current Limiter/1','');
wire(sys,'01 Stator-Flux Current Reference/2','02 Circular Rotor Current Limiter/2','');
wire(sys,'02 Circular Rotor Current Limiter/1','04 Dual-Axis PI and Bridge Limiter/1','');
wire(sys,'02 Circular Rotor Current Limiter/2','04 Dual-Axis PI and Bridge Limiter/2','');

hIrPi=wire(sys,'Rotor Current dq A/1','04 Dual-Axis PI and Bridge Limiter/3','');
hIrPre=wire(sys,'Rotor Current dq A/1','03 Slip and EMF Pre-Control/1','');
wire(sys,'Generator Mechanical Speed rad_s/1','03 Slip and EMF Pre-Control/2','');
wire(sys,'Rotor Flux dq Wb/1','03 Slip and EMF Pre-Control/3','');

wire(sys,'03 Slip and EMF Pre-Control/1','04 Dual-Axis PI and Bridge Limiter/4','');
wire(sys,'03 Slip and EMF Pre-Control/2','04 Dual-Axis PI and Bridge Limiter/5','');
wire(sys,'04 Dual-Axis PI and Bridge Limiter/1','Rotor Voltage Command dq V/1','');

% Keep Rotor Current dq branch orthogonal between Pre-Control and PI Controller
irPort=get_param([sys '/Rotor Current dq A'],'PortHandles');
prePorts=get_param(preSub,'PortHandles');
piPorts=get_param(piSub,'PortHandles');
irSrc=get_param(irPort.Outport(1),'Position');
preDst=get_param(prePorts.Inport(1),'Position');
piDst=get_param(piPorts.Inport(3),'Position');
set_param(hIrPi,'Points',[irSrc;370 irSrc(2);370 piDst(2);piDst]);
set_param(hIrPre,'Points',[irSrc;370 irSrc(2);370 preDst(2);preDst]);

note(sys,[65 430 1020 470],[ ...
    'Stator-Flux-Oriented RSC Controller (Simscape Renewable Energy Pattern): ' ...
    '(01) Torque/Magnetizing Current Reference, (02) Circular Current Magnitude Limiter, ' ...
    '(03) Slip Speed & EMF Decoupling Pre-Control, and (04) Dual-Axis PI Current Regulators with Bridge Saturation.']);
end

function buildRSCCurrentReference(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Torque Reference Nm'], ...
    'Port','1','Position',[35 135 65 155]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Idr_ref_raw_A'], ...
    'Port','1','Position',[365 55 395 75]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Iqr_ref_raw_A'], ...
    'Port','2','Position',[365 135 395 155]);

add_block('simulink/Sources/Constant',[sys '/Idr Magnetizing Reference'], ...
    'Position',[155 48 285 82],'Value','DFIG.RSC.idrRef');
add_block('simulink/Math Operations/Gain',[sys '/Torque to Iqr Gain'], ...
    'Position',[155 125 285 165],'Gain','DFIG.RSC.torqueToIqr');

wire(sys,'Idr Magnetizing Reference/1','Idr_ref_raw_A/1','');
wire(sys,'Torque Reference Nm/1','Torque to Iqr Gain/1','');
wire(sys,'Torque to Iqr Gain/1','Iqr_ref_raw_A/1','');
end

function buildRSCCircularLimiter(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Idr_ref_raw_A'], ...
    'Port','1','Position',[30 55 60 75]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Iqr_ref_raw_A'], ...
    'Port','2','Position',[30 225 60 245]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Idr_ref_lim_A'], ...
    'Port','1','Position',[795 70 825 90]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Iqr_ref_lim_A'], ...
    'Port','2','Position',[795 215 825 235]);

add_block('simulink/Math Operations/Math Function',[sys '/Idr Squared'], ...
    'Position',[125 95 175 130],'Operator','square');
add_block('simulink/Math Operations/Math Function',[sys '/Iqr Squared'], ...
    'Position',[125 160 175 195],'Operator','square');
add_block('simulink/Math Operations/Sum',[sys '/Magnitude Squared'], ...
    'Position',[215 115 250 175],'Inputs','++','IconShape','rectangular');
add_block('simulink/Math Operations/Sqrt',[sys '/Reference Magnitude'], ...
    'Position',[285 130 335 160]);
add_block('simulink/Sources/Constant',[sys '/Magnitude Floor'], ...
    'Position',[275 190 345 215],'Value','1');
add_block('simulink/Math Operations/MinMax',[sys '/Safe Magnitude'], ...
    'Position',[385 130 435 185],'Function','max','Inputs','2');
add_block('simulink/Sources/Constant',[sys '/Rotor Current Limit'], ...
    'Position',[365 75 455 105],'Value','DFIG.RSC.Imax');
add_block('simulink/Math Operations/Divide',[sys '/Limit Ratio'], ...
    'Position',[495 105 545 160]);
add_block('simulink/Sources/Constant',[sys '/Unity Scale'], ...
    'Position',[490 185 550 210],'Value','1');
add_block('simulink/Math Operations/MinMax',[sys '/Circular Limit Scale'], ...
    'Position',[590 120 645 180],'Function','min','Inputs','2');
add_block('simulink/Math Operations/Product',[sys '/Idr Limited'], ...
    'Position',[700 55 750 100],'Inputs','**');
add_block('simulink/Math Operations/Product',[sys '/Iqr Limited'], ...
    'Position',[700 200 750 245],'Inputs','**');

wire(sys,'Idr_ref_raw_A/1','Idr Limited/1','');
wire(sys,'Idr_ref_raw_A/1','Idr Squared/1','');
wire(sys,'Iqr_ref_raw_A/1','Iqr Squared/1','');
wire(sys,'Iqr_ref_raw_A/1','Iqr Limited/2','');
wire(sys,'Idr Squared/1','Magnitude Squared/1','');
wire(sys,'Iqr Squared/1','Magnitude Squared/2','');
wire(sys,'Magnitude Squared/1','Reference Magnitude/1','');
wire(sys,'Reference Magnitude/1','Safe Magnitude/1','');
wire(sys,'Magnitude Floor/1','Safe Magnitude/2','');
wire(sys,'Rotor Current Limit/1','Limit Ratio/1','');
wire(sys,'Safe Magnitude/1','Limit Ratio/2','');
wire(sys,'Limit Ratio/1','Circular Limit Scale/1','');
wire(sys,'Unity Scale/1','Circular Limit Scale/2','');
wire(sys,'Circular Limit Scale/1','Idr Limited/2','');
wire(sys,'Circular Limit Scale/1','Iqr Limited/1','');
wire(sys,'Idr Limited/1','Idr_ref_lim_A/1','');
wire(sys,'Iqr Limited/1','Iqr_ref_lim_A/1','');
end

function buildRSCSlipPreControl(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Current dq A'], ...
    'Port','1','Position',[30 65 60 85]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Generator Speed rad_s'], ...
    'Port','2','Position',[30 165 60 185]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Flux dq Wb'], ...
    'Port','3','Position',[30 250 60 270]);

add_block('simulink/Ports & Subsystems/Out1',[sys '/Vdr_ff_V'], ...
    'Port','1','Position',[615 80 645 100]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Vqr_ff_V'], ...
    'Port','2','Position',[615 215 645 235]);

add_block('simulink/Signal Routing/Demux',[sys '/Demux Ir'], ...
    'Position',[125 50 130 100],'Outputs','2','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Demux Psir'], ...
    'Position',[125 235 130 285],'Outputs','2','ShowName','off');

add_block('simulink/Sources/Constant',[sys '/Synchronous Speed'], ...
    'Position',[105 120 205 150],'Value','DFIG.Base.ws');
add_block('simulink/Math Operations/Gain',[sys '/Pole Pairs'], ...
    'Position',[105 160 205 190],'Gain','DFIG.Machine.p');
add_block('simulink/Math Operations/Sum',[sys '/Slip Speed'], ...
    'Position',[245 135 280 185],'Inputs','+-','IconShape','rectangular');

add_block('simulink/Math Operations/Gain',[sys '/Rr idr'], ...
    'Position',[315 45 405 75],'Gain','DFIG.Machine.Rr');
add_block('simulink/Math Operations/Gain',[sys '/Rr iqr'], ...
    'Position',[315 90 405 120],'Gain','DFIG.Machine.Rr');
add_block('simulink/Math Operations/Product',[sys '/wSlip psiqr'], ...
    'Position',[335 180 390 215],'Inputs','**');
add_block('simulink/Math Operations/Product',[sys '/wSlip psidr'], ...
    'Position',[335 235 390 270],'Inputs','**');

add_block('simulink/Math Operations/Sum',[sys '/Vdr Pre-Control Sum'], ...
    'Position',[485 60 525 120],'Inputs','+-','IconShape','rectangular');
add_block('simulink/Math Operations/Sum',[sys '/Vqr Pre-Control Sum'], ...
    'Position',[485 195 525 255],'Inputs','++','IconShape','rectangular');

wire(sys,'Rotor Current dq A/1','Demux Ir/1','');
wire(sys,'Rotor Flux dq Wb/1','Demux Psir/1','');
wire(sys,'Generator Speed rad_s/1','Pole Pairs/1','');
wire(sys,'Synchronous Speed/1','Slip Speed/1','');
wire(sys,'Pole Pairs/1','Slip Speed/2','');

wire(sys,'Demux Ir/1','Rr idr/1','');
wire(sys,'Demux Ir/2','Rr iqr/1','');
wire(sys,'Slip Speed/1','wSlip psiqr/1','');
wire(sys,'Demux Psir/2','wSlip psiqr/2','');
wire(sys,'Slip Speed/1','wSlip psidr/1','');
wire(sys,'Demux Psir/1','wSlip psidr/2','');

wire(sys,'Rr idr/1','Vdr Pre-Control Sum/1','');
wire(sys,'wSlip psiqr/1','Vdr Pre-Control Sum/2','');
wire(sys,'Rr iqr/1','Vqr Pre-Control Sum/1','');
wire(sys,'wSlip psidr/1','Vqr Pre-Control Sum/2','');

wire(sys,'Vdr Pre-Control Sum/1','Vdr_ff_V/1','');
wire(sys,'Vqr Pre-Control Sum/1','Vqr_ff_V/1','');
end

function buildRSCDualPIController(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Idr_ref_lim_A'], ...
    'Port','1','Position',[30 55 60 75]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Iqr_ref_lim_A'], ...
    'Port','2','Position',[30 215 60 235]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Current dq A'], ...
    'Port','3','Position',[30 135 60 155]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Vdr_ff_V'], ...
    'Port','4','Position',[30 100 60 120]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Vqr_ff_V'], ...
    'Port','5','Position',[30 265 60 285]);

add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Voltage Command dq V'], ...
    'Port','1','Position',[725 155 755 175]);

add_block('simulink/Signal Routing/Demux',[sys '/Demux Ir'], ...
    'Position',[115 120 120 170],'Outputs','2','ShowName','off');

% d-axis lane (top)
add_block('simulink/Math Operations/Sum',[sys '/Idr Error'], ...
    'Position',[185 50 220 95],'Inputs','+-','IconShape','rectangular');
add_block('simulink/Math Operations/Gain',[sys '/Idr Kp'], ...
    'Position',[275 35 365 65],'Gain','DFIG.RSC.Kp');
add_block('simulink/Math Operations/Gain',[sys '/Idr Ki'], ...
    'Position',[275 80 365 110],'Gain','DFIG.RSC.Ki');
add_block('simulink/Continuous/Integrator',[sys '/Idr Integrator'], ...
    'Position',[395 80 445 110]);
add_block('simulink/Math Operations/Sum',[sys '/Vdr Command Sum'], ...
    'Position',[495 45 535 125],'Inputs','+++','IconShape','rectangular');
add_block('simulink/Discontinuities/Saturation',[sys '/Vdr Bridge Limit'], ...
    'Position',[575 70 635 100], ...
    'UpperLimit','DFIG.RSC.Vmax','LowerLimit','-DFIG.RSC.Vmax');

% q-axis lane (bottom)
add_block('simulink/Math Operations/Sum',[sys '/Iqr Error'], ...
    'Position',[185 210 220 255],'Inputs','+-','IconShape','rectangular');
add_block('simulink/Math Operations/Gain',[sys '/Iqr Kp'], ...
    'Position',[275 195 365 225],'Gain','DFIG.RSC.Kp');
add_block('simulink/Math Operations/Gain',[sys '/Iqr Ki'], ...
    'Position',[275 240 365 270],'Gain','DFIG.RSC.Ki');
add_block('simulink/Continuous/Integrator',[sys '/Iqr Integrator'], ...
    'Position',[395 240 445 270]);
add_block('simulink/Math Operations/Sum',[sys '/Vqr Command Sum'], ...
    'Position',[495 205 535 285],'Inputs','+++','IconShape','rectangular');
add_block('simulink/Discontinuities/Saturation',[sys '/Vqr Bridge Limit'], ...
    'Position',[575 230 635 260], ...
    'UpperLimit','DFIG.RSC.Vmax','LowerLimit','-DFIG.RSC.Vmax');

add_block('simulink/Signal Routing/Mux',[sys '/Mux Vrdq'], ...
    'Position',[675 115 680 215],'Inputs','2','ShowName','off');

wire(sys,'Rotor Current dq A/1','Demux Ir/1','');

wire(sys,'Idr_ref_lim_A/1','Idr Error/1','');
wire(sys,'Demux Ir/1','Idr Error/2','');
wire(sys,'Idr Error/1','Idr Kp/1','');
wire(sys,'Idr Error/1','Idr Ki/1','');
wire(sys,'Idr Ki/1','Idr Integrator/1','');
wire(sys,'Idr Kp/1','Vdr Command Sum/1','');
wire(sys,'Idr Integrator/1','Vdr Command Sum/2','');
wire(sys,'Vdr_ff_V/1','Vdr Command Sum/3','');
wire(sys,'Vdr Command Sum/1','Vdr Bridge Limit/1','');
wire(sys,'Vdr Bridge Limit/1','Mux Vrdq/1','');

wire(sys,'Iqr_ref_lim_A/1','Iqr Error/1','');
wire(sys,'Demux Ir/2','Iqr Error/2','');
wire(sys,'Iqr Error/1','Iqr Kp/1','');
wire(sys,'Iqr Error/1','Iqr Ki/1','');
wire(sys,'Iqr Ki/1','Iqr Integrator/1','');
wire(sys,'Iqr Kp/1','Vqr Command Sum/1','');
wire(sys,'Iqr Integrator/1','Vqr Command Sum/2','');
wire(sys,'Vqr_ff_V/1','Vqr Command Sum/3','');
wire(sys,'Vqr Command Sum/1','Vqr Bridge Limit/1','');
wire(sys,'Vqr Bridge Limit/1','Mux Vrdq/2','');

wire(sys,'Mux Vrdq/1','Rotor Voltage Command dq V/1','');
end

%% ------------------------------------------------------------------------
%  04 dq to abc Stator Injection
%  ------------------------------------------------------------------------
function buildDqToAbc(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Stator Current dq'], ...
    'Port','1','Position',[20 150 50 170]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Stator Injection abc'], ...
    'Port','1','Position',[760 150 790 170]);
add_block('simulink/Signal Routing/Demux',[sys '/Separate dq'], ...
    'Position',[85 115 90 205],'Outputs','2');
add_block('simulink/Sources/Clock',[sys '/Grid Time'], ...
    'Position',[30 35 70 55]);
add_block('simulink/Math Operations/Gain',[sys '/Negative Grid Omega'], ...
    'Position',[100 25 205 60],'Gain','-DFIG.Base.ws');
% theta=-omega*t for the q-axis voltage convention used by the DFIG model.
% The inverse transform therefore uses +120 deg for phase B and -120 deg for
% phase C to produce the same positive sequence as the reused physical grid.
offsets={'A','0';'B','2*pi/3';'C','-2*pi/3'};
for k=1:3
    y=25+115*(k-1);
    add_block('simulink/Math Operations/Bias',[sys '/' offsets{k,1} ' Angle'], ...
        'Position',[235 y 300 y+30],'Bias',offsets{k,2});
    add_block('simulink/Math Operations/Trigonometric Function', ...
        [sys '/' offsets{k,1} ' Cos'], ...
        'Position',[335 y-10 385 y+20],'Operator','cos');
    add_block('simulink/Math Operations/Trigonometric Function', ...
        [sys '/' offsets{k,1} ' Sin'], ...
        'Position',[335 y+30 385 y+60],'Operator','sin');
    add_block('simulink/Math Operations/Product',[sys '/' offsets{k,1} ' id cos'], ...
        'Position',[430 y-10 475 y+25],'Inputs','**');
    add_block('simulink/Math Operations/Product',[sys '/' offsets{k,1} ' iq sin'], ...
        'Position',[430 y+35 475 y+70],'Inputs','**');
    add_block('simulink/Math Operations/Sum',[sys '/' offsets{k,1} ' Machine Current'], ...
        'Position',[520 y+5 555 y+60],'Inputs','+-');
    add_block('simulink/Math Operations/Gain',[sys '/' offsets{k,1} ' Injection Sign'], ...
        'Position',[590 y+15 650 y+50],'Gain','DFIG.Interface.StatorInjectionGain');
    wire(sys,'Negative Grid Omega/1',[offsets{k,1} ' Angle/1'],'');
    wire(sys,[offsets{k,1} ' Angle/1'],[offsets{k,1} ' Cos/1'],'');
    wire(sys,[offsets{k,1} ' Angle/1'],[offsets{k,1} ' Sin/1'],'');
    wire(sys,'Separate dq/1',[offsets{k,1} ' id cos/1'],'');
    wire(sys,[offsets{k,1} ' Cos/1'],[offsets{k,1} ' id cos/2'],'');
    wire(sys,'Separate dq/2',[offsets{k,1} ' iq sin/1'],'');
    wire(sys,[offsets{k,1} ' Sin/1'],[offsets{k,1} ' iq sin/2'],'');
    wire(sys,[offsets{k,1} ' id cos/1'],[offsets{k,1} ' Machine Current/1'],'');
    wire(sys,[offsets{k,1} ' iq sin/1'],[offsets{k,1} ' Machine Current/2'],'');
    wire(sys,[offsets{k,1} ' Machine Current/1'],[offsets{k,1} ' Injection Sign/1'],'');
end
add_block('simulink/Signal Routing/Mux',[sys '/Three-Phase Injection Vector'], ...
    'Position',[690 90 695 245],'Inputs','3');
wire(sys,'Stator Current dq/1','Separate dq/1','');wire(sys,'Grid Time/1','Negative Grid Omega/1','');
for k=1:3,wire(sys,[offsets{k,1} ' Injection Sign/1'],sprintf('Three-Phase Injection Vector/%d',k),'');end
wire(sys,'Three-Phase Injection Vector/1','Stator Injection abc/1','');
end

%% ------------------------------------------------------------------------
%  05 Average RSC Slip Power
%  ------------------------------------------------------------------------
function buildRotorSlipPower(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Voltage Command dq V'], ...
    'Port','1','Position',[35 65 65 85]);
add_block('simulink/Ports & Subsystems/In1',[sys '/Rotor Current dq A'], ...
    'Port','2','Position',[35 165 65 185]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Power to DC Link W'], ...
    'Port','1','Position',[545 115 575 135]);

add_block('simulink/Signal Routing/Demux',[sys '/Separate Rotor Voltage'], ...
    'Position',[125 45 130 105],'Outputs','2','ShowName','off');
add_block('simulink/Signal Routing/Demux',[sys '/Separate Rotor Current'], ...
    'Position',[125 145 130 205],'Outputs','2','ShowName','off');
add_block('simulink/Math Operations/Product',[sys '/Rotor vd id'], ...
    'Position',[225 55 280 95],'Inputs','**');
add_block('simulink/Math Operations/Product',[sys '/Rotor vq iq'], ...
    'Position',[225 145 280 185],'Inputs','**');
add_block('simulink/Math Operations/Sum',[sys '/Rotor Power Sum'], ...
    'Position',[335 90 375 160],'Inputs','++','IconShape','rectangular');
add_block('simulink/Math Operations/Gain',[sys '/Rotor Power into DC'], ...
    'Position',[415 105 505 145],'Gain','-1.5');

wire(sys,'Rotor Voltage Command dq V/1','Separate Rotor Voltage/1','');
wire(sys,'Rotor Current dq A/1','Separate Rotor Current/1','');
wire(sys,'Separate Rotor Voltage/1','Rotor vd id/1','');
wire(sys,'Separate Rotor Current/1','Rotor vd id/2','');
wire(sys,'Separate Rotor Voltage/2','Rotor vq iq/1','');
wire(sys,'Separate Rotor Current/2','Rotor vq iq/2','');
wire(sys,'Rotor vd id/1','Rotor Power Sum/1','');
wire(sys,'Rotor vq iq/1','Rotor Power Sum/2','');
wire(sys,'Rotor Power Sum/1','Rotor Power into DC/1','');
wire(sys,'Rotor Power into DC/1','Rotor Power to DC Link W/1','');
end

%% ========================================================================
%  05 FILTER TRANSFORMER AND PCC STATOR INJECTION BRANCH
%  ========================================================================
function addStatorInjection(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/DFIG Stator Current Injection abc'], ...
    'Port','1','Position',[20 350 50 370]);
add_block('nesl_utility/Simulink-PS Converter',[sys '/Stator Current to Physical'], ...
    'Position',[90 340 165 380],'Unit','A','ShowName','off');
add_block(sprintf('ee_lib/Sources/Controlled Current Source\n(Three-Phase)'), ...
    [sys '/DFIG Stator Average Current Source'], ...
    'Position',[185 335 305 425], ...
    'FRated','Base.f','G_parasitic','DFIG.Interface.CurrentSourceParasiticConductance');
add_block('ee_lib/Connectors & References/Electrical Reference', ...
    [sys '/DFIG Stator Neutral Reference'], ...
    'Position',[125 445 165 485],'Orientation','down');
wire(sys,'DFIG Stator Current Injection abc/1','Stator Current to Physical/1','');
conv=get_param([sys '/Stator Current to Physical'],'PortHandles');
src=get_param([sys '/DFIG Stator Average Current Source'],'PortHandles');
gnd=get_param([sys '/DFIG Stator Neutral Reference'],'PortHandles');
xfmr=get_param([sys '/0.69 kV to 10 kV Step-Up Transformer'],'PortHandles');
add_line(sys,conv.RConn(1),src.LConn(1),'autorouting','on');
add_line(sys,src.LConn(2),gnd.LConn(1),'autorouting','on');
hStatorBus=add_line(sys,src.RConn(1),xfmr.LConn(1),'autorouting','on');
srcPos=get_param(src.RConn(1),'Position');
xfmrPos=get_param(xfmr.LConn(1),'Position');
xJoin=round((srcPos(1)+xfmrPos(1))/2);
set_param(hStatorBus,'Points',[srcPos;xJoin srcPos(2);xJoin xfmrPos(2);xfmrPos]);
anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(sys,[45 510 1040 555],[ ...
    'Reused main path remains horizontal: average GSC -> Rf+Lf -> 0.69/10 kV transformer -> PCC sensor. ' ...
    'The DFIG stator average current source is a local vertical branch at the 690 V transformer bus.']);
end

function h=wire(s,a,b,n),h=add_line(s,a,b,'autorouting','on');if ~isempty(n),set_param(h,'Name',n);end,end
function h=rewire(s,a,b,n)
tok=regexp(b,'^(.*)/(\d+)$','tokens','once');
if ~isempty(tok)
    ph=get_param([s '/' tok{1}],'PortHandles');idx=str2double(tok{2});
    if idx<=numel(ph.Inport)
        old=get_param(ph.Inport(idx),'Line');if ~isempty(old)&&old>0,delete_line(old);end
    end
end
h=wire(s,a,b,n);
end
function note(s,pos,t),a=Simulink.Annotation(s,t);a.Position=pos;a.FontSize=10;a.ForegroundColor='blue';end
function enableNamedSignalLogging(model,name)
lines=find_system(model,'FindAll','on','Type','line');
for k=1:numel(lines)
    if strcmp(get_param(lines(k),'Name'),name)
        src=get_param(lines(k),'SrcPortHandle');
        try,set_param(src,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',name);catch,end
        return
    end
end
end
function routeNamedLineShortest(model,name)
lines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line','Name',name);
for k=1:numel(lines)
    src=get_param(lines(k),'SrcPortHandle');dst=get_param(lines(k),'DstPortHandle');
    if isempty(src)||src<0||isempty(dst),continue,end
    if numel(dst)>1,dst=dst(1);end
    a=get_param(src,'Position');b=get_param(dst,'Position');
    if a(2)==b(2),points=[a;b];else,xm=round((a(1)+b(1))/2);points=[a;xm a(2);xm b(2);b];end
    set_param(lines(k),'Points',points);
end
end
function routeRotorPowerTree(model)
% One short orthogonal trunk serves both consumers.  Keeping this explicit
% prevents the autorouter from drawing two diagonal copies from the DFIG.
lines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line', ...
    'Name','P_rotor_to_dc_W');
trunk=[];branches=[];
for k=1:numel(lines)
    d=get_param(lines(k),'DstPortHandle');
    if numel(d)>1,trunk=lines(k);else,branches(end+1)=lines(k);end %#ok<AGROW>
end
if isempty(trunk)||numel(branches)~=2,return,end
src=get_param(trunk,'SrcPortHandle');srcPos=get_param(src,'Position');
dstPos=zeros(2,2);
for k=1:2
    d=get_param(branches(k),'DstPortHandle');dstPos(k,:)=get_param(d,'Position');
end
[~,controlIdx]=min(dstPos(:,1));dcIdx=3-controlIdx;
xTrunk=round((dstPos(controlIdx,1)+dstPos(dcIdx,1))/2);
yJoin=dstPos(dcIdx,2);
set_param(trunk,'Points',[srcPos;xTrunk srcPos(2);xTrunk yJoin]);
set_param(branches(dcIdx),'Points',[xTrunk yJoin;dstPos(dcIdx,:)]);
set_param(branches(controlIdx),'Points',[xTrunk yJoin;xTrunk dstPos(controlIdx,2);dstPos(controlIdx,:)]);
end
function routeStatorInjectionLine(model)
lines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line', ...
    'Name','Iabc_DFIG_stator_injection');
for k=1:numel(lines)
    src=get_param(lines(k),'SrcPortHandle');dst=get_param(lines(k),'DstPortHandle');
    if isempty(src)||src<0||isempty(dst),continue,end
    if numel(dst)>1,dst=dst(1);end
    a=get_param(src,'Position');b=get_param(dst,'Position');
    xDrop=b(1)-40;
    set_param(lines(k),'Points',[a;xDrop a(2);xDrop b(2);b]);
end
end
function disableSubsystemPreviews(model)
b=find_system(model,'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem');
for k=1:numel(b),try,set_param(b{k},'ContentPreviewEnabled','off');catch,end,end
end
function moveSubsystemPortToSide(blockPath,identifier,side,order)
if nargin<4,order='last';end
block=getSimulinkBlockHandle(blockPath);
spec=flexibleportplacement.specification.Factory.getSpecifiction(block);
sideNames={'LEFT','RIGHT','TOP','BOTTOM'};connector=[];
for k=1:numel(sideNames)
    candidates=spec.SideData.(sideNames{k});
    for j=1:numel(candidates)
        if strcmp(candidates(j).Identifier,identifier),connector=candidates(j);break,end
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
function renderSystem(sys,file)
try,open_system(sys);set_param(sys,'ZoomFactor','FitSystem');drawnow;print(['-s' sys],'-dpng','-r150',file);
catch ME,warning('Render failed for %s: %s',sys,ME.message);end
end
