% Repackage the validated R7 model into a human-readable hierarchical R8.
% Electrical/control behavior is unchanged; only hierarchy, layout and labels change.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
sourceFile=fullfile(projectRoot,'build','BESS_GFM_10kV_Dynamic_R7.slx');
if ~isfile(sourceFile)
    run(fullfile(scriptDir,'build_bess_gfm_dynamic_r7.m'));
end
modelName='BESS_GFM_10kV_Readable_R8';
modelFile=fullfile(projectRoot,'build',[modelName '.slx']);
pngFile=fullfile(projectRoot,'build',[modelName '.png']);
copyfile(sourceFile,modelFile,'f');
load_system(modelFile);open_system(modelName);

% Remove legacy R6 logging; R7 telemetry remains the single authoritative log.
for b={'Result_Mux','GFM_PCS_Results'}
    p=[modelName '/' b{1}];if getSimulinkBlockHandle(p)>0,delete_block(p);end
end

% Names propagate to generated subsystem ports and make signal flow readable.
name_signal([modelName '/Idc_to_Simulink'],1,'Ibat_A');
name_signal([modelName '/Vdc_to_Simulink'],1,'Vdc_V');
name_signal([modelName '/Vbat_to_Simulink'],1,'Vbat_V');
name_signal([modelName '/Battery_DC_Power'],1,'Pbat_W');
name_signal([modelName '/SOC'],1,'SOC_pu');
name_signal([modelName '/P_to_Simulink'],1,'P_ac_W');
name_signal([modelName '/Q_to_Simulink'],1,'Q_ac_var');
name_signal([modelName '/Frequency_Hz'],1,'f_Hz');
name_signal([modelName '/V_Command_Limit'],1,'Vll_cmd_V');
name_signal([modelName '/Modulation_Limit'],1,'modulation_pu');
name_signal([modelName '/Duty_Limit'],1,'duty_pu');
name_signal([modelName '/DC_Current_Limit'],1,'Ibat_ref_A');
name_signal([modelName '/AC_Current_RMS'],1,'Iac_est_A');
name_signal([modelName '/AC_Current_Limit_Saturation'],1,'ac_limit_factor');
name_signal([modelName '/Load_Step_Command'],1,'step_breaker_cmd');
name_signal([modelName '/Time'],1,'time_s');

dcPlant={ ...
    'Battery_OCV','Battery_Current','Battery_Internal_R', ...
    'Battery_Terminal_Voltage','DCDC_Input_Inductor', ...
    'Bidirectional_1200_1500V_DCDC','DC_Link_C','DC_Link_Voltage', ...
    'DC_Negative_Reference','Idc_to_Simulink','Vbat_to_Simulink', ...
    'Vdc_to_Simulink','Battery_DC_Power','SOC_Rate','SOC', ...
    'Solver Configuration'};
dcdcControl={ ...
    'Vdc_Filter','Vdc_For_Modulation','Vdc_Reference','Vdc_Error', ...
    'Vdc_Kp','Vdc_Ki','Vdc_PI_Integrator','P_DC_Feedforward_Filter', ...
    'P_to_Battery_Current_FF','Battery_Current_Reference','DC_Current_Limit', ...
    'Idc_Filter','DC_Current_Error','DC_Current_Kp','DC_Current_Ki', ...
    'DC_Current_PI_Integrator','Duty_Feedforward','Duty_Command_Sum', ...
    'Duty_Limit','Duty_to_PS'};
gfmControl={ ...
    'P_Filter','Q_Filter','P_f_Droop_rad_s','Omega0','Omega_Command', ...
    'Electrical_Angle','Frequency_Droop_Hz','f0_50Hz','Frequency_Hz', ...
    'Q_V_Droop','V0_690V','V_Command_Sum','V_Command_Limit', ...
    'Virtual_Z_Inputs','Virtual_Impedance_dV','AC_Current_Inputs', ...
    'AC_Current_RMS','AC_Current_Limit_Factor','AC_Current_Limit_Saturation', ...
    'Vll_to_Modulation_Numerator','Divide_By_Vdc','Apply_AC_Current_Limit', ...
    'Modulation_Limit','Mod_Inputs','m_a','m_b','m_c','m_abc','Modulation_to_PS'};
