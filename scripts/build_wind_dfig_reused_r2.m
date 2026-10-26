%BUILD_WIND_DFIG_REUSED_R2 Derive DFIG R2 from the accepted average plant.
% Reused verbatim: turbine aerodynamics/inertia, physical DC-link and average
% GSC, GFL controller, filter/transformer/PCC, and grid equivalent.  Only the
% PMSG/MSC block is replaced by a wound-rotor DFIG plus average RSC, and a
% stator-current injection interface is added at the existing 690 V bus.

scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
source=fullfile(root,'models','resources','Wind_DirectDrive_Average.slx');
r1file=fullfile(root,'build','Wind_DFIG_Average_R1.slx');
model='Wind_DFIG_Reused_R2';modelFile=fullfile(root,'build',[model '.slx']);
assert(isfile(source),'Missing accepted average source: %s',source);
assert(isfile(r1file),'Missing validated DFIG R1 algorithm source: %s',r1file);
run(fullfile(root,'parameters','init_wind_dfig_reused_r2.m'));
if bdIsLoaded(model),close_system(model,0);end
copyfile(source,modelFile,'f');load_system(modelFile);load_system(r1file);
load_system('ee_lib');load_system('nesl_utility');

set_param(model,'PreLoadFcn','', ...
    'InitFcn',char("root=fileparts(fileparts(get_param(bdroot,'FileName'))); " + ...
    "run(fullfile(root,'parameters','init_wind_dfig_reused_r2.m'));"), ...
    'StopTime','DFIG.Simulation.StopTime','MaxStep','Base.Simulation.MaxStep', ...
    'Description',['DFIG R2 derived from Wind_DirectDrive_Average. Retains the ' ...
    'accepted physical DC/GSC/filter/transformer/PCC/grid chain and replaces ' ...
    'only PMSG/MSC with explicit dq DFIG plus average RSC.']);

old=[model '/02 PMSG and MSC Average Model'];
assert(getSimulinkBlockHandle(old)>0,'Expected reused PMSG/MSC boundary is missing.');
delete_block(old);
dfig=[model '/02 DFIG and Average RSC'];
add_block('built-in/Subsystem',dfig,'Position',[430 70 735 240], ...
    'BackgroundColor','[0.96 0.86 0.55]','FontWeight','bold', ...
    'ContentPreviewEnabled','off');
buildDFIGAssembly(dfig,'Wind_DFIG_Average_R1');
moveSubsystemPortToSide(dfig,'Out1','LEFT','last');
% Separate the two electrical interfaces by direction: stator current leaves
% to the right toward the transformer bus, while signed rotor slip power
% leaves downward toward the reused DC/GSC control band.
moveSubsystemPortToSide(dfig,'Out2','BOTTOM','last');

iface=[model '/05 Filter Transformer and PCC'];
addStatorInjection(iface);

% Preserve the proven downstream hierarchy and place only the new machine
% above it.  Each semantic path receives its own routing band.
set_param([model '/01 Wind Turbine Aerodynamics'],'Position',[45 70 350 240]);
set_param(dfig,'Position',[430 70 735 240]);
set_param([model '/04 GFL Control'],'Position',[470 330 745 500]);
moveSubsystemPortToSide([model '/04 GFL Control'],'In1','TOP','last');
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
for n={'omega_turbine_rad_s','T_e_turbine_Nm','P_rotor_to_dc_W', ...
        'Iabc_DFIG_stator_injection','Vabc_PCC_Meas','Iabc_PCC_Meas', ...
        'Vdc_Meas','P_PCC','Q_PCC'}
    enableNamedSignalLogging(model,n{1});
end

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
renderSystem(model,fullfile(root,'build','WIND_DFIG_R2_01_Top.png'));
renderSystem(dfig,fullfile(root,'build','WIND_DFIG_R2_02_DFIG_RSC.png'));
renderSystem(iface,fullfile(root,'build','WIND_DFIG_R2_03_Reused_PCC.png'));
renderSystem([model '/03 DC Link and Average GSC'],fullfile(root,'build','WIND_DFIG_R2_04_Reused_DC_GSC.png'));
close_system(model,0);close_system('Wind_DFIG_Average_R1',0);
fprintf('WIND_DFIG_REUSED_R2_BUILD_OK=1\nMODEL=%s\n',modelFile);

