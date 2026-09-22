%BUILD_GFM_PLANT_C0_MODEL Generate the independent GFM-BESS plant asset.
% This is intentionally a copied branch of the readable B0 plant builder.
% It does not modify or regenerate the GFL B0/B1 models.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root,'Parameters'));
init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));

model = 'GFM_BESS_Plant_C0';
modelFile = fullfile(root, [model '.slx']);
if bdIsLoaded(model)
    close_system(model, 0);
end
if isfile(modelFile)
    delete(modelFile);
end

load_system('simulink');
load_system('ee_lib');
load_system('nesl_utility');
new_system(model);
set_param(model, 'Location',[40 80 1510 750], 'ZoomFactor','FitSystem', ...
    'Solver','ode23t', 'StopTime','Base.Simulation.StopTime', ...
    'MaxStep','Base.Simulation.MaxStep', 'ReturnWorkspaceOutputs','on');

% Top level shows functional plant boundaries rather than implementation
% plumbing. Measurements remain named and loggable inside their owners.
addSubsystem(model,'Controller Placeholder',[250 65 455 155],[1.00 0.93 0.75]);
addSubsystem(model,'Two-Level VSC',[250 245 485 390],[1.00 0.88 0.65]);
addSubsystem(model,'Grid Interface (Filter XFMR PCC)',[600 245 895 390],[0.87 1.00 0.87]);
addSubsystem(model,'Grid Equivalent and Source',[1010 245 1280 390],[0.85 0.93 1.00]);

buildControllerPlaceholder([model '/Controller Placeholder']);
buildVSC([model '/Two-Level VSC']);
buildGridInterface([model '/Grid Interface (Filter XFMR PCC)']);
buildGridSystem([model '/Grid Equivalent and Source']);

% Top-level power connections and named signal flow.
connectPhysical(model,'Two-Level VSC','RConn',1, ...
    'Grid Interface (Filter XFMR PCC)','LConn',1,'VSC_AC_Terminal');
connectPhysical(model,'Grid Interface (Filter XFMR PCC)','RConn',1, ...
    'Grid Equivalent and Source','LConn',1,'PCC_to_Grid');

connectSignal(model,'Controller Placeholder',1,'Two-Level VSC',1,'GatePulses_B0_Off');

addNote(model,[45 165 500 220],sprintf([ ...
    'GFM-BESS INDEPENDENT PLANT\n' ...
    '5 MW / 10 MWh branch plant. Gates remain off until the C0 controller is added.']));
addNote(model,[600 420 1280 455], ...
    'Plant boundaries: converter | filter + transformer + internal PCC measurement | grid impedance + source.');

% R2026a enables subsystem previews again when children are added. Disable
% them after construction so each hierarchy level reads as a clean diagram.
disableSubsystemPreviews(model);

set_param(model,'PreLoadFcn',sprintf("addpath('%s'); init_project; run(fullfile('%s','Parameters','gfm_parameters.m'));", ...
    strrep(root,"'","''"),strrep(root,"'","''")));
set_param(model,'InitFcn', ...
    "init_project; run(fullfile(fileparts(get_param(bdroot,'FileName')),'Parameters','gfm_parameters.m'));");
set_param(model,'Description', ...
    'Independent human-readable 5 MW / 10 MWh GFM-BESS plant. No controller is embedded in this model.');

save_system(model,modelFile);
set_param(model,'SimulationCommand','update');
save_system(model,modelFile);
close_system(model,0);
fprintf('Created and diagram-updated: %s\n',modelFile);

%% Local builders
function addSubsystem(parent,name,pos,color)
path = [parent '/' name];
add_block('built-in/Subsystem',path,'Position',pos,'BackgroundColor',rgbName(color), ...
    'ShowName','on','FontWeight','bold','ContentPreviewEnabled','off');
end

function buildControllerPlaceholder(sys)
add_block('simulink/Sources/Constant',[sys '/All Gates Off'], ...
    'Position',[80 105 205 155],'Value','Control.PWM.GatesOff', ...
    'SampleTime','Control.PWM.Ts');
add_block('simulink/Ports & Subsystems/Out1',[sys '/GatePulses'], ...
    'Position',[300 118 330 132],'Port','1');
lh = add_line(sys,'All Gates Off/1','GatePulses/1','autorouting','on');
set_param(lh,'Name','GatePulses_B0_Off');
addNote(sys,[45 30 350 75], ...
    'B0 interface only. Replace the constant with readable carrier PWM in B1; the VSC wiring remains unchanged.');
end

function buildVSC(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/GatePulses'], ...
    'Position',[25 410 55 430],'Port','1');