acPlant={ ...
    'Bidirectional_Average_VSC','LCL_L1','LCL_L2','LCL_Damped_C', ...
    'Filter_Ground','T_BESS_0p69_10kV','BESS_PQ_Sensor', ...
    'P_to_Simulink','Q_to_Simulink'};
scenario={ ...
    'Adjusted_Island_Load','Step_Load_Breaker','One_MW_Step_Load', ...
    'Load_Step_Command','Load_Step_to_PS'};
monitor={'Time','R7_Result_Mux','R7_Results'};

make_group(modelName,dcPlant,'01 Battery and DC Link');
make_group(modelName,dcdcControl,'02 Bidirectional DC-DC Control');
make_group(modelName,gfmControl,'03 GFM Control and Limits');
make_group(modelName,acPlant,'04 PCS Filter and Transformer');
set_pmio_domain([modelName '/04 PCS Filter and Transformer'],'Conn1', ...
    'foundation.electrical.electrical');
set_pmio_domain([modelName '/04 PCS Filter and Transformer'],'Conn2', ...
    'foundation.electrical.three_phase');
set_pmio_domain([modelName '/04 PCS Filter and Transformer'],'Conn3', ...
    'foundation.electrical.electrical');
make_group(modelName,scenario,'05 Island Load Scenario');
make_group(modelName,monitor,'06 Measurements and Results');

% Harden only after the original R8 module boundaries have been committed.
% This avoids an R2026a graph-edit crash caused by creating subsystems while
% new cross-module branches are still pending in the root diagram.
harden_r8_controls(modelName);

% Replace long top-level Simulink wires by named global signal routes.
% Physical conserving connections stay explicit at the top level.
route_top_level_signals(modelName);

% Minimise subsystem coupling: each plant stays with the controller that
% directly governs it.  The six detailed modules become four top-level
% architectural units while remaining available one level below.
make_group(modelName,{'01 Battery and DC Link','02 Bidirectional DC-DC Control'}, ...
    '01 BESS DC Source');
lock_resolved_pmio_domains([modelName '/01 BESS DC Source']);
make_group(modelName,{'03 GFM Control and Limits','04 PCS Filter and Transformer'}, ...
    '02 GFM PCS and Step-up');
rebuild_final_power_ports(modelName);
repair_solver_configuration(modelName);
set_param([modelName '/05 Island Load Scenario'],'Name','03 Island Load Scenario');
set_param([modelName '/06 Measurements and Results'],'Name','04 Supervision and Results');
% Logging is a sink.  Remove the unused auto-generated output interface.
unusedOut=find_system([modelName '/04 Supervision and Results'], ...
    'SearchDepth',1,'BlockType','Outport');
for k=1:numel(unusedOut),delete_block(unusedOut{k});end

% Stable left-to-right power path; supervisory logging is not in the
% functional control chain.
set_param([modelName '/01 BESS DC Source'], ...
    'Position',[90 190 350 390],'BackgroundColor','[1.0,0.95,0.72]', ...
    'ForegroundColor','black','ShowPortLabels','FromPortIcon', ...
    'AttributesFormatString','Battery + bidirectional DC/DC\n1200 V / 10 MWh -> 1500 Vdc');
set_param([modelName '/02 GFM PCS and Step-up'], ...
    'Position',[500 190 800 390],'BackgroundColor','[0.78,0.90,1.0]', ...
    'ForegroundColor','black','ShowPortLabels','FromPortIcon', ...
    'AttributesFormatString','GFM control + PCS/LCL + transformer\n6.25 MVA, 0.69 / 10 kV');