function buildDFIGAssembly(sys,r1)
add_block('simulink/Ports & Subsystems/In1',[sys '/Turbine Rotor Speed'], ...
    'Port','1','Position',[20 160 50 180]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Turbine-Side Electromagnetic Torque'], ...
    'Port','1','Position',[20 260 50 280],'Orientation','right');
add_block('simulink/Ports & Subsystems/Out1',[sys '/Rotor Power to DC Link'], ...
    'Port','2','Position',[1080 375 1110 395]);
add_block('simulink/Ports & Subsystems/Out1',[sys '/Stator Current Injection abc'], ...
    'Port','3','Position',[1080 90 1110 110]);

add_block([r1 '/02 Wound-Rotor DFIG dq Plant'],[sys '/02 Wound-Rotor DFIG dq Plant'], ...
    'Position',[365 80 660 285],'ContentPreviewEnabled','off');
add_block([r1 '/03 Rotor-Side Average Converter Control'], ...
    [sys '/03 Rotor-Side Average Converter Control'], ...
    'Position',[360 365 680 555],'ContentPreviewEnabled','off');
add_block('built-in/Subsystem',[sys '/04 dq to abc Stator Injection'], ...
    'Position',[755 55 965 180],'BackgroundColor','[0.85 0.93 0.98]', ...
    'ContentPreviewEnabled','off');
buildDqToAbc([sys '/04 dq to abc Stator Injection']);

add_block('simulink/Math Operations/Gain',[sys '/Gearbox Speed'], ...
    'Position',[90 145 190 180],'Gain','DFIG.Drive.gearRatio');
add_block('simulink/Math Operations/Math Function',[sys '/Turbine Speed Squared'], ...
    'Position',[90 210 150 250],'Operator','square');
add_block('simulink/Math Operations/Gain',[sys '/MPPT Generator Torque'], ...
    'Position',[190 210 315 250], ...
    'Gain','Wind.Kopt_Nm_per_rad_s2/(DFIG.Drive.gearRatio*DFIG.Wind.etaGear)');
add_block('simulink/Sources/Constant',[sys '/Stator Grid Voltage dq'], ...
    'Position',[95 65 215 100],'Value','DFIG.Grid.Vdq');
add_block('simulink/Math Operations/Gain',[sys '/Torque Referred to Turbine'], ...
    'Position',[785 245 930 280], ...
    'Gain','DFIG.Drive.gearRatio*DFIG.Wind.etaGear');

add_block('simulink/Signal Routing/Demux',[sys '/Separate Rotor Voltage'], ...
    'Position',[735 345 740 420],'Outputs','2');
add_block('simulink/Signal Routing/Demux',[sys '/Separate Rotor Current'], ...
    'Position',[735 430 740 505],'Outputs','2');
add_block('simulink/Math Operations/Product',[sys '/Rotor vd id'], ...
    'Position',[785 340 835 380],'Inputs','**');
add_block('simulink/Math Operations/Product',[sys '/Rotor vq iq'], ...
    'Position',[785 405 835 445],'Inputs','**');
add_block('simulink/Math Operations/Sum',[sys '/Rotor Power Sum'], ...
    'Position',[865 355 900 425],'Inputs','++');
add_block('simulink/Math Operations/Gain',[sys '/Rotor Power into DC'], ...
    'Position',[935 370 1020 410],'Gain','-1.5');