addPhysPort(sys,'AC_Terminal','Right',1,[820 180 850 210]);

% DC source, link capacitor and Vdc measurement are ordinary circuit
% elements inside the converter boundary. No artificial DC busbar blocks.
add_block('ee_lib/Sources/Voltage Source',[sys '/Controllable DC Source'], ...
    'Position',[70 105 170 170],'Orientation','down', ...
    'dc_voltage','PV.Vdc','ac_voltage','0');
add_block('ee_lib/Passive/Capacitor',[sys '/DC-Link Capacitor'], ...
    'Position',[235 100 315 175],'Orientation','down', ...
    'c','Converter.Cdc','r','Converter.Cdc_esr', ...
    'v_specify','on','v_priority','High','v','Converter.Vdc_nom');
add_block('ee_lib/Sensors & Transducers/Voltage Sensor',[sys '/Vdc Sensor'], ...
    'Position',[385 100 475 175],'Orientation','down');
add_block('nesl_utility/PS-Simulink Converter',[sys '/Vdc to Simulink'], ...
    'Position',[350 255 450 295],'Unit','V');
add_block('simulink/Sinks/Terminator',[sys '/Vdc Internal Monitor'], ...
    'Position',[505 265 525 285]);
add_block('ee_lib/Connectors & References/Electrical Reference', ...
    [sys '/DC Negative Reference'],'Position',[225 230 265 270]);
add_block('nesl_utility/Solver Configuration',[sys '/Solver Configuration'], ...
    'Position',[70 230 120 280]);

add_block('simulink/Signal Routing/Demux',[sys '/Six Gate Signals'], ...
    'Position',[95 350 100 500],'Outputs','6');
for k = 1:6
    y = 315 + 38*k;
    name = sprintf('Gate %d to Physical Signal',k);
    add_block('nesl_utility/Simulink-PS Converter',[sys '/' name], ...
        'Position',[160 y 240 y+25],'Unit','V');
end
add_block('ee_lib/Semiconductors & Converters/Converters/Six-Pulse Gate Multiplexer', ...
    [sys '/Six-Pulse Gate Multiplexer'],'Position',[305 335 395 520]);
add_block('ee_lib/Semiconductors & Converters/Converters/Converter (Three-Phase)', ...
    [sys '/Two-Level Three-Phase Bridge'],'Position',[650 105 760 285], ...
    'fidelity_option','ee.enum.converters.fidelity.detailed', ...
    'device_type','ee.enum.converters.switchingdevice.ideal', ...
    'Ron','Converter.SwitchOnResistance','Goff','Converter.OffConductance', ...
    'Vth','Converter.GateThreshold_V', ...
    'diode_param','ee.enum.converters.protectiondiode.nodynamics');

add_line(sys,'GatePulses/1','Six Gate Signals/1','autorouting','on');
mux = get_param([sys '/Six-Pulse Gate Multiplexer'],'PortHandles');
for k = 1:6
    cv = get_param([sys '/' sprintf('Gate %d to Physical Signal',k)],'PortHandles');
    dm = get_param([sys '/Six Gate Signals'],'PortHandles');
    add_line(sys,dm.Outport(k),cv.Inport(1),'autorouting','on');
    add_line(sys,cv.RConn(1),mux.LConn(k),'autorouting','on');
end
bridge = get_param([sys '/Two-Level Three-Phase Bridge'],'PortHandles');
add_line(sys,mux.RConn(1),bridge.LConn(1),'autorouting','on');
src = get_param([sys '/Controllable DC Source'],'PortHandles');
cap = get_param([sys '/DC-Link Capacitor'],'PortHandles');
sen = get_param([sys '/Vdc Sensor'],'PortHandles');
ref = get_param([sys '/DC Negative Reference'],'PortHandles');
sol = get_param([sys '/Solver Configuration'],'PortHandles');
vconv = get_param([sys '/Vdc to Simulink'],'PortHandles');
add_line(sys,src.LConn(1),bridge.RConn(1),'autorouting','on');
add_line(sys,src.RConn(1),bridge.RConn(2),'autorouting','on');
add_line(sys,cap.LConn(1),src.LConn(1),'autorouting','on');
add_line(sys,cap.RConn(1),src.RConn(1),'autorouting','on');
add_line(sys,sen.LConn(1),src.LConn(1),'autorouting','on');
add_line(sys,sen.RConn(2),src.RConn(1),'autorouting','on');
add_line(sys,ref.LConn(1),src.RConn(1),'autorouting','on');
add_line(sys,sol.RConn(1),src.RConn(1),'autorouting','on');
add_line(sys,sen.RConn(1),vconv.LConn(1),'autorouting','on');
lvdc = add_line(sys,vconv.Outport(1), ...
    get_param([sys '/Vdc Internal Monitor'],'PortHandles').Inport(1));