set_param([modelName '/03 Island Load Scenario'], ...
    'Position',[950 190 1190 390],'BackgroundColor','[0.91,0.84,0.98]', ...
    'ForegroundColor','black','ShowPortLabels','FromPortIcon', ...
    'AttributesFormatString','4 MW base + 1 MW step\nt = 0.30 s');
set_param([modelName '/04 Supervision and Results'], ...
    'Position',[500 540 800 680],'BackgroundColor','[0.90,0.90,0.90]', ...
    'ForegroundColor','black','ShowPortLabels','FromPortIcon', ...
    'AttributesFormatString','Read-only telemetry\ngfm_r7_result (15 channels)');

% Deliberate second-level layout: plant and its local controller are close,
% but the top-level interface remains one physical power port.
set_param([modelName '/01 BESS DC Source/01 Battery and DC Link'], ...
    'Position',[70 100 310 280],'BackgroundColor','[1.0,0.95,0.72]', ...
    'AttributesFormatString','1200 V / 10 MWh\n1500 V DC link');
set_param([modelName '/01 BESS DC Source/02 Bidirectional DC-DC Control'], ...
    'Position',[430 100 700 280],'BackgroundColor','[0.82,0.94,0.80]', ...
    'AttributesFormatString',sprintf([ ...
        'Vdc PI: 10 Hz | Ibat PI: 300 Hz\n' ...
        'Anti-windup + SOC 20-90%% direction interlock']));
set_param([modelName '/02 GFM PCS and Step-up/03 GFM Control and Limits'], ...
    'Position',[70 100 360 300],'BackgroundColor','[0.78,0.90,1.0]', ...
    'AttributesFormatString','P-f / Q-V / Virtual Z\nAC limit: 1.20 pu');
set_param([modelName '/02 GFM PCS and Step-up/04 PCS Filter and Transformer'], ...
    'Position',[480 100 760 300],'BackgroundColor','[1.0,0.86,0.70]', ...
    'AttributesFormatString','6.25 MVA PCS + LCL\n0.69 / 10 kV transformer');

% Arrange internals and use consistent subsystem canvas styling.
groups={'01 BESS DC Source', ...
    '01 BESS DC Source/01 Battery and DC Link', ...
    '01 BESS DC Source/02 Bidirectional DC-DC Control', ...
    '02 GFM PCS and Step-up', ...
    '02 GFM PCS and Step-up/03 GFM Control and Limits', ...
    '02 GFM PCS and Step-up/04 PCS Filter and Transformer', ...
    '03 Island Load Scenario','04 Supervision and Results'};
for k=1:numel(groups)
    sys=[modelName '/' groups{k}];
    try,Simulink.BlockDiagram.arrangeSystem(sys,'FullLayout','true');catch,end
    set_param(sys,'ScreenColor','white');
    try,set_param(sys,'ContentPreviewEnabled','off');catch,end
end
try,hilite_system(modelName,'none');catch,end

% Top-level engineering title and reading guide.
anns=find_system(modelName,'FindAll','on','Type','annotation');
for k=1:numel(anns),delete(anns(k));end
titleNote=Simulink.Annotation(modelName,sprintf([ ...
    'BESS-GFM 5 MW / 10 MWh — Human-readable hierarchy (R8)\n' ...
    'Power path: BESS DC Source  ->  GFM PCS + Step-up  ->  10 kV Island Load\n' ...
    'Boundary rule: each plant is packaged with its local controller; PV/Wind not included']));
titleNote.Position=[80 40 1160 125];titleNote.FontSize=16;titleNote.FontWeight='bold';
guide=Simulink.Annotation(modelName,sprintf([ ...
    'How to read: top level shows only power-domain boundaries; double-click for detailed modules.\n' ...
    'Blue lines = explicit Simscape power network; named Goto/From routes carry control and telemetry.\n' ...
    'Main interfaces: Vdc_V, Ibat_A, P_ac_W, Q_ac_var, duty_pu, modulation_pu.\n' ...
    'Protection: PI back-calculation anti-windup; SOC limits block only the forbidden power direction.\n' ...
    'Validated scenario: 4 MW -> 5 MW at 0.30 s; strict 4500 A current limiting and SOC direction interlock enabled.']));