wire(sys,'Turbine Rotor Speed/1','Gearbox Speed/1','');
wire(sys,'Turbine Rotor Speed/1','Turbine Speed Squared/1','');
wire(sys,'Turbine Speed Squared/1','MPPT Generator Torque/1','');
wire(sys,'Stator Grid Voltage dq/1','02 Wound-Rotor DFIG dq Plant/1','');
wire(sys,'Gearbox Speed/1','02 Wound-Rotor DFIG dq Plant/3','');
wire(sys,'Gearbox Speed/1','03 Rotor-Side Average Converter Control/2','');
wire(sys,'MPPT Generator Torque/1','03 Rotor-Side Average Converter Control/1','');
wire(sys,'02 Wound-Rotor DFIG dq Plant/2','03 Rotor-Side Average Converter Control/3','');
wire(sys,'02 Wound-Rotor DFIG dq Plant/5','03 Rotor-Side Average Converter Control/4','');
wire(sys,'03 Rotor-Side Average Converter Control/1','02 Wound-Rotor DFIG dq Plant/2','');
wire(sys,'02 Wound-Rotor DFIG dq Plant/3','Torque Referred to Turbine/1','');
wire(sys,'Torque Referred to Turbine/1','Turbine-Side Electromagnetic Torque/1','');
wire(sys,'02 Wound-Rotor DFIG dq Plant/1','04 dq to abc Stator Injection/1','');
wire(sys,'04 dq to abc Stator Injection/1','Stator Current Injection abc/1','');
wire(sys,'03 Rotor-Side Average Converter Control/1','Separate Rotor Voltage/1','');
wire(sys,'02 Wound-Rotor DFIG dq Plant/2','Separate Rotor Current/1','');
wire(sys,'Separate Rotor Voltage/1','Rotor vd id/1','');wire(sys,'Separate Rotor Current/1','Rotor vd id/2','');
wire(sys,'Separate Rotor Voltage/2','Rotor vq iq/1','');wire(sys,'Separate Rotor Current/2','Rotor vq iq/2','');
wire(sys,'Rotor vd id/1','Rotor Power Sum/1','');wire(sys,'Rotor vq iq/1','Rotor Power Sum/2','');
wire(sys,'Rotor Power Sum/1','Rotor Power into DC/1','');wire(sys,'Rotor Power into DC/1','Rotor Power to DC Link/1','');
note(sys,[65 610 1050 665],[ ...
    'Reused interfaces: the accepted turbine supplies turbine speed and receives turbine-side Te. ' ...
    'Signed rotor slip power uses the former Pmsc/DC input. Stator current is injected at the existing 690 V bus.']);
end

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

function addStatorInjection(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/DFIG Stator Current Injection abc'], ...
    'Port','1','Position',[20 325 50 345]);
add_block('nesl_utility/Simulink-PS Converter',[sys '/Stator Current to Physical'], ...
    'Position',[75 315 170 355],'Unit','A');
add_block(sprintf('ee_lib/Sources/Controlled Current Source\n(Three-Phase)'), ...
    [sys '/DFIG Stator Average Current Source'], ...
    'Position',[215 285 360 385], ...
    'FRated','Base.f','G_parasitic','DFIG.Interface.CurrentSourceParasiticConductance');
add_block('ee_lib/Connectors & References/Electrical Reference', ...
    [sys '/DFIG Stator Neutral Reference'], ...
    'Position',[255 420 295 460],'Orientation','down');
wire(sys,'DFIG Stator Current Injection abc/1','Stator Current to Physical/1','');
conv=get_param([sys '/Stator Current to Physical'],'PortHandles');
src=get_param([sys '/DFIG Stator Average Current Source'],'PortHandles');
gnd=get_param([sys '/DFIG Stator Neutral Reference'],'PortHandles');
xfmr=get_param([sys '/0.69 kV to 10 kV Step-Up Transformer'],'PortHandles');
add_line(sys,conv.RConn(1),src.LConn(1),'autorouting','on');
add_line(sys,src.LConn(2),gnd.LConn(1),'autorouting','on');
add_line(sys,src.RConn(1),xfmr.LConn(1),'autorouting','on');
anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(sys,[45 500 1040 555],[ ...
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
xBus=dstPos(controlIdx,1);yBus=round((srcPos(2)+dstPos(controlIdx,2))/2);
set_param(trunk,'Points',[srcPos;xBus srcPos(2);xBus yBus]);
set_param(branches(controlIdx),'Points',[xBus yBus;dstPos(controlIdx,:)]);
xApproach=dstPos(dcIdx,1)-35;
set_param(branches(dcIdx),'Points',[xBus yBus;xApproach yBus; ...
    xApproach dstPos(dcIdx,2);dstPos(dcIdx,:)]);
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