set_param(lvdc,'Name','Vdc');
add_line(sys,bridge.LConn(2),innerPort([sys '/AC_Terminal']),'autorouting','on');
addNote(sys,[55 625 805 670], ...
    'DC source, Cdc and Vdc sensing feed the detailed two-level bridge directly. Gate order is [GaH GaL GbH GbL GcH GcL].');
end

function buildGridInterface(sys)
addPhysPort(sys,'From_VSC','Left',1,[20 180 50 210]);
addPhysPort(sys,'To_Grid','Right',2,[1260 180 1290 210]);
add_block('built-in/Subsystem',[sys '/Converter Terminal Measurement'], ...
    'Position',[85 115 275 285],'BackgroundColor','lightBlue', ...
    'FontWeight','bold','ContentPreviewEnabled','off');
buildACMeasurement([sys '/Converter Terminal Measurement']);
add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', ...
    [sys '/AC Filter Rf + Lf'],'Position',[345 140 495 250], ...
    'component_structure','ee.enum.rlc.structure.SeriesRL', ...
    'R','Filter.R','L','Filter.L');
add_block('ee_lib/Passive/Transformers/Two-Winding Transformer (Three-Phase)', ...
    [sys '/0.69 kV to 10 kV Step-Up Transformer'],'Position',[570 115 790 275], ...
    'SRated','Transformer.Sn','FRated','Transformer.f', ...
    'VRated1','Transformer.Vll_primary','VRated2','Transformer.Vll_secondary', ...
    'Winding1Connection','ee.enum.windingconnection.Y', ...
    'Winding2Connection','ee.enum.windingconnection.Y', ...
    'pu_Rw1','Transformer.R1_pu','pu_Rw2','Transformer.R2_pu', ...
    'leakage_reactance_option','ee.enum.transformer_leakage.include', ...
    'pu_Xl1','Transformer.X1_pu','pu_Xl2','Transformer.X2_pu', ...
    'pu_Xm','Transformer.Xm_pu');
add_block('ee_lib/Sensors & Transducers/Current and Voltage Sensor (Three-Phase)', ...
    [sys '/PCC VI Sensor'],'Position',[875 140 995 250], ...
    'vMeasurementType','ee.enum.vmeasurement.lg','outputUnit','ee.enum.unit.si', ...
    'SRated','Base.Sn','VRated','Base.Vll_hv');
add_block('nesl_utility/PS-Simulink Converter',[sys '/Vabc PCC to Simulink'], ...
    'Position',[1035 65 1130 100],'Unit','V');
add_block('nesl_utility/PS-Simulink Converter',[sys '/Iabc PCC to Simulink'], ...
    'Position',[1035 285 1130 320],'Unit','A');
add_block('simulink/Sinks/Terminator',[sys '/Vabc PCC Internal Monitor'], ...
    'Position',[1190 72 1210 92]);
add_block('simulink/Sinks/Terminator',[sys '/Iabc PCC Internal Monitor'], ...
    'Position',[1190 292 1210 312]);

terminal=get_param([sys '/Converter Terminal Measurement'],'PortHandles');
filter=get_param([sys '/AC Filter Rf + Lf'],'PortHandles');
tr=get_param([sys '/0.69 kV to 10 kV Step-Up Transformer'],'PortHandles');
sen=get_param([sys '/PCC VI Sensor'],'PortHandles');
vconv=get_param([sys '/Vabc PCC to Simulink'],'PortHandles');
iconv=get_param([sys '/Iabc PCC to Simulink'],'PortHandles');
add_line(sys,innerPort([sys '/From_VSC']),terminal.LConn(1),'autorouting','on');
add_line(sys,terminal.RConn(1),filter.LConn(1),'autorouting','on');
add_line(sys,filter.RConn(1),tr.LConn(1),'autorouting','on');
add_line(sys,tr.RConn(1),sen.LConn(1),'autorouting','on');
add_line(sys,sen.RConn(3),innerPort([sys '/To_Grid']),'autorouting','on');
add_line(sys,sen.RConn(1),vconv.LConn(1),'autorouting','on');
add_line(sys,sen.RConn(2),iconv.LConn(1),'autorouting','on');
lv=add_line(sys,vconv.Outport(1), ...
    get_param([sys '/Vabc PCC Internal Monitor'],'PortHandles').Inport(1));