guide.Position=[80 760 1200 875];guide.FontSize=11;

set_param(modelName,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_bess_gfm_dynamic_r7.m'));" );
set_param(modelName,'Location',[80 80 1450 920]);
set_param(modelName,'ZoomFactor','FitSystem');
save_system(modelName,modelFile);
set_param(modelName,'SimulationCommand','update');
fprintf('BESS_GFM_READABLE_R8_UPDATE_OK=1\n');
try,print(['-s' modelName],'-dpng',pngFile);catch ME,fprintf('%s\n',ME.message);end
for k=1:numel(groups)
    childPng=fullfile(projectRoot,'build',sprintf('R8_%02d_%s.png',k, ...
        regexprep(groups{k},'[^A-Za-z0-9]+','_')));
    try,print(['-s' modelName '/' groups{k}],'-dpng',childPng);catch,end
end
save_system(modelName,modelFile);close_system(modelName,0);
fprintf('BESS_GFM_READABLE_R8_MODEL=%s\n',modelFile);

function harden_r8_controls(model)
% Add protection without changing the validated unsaturated control law.
plant=[model '/01 Battery and DC Link'];
ctrl=[model '/02 Bidirectional DC-DC Control'];

% Route SOC by name so the plant/controller boundary gains no extra
% top-level wire or architectural port.
add_block('simulink/Signal Routing/Goto',[plant '/SOC Protection Route'], ...
    'GotoTag','R8_SOC_FOR_PROTECTION','TagVisibility','global', ...
    'ShowName','off','Position',[930 410 995 430]);
add_line(plant,'SOC/1','SOC Protection Route/1','autorouting','on');
add_block('simulink/Signal Routing/From',[ctrl '/SOC Protection Route'], ...
    'GotoTag','R8_SOC_FOR_PROTECTION','ShowName','off', ...
    'Position',[1030 755 1110 775]);

% Keep the hardware current limit, then add SOC-dependent dynamic limits.
set_param([ctrl '/DC_Current_Limit'],'Name','Hardware_Current_Limit');
clear_input_line([ctrl '/DC_Current_Error'],1);
add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
    [ctrl '/SOC_Discharge_Allowed'],'Position',[1160 745 1280 780], ...
    'relop','>','const','G.bess.SOC_min');
add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
    [ctrl '/SOC_Charge_Allowed'],'Position',[1160 800 1280 835], ...
    'relop','<','const','G.bess.SOC_max');
add_block('simulink/Math Operations/Gain', ...
    [ctrl '/Discharge_Current_Limit'],'Position',[1320 745 1430 780], ...
    'Gain','G.dcdc.Iref_limit_A');
add_block('simulink/Math Operations/Gain', ...
    [ctrl '/Charge_Current_Limit'],'Position',[1320 800 1430 835], ...
    'Gain','-G.dcdc.Iref_limit_A');
add_block('simulink/Discontinuities/Saturation Dynamic', ...
    [ctrl '/DC_Current_Limit'],'Position',[1480 735 1580 825]);
add_line(ctrl,'SOC Protection Route/1','SOC_Discharge_Allowed/1','autorouting','on');
add_line(ctrl,'SOC Protection Route/1','SOC_Charge_Allowed/1','autorouting','on');
add_line(ctrl,'SOC_Discharge_Allowed/1','Discharge_Current_Limit/1','autorouting','on');
add_line(ctrl,'SOC_Charge_Allowed/1','Charge_Current_Limit/1','autorouting','on');
% Saturation Dynamic port order is: upper limit, signal, lower limit.
add_line(ctrl,'Discharge_Current_Limit/1','DC_Current_Limit/1','autorouting','on');
add_line(ctrl,'Hardware_Current_Limit/1','DC_Current_Limit/2','autorouting','on');
add_line(ctrl,'Charge_Current_Limit/1','DC_Current_Limit/3','autorouting','on');
add_line(ctrl,'DC_Current_Limit/1','DC_Current_Error/1','autorouting','on');
reroute_outport(ctrl,'Hardware_Current_Limit','DC_Current_Limit');

% Outer voltage-loop back-calculation: xdot = Ki*e + Kaw*(sat-unsat).
clear_input_line([ctrl '/Vdc_PI_Integrator'],1);
add_block('simulink/Math Operations/Sum',[ctrl '/Vdc_AW_Error'], ...
    'Position',[1600 745 1630 795],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[ctrl '/Vdc_AW_Gain'], ...
    'Position',[1670 750 1760 785],'Gain','G.dcdc.Kaw_v_per_s');
add_block('simulink/Math Operations/Sum',[ctrl '/Vdc_Integrator_Input'], ...
    'Position',[1800 735 1830 785],'Inputs','++');
add_line(ctrl,'DC_Current_Limit/1','Vdc_AW_Error/1','autorouting','on');
add_line(ctrl,'Battery_Current_Reference/1','Vdc_AW_Error/2','autorouting','on');
add_line(ctrl,'Vdc_AW_Error/1','Vdc_AW_Gain/1','autorouting','on');
add_line(ctrl,'Vdc_Ki/1','Vdc_Integrator_Input/1','autorouting','on');
add_line(ctrl,'Vdc_AW_Gain/1','Vdc_Integrator_Input/2','autorouting','on');
add_line(ctrl,'Vdc_Integrator_Input/1','Vdc_PI_Integrator/1','autorouting','on');

% Inner current-loop back-calculation around the duty-ratio saturation.
clear_input_line([ctrl '/DC_Current_PI_Integrator'],1);
add_block('simulink/Math Operations/Sum',[ctrl '/Duty_AW_Error'], ...
    'Position',[1600 850 1630 900],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[ctrl '/Duty_AW_Gain'], ...
    'Position',[1670 855 1760 890],'Gain','G.dcdc.Kaw_i_per_s');
add_block('simulink/Math Operations/Sum',[ctrl '/Duty_Integrator_Input'], ...
    'Position',[1800 840 1830 890],'Inputs','++');
add_line(ctrl,'Duty_Limit/1','Duty_AW_Error/1','autorouting','on');
add_line(ctrl,'Duty_Command_Sum/1','Duty_AW_Error/2','autorouting','on');
add_line(ctrl,'Duty_AW_Error/1','Duty_AW_Gain/1','autorouting','on');
add_line(ctrl,'DC_Current_Ki/1','Duty_Integrator_Input/1','autorouting','on');
add_line(ctrl,'Duty_AW_Gain/1','Duty_Integrator_Input/2','autorouting','on');
add_line(ctrl,'Duty_Integrator_Input/1','DC_Current_PI_Integrator/1','autorouting','on');
end

function reroute_outport(sys,oldSource,newSource)
oldPH=get_param([sys '/' oldSource],'PortHandles');
newPH=get_param([sys '/' newSource],'PortHandles');
outs=find_system(sys,'SearchDepth',1,'BlockType','Outport');
for k=1:numel(outs)
    ph=get_param(outs{k},'PortHandles');line=get_param(ph.Inport,'Line');
    if line>0 && get_param(line,'SrcPortHandle')==oldPH.Outport(1)
        delete_line(line);
        add_line(sys,newPH.Outport(1),ph.Inport,'autorouting','on');
    end
end
end

function rebuild_final_power_ports(model)
% createSubsystem can lose mixed scalar/three-phase PMIO typing when a
% second hierarchy level is created.  Rebuild the final architectural
% interfaces explicitly: two scalar DC conductors and one three-phase PCC.
delete_all_root_lines(model);
bess=[model '/01 BESS DC Source'];
assert(getSimulinkBlockHandle([bess '/Conn1'])>0 && ...
    getSimulinkBlockHandle([bess '/Conn2'])>0, ...
    'BESS DC interface was not generated as two ports.');