li=add_line(sys,iconv.Outport(1), ...
    get_param([sys '/Iabc PCC Internal Monitor'],'PortHandles').Inport(1));
set_param(lv,'Name','Vabc_PCC'); set_param(li,'Name','Iabc_PCC');
addNote(sys,[100 365 1190 410], ...
    'Direct power path: converter-terminal measurement -> Rf + Lf -> 0.69/10 kV transformer -> PCC VI sensor.');
end

function buildACMeasurement(sys)
addPhysPort(sys,'From_VSC','Left',1,[20 145 50 175]);
addPhysPort(sys,'To_Filter','Right',2,[730 145 760 175]);
add_block('ee_lib/Sensors & Transducers/Current and Voltage Sensor (Three-Phase)', ...
    [sys '/Converter Terminal VI Sensor'],'Position',[165 105 285 225], ...
    'vMeasurementType','ee.enum.vmeasurement.lg','outputUnit','ee.enum.unit.si', ...
    'SRated','Base.Sn','VRated','Base.Vll_lv');
add_block('nesl_utility/PS-Simulink Converter',[sys '/Vabc to Simulink'], ...
    'Position',[350 70 445 105],'Unit','V');
add_block('nesl_utility/PS-Simulink Converter',[sys '/Iabc to Simulink'], ...
    'Position',[350 235 445 270],'Unit','A');
add_block('simulink/Sinks/Terminator',[sys '/Vabc Internal Monitor'], ...
    'Position',[675 55 695 75]);
add_block('built-in/Subsystem',[sys '/Line Voltage Calculation'], ...
    'Position',[475 120 625 205],'BackgroundColor','lightBlue', ...
    'ContentPreviewEnabled','off');
buildLineVoltageCalculation([sys '/Line Voltage Calculation']);
add_block('simulink/Sinks/Terminator',[sys '/Vll Internal Monitor'], ...
    'Position',[675 150 695 170]);
add_block('simulink/Sinks/Terminator',[sys '/Iabc Internal Monitor'], ...
    'Position',[675 245 695 265]);
sen=get_param([sys '/Converter Terminal VI Sensor'],'PortHandles');
vconv=get_param([sys '/Vabc to Simulink'],'PortHandles');
iconv=get_param([sys '/Iabc to Simulink'],'PortHandles');
add_line(sys,innerPort([sys '/From_VSC']),sen.LConn(1),'autorouting','on');
add_line(sys,sen.RConn(3),innerPort([sys '/To_Filter']),'autorouting','on');
add_line(sys,sen.RConn(1),vconv.LConn(1),'autorouting','on');
add_line(sys,sen.RConn(2),iconv.LConn(1),'autorouting','on');
lv=add_line(sys,vconv.Outport(1),get_param([sys '/Vabc Internal Monitor'],'PortHandles').Inport(1));
add_line(sys,vconv.Outport(1),get_param([sys '/Line Voltage Calculation'],'PortHandles').Inport(1), ...
    'autorouting','on');
ll=add_line(sys,get_param([sys '/Line Voltage Calculation'],'PortHandles').Outport(1), ...
    get_param([sys '/Vll Internal Monitor'],'PortHandles').Inport(1));
li=add_line(sys,iconv.Outport(1),get_param([sys '/Iabc Internal Monitor'],'PortHandles').Inport(1));
set_param(lv,'Name','Vabc_inv');set_param(ll,'Name','Vll_inv');set_param(li,'Name','Iabc_sw');
addNote(sys,[45 315 700 360], ...
    'Branch-local VSC-side voltage/current measurement before the RL filter.');
end

function buildLineVoltageCalculation(sys)
add_block('simulink/Ports & Subsystems/In1',[sys '/Vabc'], ...
    'Position',[20 120 50 140],'Port','1');
add_block('simulink/Signal Routing/Demux',[sys '/Separate abc'], ...
    'Position',[85 70 90 195],'Outputs','3');
names={'Vab = Va - Vb','Vbc = Vb - Vc','Vca = Vc - Va'};
for k=1:3
    y=45+75*(k-1);
    add_block('simulink/Math Operations/Sum',[sys '/' names{k}], ...
        'Position',[180 y 215 y+35],'Inputs','+-');
end
add_block('simulink/Signal Routing/Mux',[sys '/Vab Vbc Vca'], ...
    'Position',[300 65 305 205],'Inputs','3');
add_block('simulink/Ports & Subsystems/Out1',[sys '/Vll'], ...
    'Position',[370 125 400 145],'Port','1');