set_param([bess '/Conn1'],'Name','DC_Positive','Side','Right', ...
    'Position',[720 100 750 130]);
set_param([bess '/Conn2'],'Name','DC_Negative','Side','Right', ...
    'Position',[720 190 750 220]);
ports=find_system(bess,'SearchDepth',1,'BlockType','PMIOPort');
for k=1:numel(ports)
    if ~any(strcmp(get_param(ports{k},'Name'),{'DC_Positive','DC_Negative'}))
        delete_block(ports{k});
    end
end

pcs=[model '/02 GFM PCS and Step-up'];
plant=[pcs '/04 PCS Filter and Transformer'];
delete_pmio_ports(pcs);
pp=get_param(plant,'PortHandles');
clear_port_line(pp.RConn(1));
clear_port_line(pp.RConn(2));
clear_port_line(pp.RConn(3));
add_pmio(pcs,'DC_Positive',1,'Left','foundation.electrical.electrical',[20 80 50 110]);
add_pmio(pcs,'DC_Negative',2,'Left','foundation.electrical.electrical',[20 145 50 175]);
add_pmio(pcs,'PCC_10kV',3,'Right','foundation.electrical.three_phase',[800 230 830 260]);
connect_pmio(pcs,pp.RConn(1),'DC_Positive');
connect_pmio(pcs,pp.RConn(3),'DC_Negative');
connect_pmio(pcs,pp.RConn(2),'PCC_10kV');

scenario=[model '/05 Island Load Scenario'];
delete_pmio_ports(scenario);
base=get_param([scenario '/Adjusted_Island_Load'],'PortHandles');
breaker=get_param([scenario '/Step_Load_Breaker'],'PortHandles');
clear_port_line(base.LConn(1));
clear_port_line(breaker.LConn(2));
add_pmio(scenario,'PCC_10kV',1,'Left','foundation.electrical.three_phase',[20 180 50 210]);
pcc=pmio_handle([scenario '/PCC_10kV']);
add_line(scenario,pcc,base.LConn(1),'autorouting','on');
add_line(scenario,base.LConn(1),breaker.LConn(2),'autorouting','on');

% Recreate the three deliberate top-level power connections.
bessPH=get_param(bess,'PortHandles');
pcsPH=get_param(pcs,'PortHandles');
loadPH=get_param(scenario,'PortHandles');
add_line(model,bessPH.RConn(1),pcsPH.LConn(1),'autorouting','off');
add_line(model,bessPH.RConn(2),pcsPH.LConn(2),'autorouting','off');
add_line(model,pcsPH.RConn(1),loadPH.LConn(1),'autorouting','off');
end

function delete_all_root_lines(model)
% At this stage every control/telemetry crossing has already become a
% named Goto/From route.  Root-level lines are therefore only the physical
% connections generated by hierarchy creation, which are rebuilt below.
while true
    lines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line');
    if isempty(lines),break;end
    try
        delete_line(lines(1));
    catch
        % A branch deletion can invalidate sibling handles; rescan.
        try,delete(lines(1));catch,end
    end
end
end

function repair_solver_configuration(model)
% The Solver Configuration belongs on the scalar DC negative network.
% Automatic mixed-domain packaging can reconnect it to a generated
% three-phase PMIO segment, so restore the deliberate R7 connection.
plant=[model '/01 BESS DC Source/01 Battery and DC Link'];
solver=get_param([plant '/Solver Configuration'],'PortHandles');
reference=get_param([plant '/DC_Negative_Reference'],'PortHandles');
clear_port_line(solver.RConn(1));
add_line(plant,reference.LConn(1),solver.RConn(1),'autorouting','on');
end

function delete_pmio_ports(sys)
ports=find_system(sys,'SearchDepth',1,'BlockType','PMIOPort');
for k=1:numel(ports),delete_block(ports{k});end
end

function clear_port_line(port)
line=get_param(port,'Line');
if line>0
    try,delete_line(line);catch,end
end
end

function add_pmio(sys,name,port,side,domain,pos)
add_block('built-in/PMIOPort',[sys '/' name], ...
    'Port',num2str(port),'Side',side, ...
    'ConnectionType',['Connection: ' domain],'Position',pos);
end

function connect_pmio(sys,source,name)
add_line(sys,source,pmio_handle([sys '/' name]),'autorouting','on');
end

function h=pmio_handle(block)
ph=get_param(block,'PortHandles');h=[ph.LConn ph.RConn];
assert(numel(h)==1,'Expected one conserving handle on %s.',block);
end

function set_pmio_domain(sys,name,domain)
block=[sys '/' name];
assert(getSimulinkBlockHandle(block)>0,'Missing connection port: %s',block);
set_param(block,'ConnectionType',['Connection: ' domain]);
end

function lock_resolved_pmio_domains(sys)
% Freeze every already-resolved conserving-port domain before another
% hierarchy transaction can force Simulink to infer it across two levels.
ports=find_system(sys,'SearchDepth',1,'BlockType','PMIOPort');
for k=1:numel(ports)
    ph=get_param(ports{k},'PortHandles');handles=[ph.LConn ph.RConn];
    if isempty(handles),continue;end
    runtime=string(get_param(handles(1),'ConnectionType'));
    prefix="network_engine_domain.";
    if startsWith(runtime,prefix)
        domain=extractAfter(runtime,strlength(prefix));
        if startsWith(domain,"foundation.")
            set_param(ports{k},'ConnectionType',['Connection: ' char(domain)]);
        end
    end
end
end

function make_group(model,blocks,name)
paths=cellfun(@(x)[model '/' x],blocks,'UniformOutput',false);
h=zeros(1,numel(paths));
for k=1:numel(paths)
    h(k)=getSimulinkBlockHandle(paths{k});
    assert(h(k)>0,'Missing block for hierarchy: %s',paths{k});
end
Simulink.BlockDiagram.createSubsystem(h,'Name',name,'MakeNameUnique','off');
% Save each hierarchy transaction, but do not close/reload the diagram here.
% R2026a Update 4 can dereference stale line segments while close_system
% destroys a just-edited graph.  Final PMIO domains are rebuilt explicitly.
fileName=get_param(model,'FileName');
save_system(model,fileName);
end

function clear_input_line(block,index)
p=get_param(block,'PortHandles');h=get_param(p.Inport(index),'Line');
if h>0,delete_line(h);end
end