add_line(sys,'Vabc/1','Separate abc/1','autorouting','on');
add_line(sys,'Separate abc/1',[names{1} '/1'],'autorouting','on');
add_line(sys,'Separate abc/2',[names{1} '/2'],'autorouting','on');
add_line(sys,'Separate abc/2',[names{2} '/1'],'autorouting','on');
add_line(sys,'Separate abc/3',[names{2} '/2'],'autorouting','on');
add_line(sys,'Separate abc/3',[names{3} '/1'],'autorouting','on');
add_line(sys,'Separate abc/1',[names{3} '/2'],'autorouting','on');
for k=1:3
    add_line(sys,[names{k} '/1'],sprintf('Vab Vbc Vca/%d',k),'autorouting','on');
end
lh=add_line(sys,'Vab Vbc Vca/1','Vll/1','autorouting','on');
set_param(lh,'Name','Vll_inv');
end

function buildGridSystem(sys)
addPhysPort(sys,'From_PCC','Left',1,[20 180 50 210]);
add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', ...
    [sys '/Grid Equivalent Rg + Lg'],'Position',[135 140 285 250], ...
    'component_structure','ee.enum.rlc.structure.SeriesRL', ...
    'R','Grid.R','L','Grid.L');
add_block('ee_lib/Sources/Voltage Source (Three-Phase)',[sys '/Ideal Three-Phase Grid Source'], ...
    'Position',[430 125 570 255],'Orientation','left', ...
    'vline_rms','Grid.Vll','freq','Grid.f', ...
    'shift','Grid.phase_deg','impedance_option','0');
add_block('ee_lib/Connectors & References/Electrical Reference',[sys '/Grid Neutral Ground'], ...
    'Position',[620 270 660 310]);
gridZ=get_param([sys '/Grid Equivalent Rg + Lg'],'PortHandles');
src = get_param([sys '/Ideal Three-Phase Grid Source'],'PortHandles');
ref = get_param([sys '/Grid Neutral Ground'],'PortHandles');
add_line(sys,innerPort([sys '/From_PCC']),gridZ.LConn(1),'autorouting','on');
add_line(sys,gridZ.RConn(1),src.RConn(1),'autorouting','on');
add_line(sys,src.LConn(1),ref.LConn(1),'autorouting','on');
addNote(sys,[90 360 670 405], ...
    'Single Thevenin impedance only: explicit Rg + Lg followed by an ideal source with internal impedance disabled.');
end

%% Wiring and presentation helpers
function addPhysPort(sys,name,side,port,pos)
if strcmpi(side,'Right')
    orientation = 'left';
else
    orientation = 'right';
end
add_block('nesl_utility/Connection Port',[sys '/' name], ...
    'Side',side,'Port',num2str(port),'Position',pos,'Orientation',orientation);
end

function h = innerPort(path)
ph = get_param(path,'PortHandles');
if ~isempty(ph.LConn)
    h = ph.LConn(1);
elseif ~isempty(ph.RConn)
    h = ph.RConn(1);
else
    error('No physical conserving port found on %s',path);
end
end

function connectPhysical(model,src,srcField,srcIndex,dst,dstField,dstIndex,lineName)
s = get_param([model '/' src],'PortHandles');
d = get_param([model '/' dst],'PortHandles');
lh = add_line(model,s.(srcField)(srcIndex),d.(dstField)(dstIndex),'autorouting','on');
set_param(lh,'Name',lineName);
end

function connectSignal(model,src,srcPort,dst,dstPort,lineName)
s = get_param([model '/' src],'PortHandles');
d = get_param([model '/' dst],'PortHandles');
lh = add_line(model,s.Outport(srcPort),d.Inport(dstPort),'autorouting','on');
set_param(lh,'Name',lineName);
end

function addNote(sys,pos,text)
a = Simulink.Annotation(sys,text);
a.Position = pos;
a.FontSize = 10;
a.ForegroundColor = 'blue';
end

function disableSubsystemPreviews(model)
blocks=find_system(model,'LookUnderMasks','all','BlockType','SubSystem');
for k=1:numel(blocks)
    set_param(blocks{k},'ContentPreviewEnabled','off');
end
end

function name = rgbName(rgb)
% Simulink block colors use named colors; choose the nearest intended family.
if rgb(1) > 0.95 && rgb(2) < 0.9
    name = 'orange';
elseif rgb(3) > 0.95 && rgb(2) > 0.9
    name = 'lightBlue';
elseif rgb(2) > 0.95
    name = 'green';
elseif rgb(1) > 0.95
    name = 'yellow';
else
    name = 'white';
end
end