function route_top_level_signals(model)
% Convert every ordinary Simulink line between top-level subsystems into a
% named global Goto/From route placed inside the corresponding subsystem.
lines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line');
routes=struct('src',{},'srcParent',{},'srcPort',{},'tag',{},'dst',{});
for k=1:numel(lines)
    lineH=lines(k);
    src=get_param(lineH,'SrcPortHandle');
    if isempty(src)||src<0||~strcmp(get_param(src,'PortType'),'outport'),continue;end
    dst=get_param(lineH,'DstPortHandle');
    if isempty(dst),continue;end
    srcParent=get_param(src,'Parent');
    if strcmp(srcParent,model),continue;end
    srcPort=as_number(get_param(src,'PortNumber'));
    idx=find([routes.src]==src,1);
    if isempty(idx)
        label=get_param(lineH,'Name');
        if isempty(label),label='signal';end
        parentKey=regexprep(get_param(srcParent,'Name'),'[^A-Za-z0-9]','_');
        tag=sprintf('R8_%s_p%d_%s',parentKey,srcPort, ...
            regexprep(label,'[^A-Za-z0-9_]','_'));
        idx=numel(routes)+1;
        routes(idx)=struct('src',src,'srcParent',srcParent, ...
            'srcPort',srcPort,'tag',tag,'dst',dst(:).');
    else
        routes(idx).dst=unique([routes(idx).dst dst(:).'],'stable');
    end
end

% Work from highest port number down so deleting a generated port cannot
% renumber a port that has not yet been handled.
if isempty(routes),return;end
% Remove only the identified ordinary Simulink lines while all subsystem
% signal ports still exist.  Never infer/delete Simscape connection
% segments from missing ordinary source handles.
for k=1:numel(routes)
    try
        topLine=get_param(routes(k).src,'Line');
        if topLine>0,delete_line(topLine);end
    catch
    end
end
keys=arrayfun(@(r)sprintf('%s|%08d',r.srcParent,999999-r.srcPort), ...
    routes,'UniformOutput',false);
[~,order]=sort(keys);
routes=routes(order);
for k=1:numel(routes)
    r=routes(k);
    outBlock=find_port_block(r.srcParent,'Outport',r.srcPort);
    if ~isempty(outBlock)
        pos=get_param(outBlock,'Position');
        ph=get_param(outBlock,'PortHandles');
        inLine=get_param(ph.Inport,'Line');
        inSrc=-1;
        if inLine>0,inSrc=get_param(inLine,'SrcPortHandle');end
        delete_block(outBlock);
        goto=[r.srcParent '/route_' r.tag];
        add_block('simulink/Signal Routing/Goto',goto,'GotoTag',r.tag, ...
            'TagVisibility','global','ShowName','off','Position',pos);
        if inSrc>0
            gp=get_param(goto,'PortHandles');
            % Simulink can preserve/reconnect the line when a replacement
            % block occupies the former Outport position.
            if get_param(gp.Inport,'Line')<0
                add_line(r.srcParent,inSrc,gp.Inport,'autorouting','on');
            end
        end
    end
end

% Snapshot destination mappings, then again delete ports in descending order.
dest=struct('parent',{},'port',{},'tag',{});
for k=1:numel(routes)
    for j=1:numel(routes(k).dst)
        d=routes(k).dst(j);
        if d<0||~strcmp(get_param(d,'PortType'),'inport'),continue;end
        dstParent=get_param(d,'Parent');
        if strcmp(dstParent,model),continue;end
        dstPort=as_number(get_param(d,'PortNumber'));
        dest(end+1)=struct('parent',dstParent,'port',dstPort, ...
            'tag',routes(k).tag); %#ok<AGROW>
    end
end
keys=arrayfun(@(d)sprintf('%s|%08d',d.parent,999999-d.port),dest, ...
    'UniformOutput',false);
[~,order]=sort(keys);dest=dest(order);
for k=1:numel(dest)
        d=dest(k);
        inBlock=find_port_block(d.parent,'Inport',d.port);
        if isempty(inBlock),continue;end
        pos=get_param(inBlock,'Position');
        ph=get_param(inBlock,'PortHandles');
        outLine=get_param(ph.Outport,'Line');
        internalDst=[];
        if outLine>0,internalDst=get_param(outLine,'DstPortHandle');end
        delete_block(inBlock);
        from=[d.parent '/route_' d.tag];
        if getSimulinkBlockHandle(from)>0
            from=[from '_' num2str(d.port)];
        end
        add_block('simulink/Signal Routing/From',from,'GotoTag',d.tag, ...
            'ShowName','off','Position',pos);
        fp=get_param(from,'PortHandles');
        for q=1:numel(internalDst)
            if internalDst(q)>0 && get_param(internalDst(q),'Line')<0
                add_line(d.parent,fp.Outport,internalDst(q),'autorouting','on');
            end
        end
end
end

function b=find_port_block(parent,blockType,portNo)
b=find_system(parent,'SearchDepth',1,'BlockType',blockType);
keep=false(size(b));
for n=1:numel(b),keep(n)=as_number(get_param(b{n},'Port'))==portNo;end
b=b(keep);
if isempty(b),b=[];else,b=b{1};end
end
function x=as_number(v)
if isnumeric(v),x=double(v);else,x=str2double(v);end
end
function name_signal(block,port,name)
p=get_param(block,'PortHandles');
if numel(p.Outport)>=port
    h=get_param(p.Outport(port),'Line');
    if h>0,set_param(h,'Name',name);end
end
end
