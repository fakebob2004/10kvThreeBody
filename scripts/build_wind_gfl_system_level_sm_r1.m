% Derive a standalone Wind-GFL commissioning model without modifying R2.1.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
source=fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx');
model='Wind_GFL_5MW_SystemLevel_SM_R1';
modelFile=fullfile(root,'build',[model '.slx']);
assert(isfile(source),'Accepted PV-GFL R2.1 source model is missing.');
copyfile(source,modelFile,'f');load_system(modelFile);
run(fullfile(scriptDir,'init_wind_gfl_system_level_sm_r1.m'));

oldBranch=[model '/01 PV-GFL Branch R2.1'];
set_param(oldBranch,'Name','01 Wind-GFL System-Level Branch');
branch=[model '/01 Wind-GFL System-Level Branch'];
set_param([branch '/01 GFL PCS'],'Name','03 GFL PCS');
set_param([branch '/02 Step-up and PCC'],'Name','04 Step-up and PCC');
set_param([branch '/CommandBus'],'Name','WindCommandBus');

% Rename branch-local scoped routes; no tag leaves the branch boundary.
tagBlocks=find_system(branch,'LookUnderMasks','all','FollowLinks','on','RegExp','on', ...
    'BlockType','(Goto|From|GotoTagVisibility)');
for k=1:numel(tagBlocks)
    try
        tag=get_param(tagBlocks{k},'GotoTag');
        if startsWith(tag,'R21_'),set_param(tagBlocks{k},'GotoTag',strrep(tag,'R21_','WIND1_'));end
    catch
    end
end
for old={'scope_R21_CurrentCommandBus','scope_R21_PCCMeasurementBus','scope_R21_PrimaryMeasurementBus'}
    p=[branch '/' old{1}];
    if getSimulinkBlockHandle(p)>0
        set_param(p,'Name',strrep(old{1},'R21_','WIND1_'));
    end
end

% Break the inherited external command-to-PCS connection.
pcs=[branch '/03 GFL PCS'];
ph=get_param(pcs,'PortHandles');ln=get_param(ph.Inport(1),'Line');if ln>0,delete_line(ln);end
% Avoid variable-step event chattering exactly on the PLL frequency clamp;
% the saturation values remain unchanged and are still validated dynamically.
set_param([pcs '/01 Secondary Control/02 Local SRF-PLL/Omega Limits'],'ZeroCross','off');
cleanup_unconnected_outports([pcs '/01 Secondary Control']);
cleanup_unused_parent_outputs([pcs '/01 Secondary Control']);
remove_disconnected_lines(pcs);
set_param([branch '/04 Step-up and PCC/T_PV_0p69_10kV'],'Name','T_Wind_0p69_10kV');
set_param([branch '/04 Step-up and PCC/PV PCC Power Sensor'],'Name','Wind PCC Power Sensor');

% 01 Aerodynamic/MPPT abstraction: clamps available and dispatch powers and
% exports one compact source bus.  It is explicitly replaceable by a full
% turbine/MPPT implementation with the same bus contract.
aero=[branch '/01 Aerodynamic and MPPT Available Power'];
add_block('simulink/Ports & Subsystems/Subsystem',aero,'Position',[180 300 365 390]);
clear_subsystem(aero);
add_block('simulink/Ports & Subsystems/In1',[aero '/WindCommandBus'],'Position',[25 82 55 98]);
add_block('simulink/Signal Routing/Demux',[aero '/Command Selector'], ...
    'Outputs','4','Position',[90 40 95 155]);
add_block('simulink/Discontinuities/Saturation',[aero '/Available Power Limit'], ...
    'UpperLimit','W1.wind.P_rated_W','LowerLimit','0','Position',[130 30 240 60]);
add_block('simulink/Continuous/Transfer Fcn',[aero '/Mechanical Power Response'], ...
    'Numerator','1','Denominator','[W1.wind.mechanical_tau_s 1]', ...
    'Position',[255 25 350 65]);
add_block('simulink/Discontinuities/Saturation',[aero '/Dispatch Power Limit'], ...
    'UpperLimit','W1.wind.P_rated_W','LowerLimit','0','Position',[130 70 240 100]);
add_block('simulink/Discontinuities/Saturation',[aero '/Enable Clamp'], ...
    'UpperLimit','1','LowerLimit','0','Position',[145 150 225 180]);
add_block('simulink/Signal Routing/Mux',[aero '/WindSourceBus'], ...
    'Inputs','4','Position',[390 45 395 165]);
add_block('simulink/Ports & Subsystems/Out1',[aero '/WindSourceBus Out'], ...
    'Position',[440 98 470 112]);
add_line(aero,'WindCommandBus/1','Command Selector/1');
add_line(aero,'Command Selector/1','Available Power Limit/1');
add_line(aero,'Command Selector/2','Dispatch Power Limit/1');
add_line(aero,'Command Selector/3','WindSourceBus/3');
add_line(aero,'Command Selector/4','Enable Clamp/1');
add_line(aero,'Available Power Limit/1','Mechanical Power Response/1');
add_line(aero,'Mechanical Power Response/1','WindSourceBus/1');
add_line(aero,'Dispatch Power Limit/1','WindSourceBus/2');
add_line(aero,'Enable Clamp/1','WindSourceBus/4');
add_line(aero,'WindSourceBus/1','WindSourceBus Out/1');
set_param(aero,'BackgroundColor','[0.84,0.94,0.82]');

% 02 MSC/DC abstraction: min(Pavailable,Pdispatch), physical ramp limit and
% aggregate energy-buffer lag.  The second output is one compact diagnostic
% bus, avoiding multiple cross-layer wires.
msc=[branch '/02 DC Energy Buffer and MSC Equivalent'];
add_block('simulink/Ports & Subsystems/Subsystem',msc,'Position',[410 290 545 400]);
clear_subsystem(msc);
add_block('simulink/Ports & Subsystems/In1',[msc '/WindSourceBus'],'Position',[25 92 55 108]);
add_block('simulink/Signal Routing/Demux',[msc '/Source Selector'], ...
    'Outputs','4','Position',[85 35 90 165]);
add_block('simulink/Math Operations/MinMax',[msc '/Available versus Dispatch'], ...
    'Function','min','Inputs','2','Position',[130 40 185 85]);
add_block('simulink/Discontinuities/Rate Limiter',[msc '/MSC Power Ramp'], ...
    'RisingSlewLimit','W1.wind.source_ramp_up_Wps', ...
    'FallingSlewLimit','W1.wind.source_ramp_down_Wps','Position',[220 45 315 80]);
add_block('simulink/Continuous/Transfer Fcn',[msc '/DC Energy Buffer'], ...
    'Numerator','1','Denominator','[W1.dc.buffer_tau_s 1]','Position',[350 45 450 80]);
add_block('simulink/Signal Routing/Mux',[msc '/PCS CommandBus'], ...
    'Inputs','3','Position',[490 45 495 140]);
add_block('simulink/Signal Routing/Mux',[msc '/Source StatusBus'], ...
    'Inputs','5','Position',[435 120 440 245]);
add_block('simulink/Math Operations/Sum',[msc '/DC Power Imbalance'], ...
    'Inputs','+-','Position',[350 245 380 295]);
add_block('simulink/Continuous/Integrator',[msc '/DC Energy Delta'], ...
    'InitialCondition','0','Position',[410 250 440 280]);
add_block('simulink/Math Operations/Bias',[msc '/Nominal DC Energy'], ...
    'Bias','W1.dc.energy_buffer_J','Position',[470 250 550 280]);
add_block('simulink/User-Defined Functions/Fcn',[msc '/DC Voltage from Energy'], ...
    'Expr','sqrt(abs(2*u/W1.dc.C_equiv_F))','Position',[575 250 710 285]);
add_block('simulink/Math Operations/Gain',[msc '/MPPT Capture pu'], ...
    'Gain','1/W1.wind.P_rated_W','Position',[350 210 435 240]);
add_block('simulink/Ports & Subsystems/Out1',[msc '/PCS CommandBus Out'], ...
    'Position',[545 82 575 98]);
add_block('simulink/Ports & Subsystems/Out1',[msc '/Source StatusBus Out'], ...
    'Position',[545 167 575 183],'Port','2');
add_line(msc,'WindSourceBus/1','Source Selector/1');
add_line(msc,'Source Selector/1','Available versus Dispatch/1');
add_line(msc,'Source Selector/2','Available versus Dispatch/2');
add_line(msc,'Available versus Dispatch/1','MSC Power Ramp/1');
add_line(msc,'MSC Power Ramp/1','DC Energy Buffer/1');
add_line(msc,'DC Energy Buffer/1','PCS CommandBus/1');
add_line(msc,'Source Selector/3','PCS CommandBus/2');
add_line(msc,'Source Selector/4','PCS CommandBus/3');
add_line(msc,'PCS CommandBus/1','PCS CommandBus Out/1');
add_line(msc,'Source Selector/1','Source StatusBus/1');
add_line(msc,'Source Selector/2','Source StatusBus/2');
add_line(msc,'DC Energy Buffer/1','Source StatusBus/3');
add_line(msc,'Available versus Dispatch/1','DC Power Imbalance/1');
add_line(msc,'DC Energy Buffer/1','DC Power Imbalance/2');
add_line(msc,'DC Power Imbalance/1','DC Energy Delta/1');
add_line(msc,'DC Energy Delta/1','Nominal DC Energy/1');
add_line(msc,'Nominal DC Energy/1','DC Voltage from Energy/1');
add_line(msc,'DC Voltage from Energy/1','Source StatusBus/4');
add_line(msc,'Source Selector/1','MPPT Capture pu/1');
add_line(msc,'MPPT Capture pu/1','Source StatusBus/5');
add_line(msc,'Source StatusBus/1','Source StatusBus Out/1');
set_param(msc,'BackgroundColor','[0.96,0.91,0.76]');

% Wire the four internal power-domain layers.  Only two vector signals cross
% the source layers: PCS CommandBus and Source StatusBus.
add_line(branch,'WindCommandBus/1','01 Aerodynamic and MPPT Available Power/1','autorouting','on');
add_line(branch,'01 Aerodynamic and MPPT Available Power/1','02 DC Energy Buffer and MSC Equivalent/1','autorouting','on');
add_line(branch,'02 DC Energy Buffer and MSC Equivalent/1','03 GFL PCS/1','autorouting','on');

% Append three source-layer channels to the accepted 16-channel PCS status.
outPH=get_param([branch '/StatusBus'],'PortHandles');ln=get_param(outPH.Inport(1),'Line');if ln>0,delete_line(ln);end
add_block('simulink/Signal Routing/Mux',[branch '/Wind StatusBus Elements'], ...
    'Inputs','2','Position',[1050 410 1055 485]);
add_line(branch,'03 GFL PCS/1','Wind StatusBus Elements/1','autorouting','on');
add_line(branch,'02 DC Energy Buffer and MSC Equivalent/2','Wind StatusBus Elements/2','autorouting','on');
add_line(branch,'Wind StatusBus Elements/1','StatusBus/1','autorouting','on');

% Rebuild the external profile as [Pavailable,Pdispatch,Q,enable].
oldProfile=[model '/02 Commissioning Command Profile'];
set_param(oldProfile,'Name','02 Wind Commissioning Command Profile');
profile=[model '/02 Wind Commissioning Command Profile'];
mux=[profile '/CommandBus'];mph=get_param(mux,'PortHandles');
for h=mph.Inport(:).',ln=get_param(h,'Line');if ln>0,delete_line(ln);end,end
set_param(mux,'Inputs','4','Name','WindCommandBus');
add_block('simulink/Sources/Constant',[profile '/P Available Base'], ...
    'Value','W1.command.P_available_base_W','Position',[20 235 100 265]);
add_block('simulink/Sources/Step',[profile '/P Available Increment'], ...
    'Time','W1.command.P_available_step_time_s','Before','0', ...
    'After','W1.command.P_available_step_W','Position',[20 280 100 310]);
add_block('simulink/Math Operations/Sum',[profile '/P Available'], ...
    'Inputs','++','Position',[145 245 175 305]);
add_line(profile,'P Available Base/1','P Available/1');
add_line(profile,'P Available Increment/1','P Available/2');
add_line(profile,'P Available/1','WindCommandBus/1');
add_line(profile,'P Command/1','WindCommandBus/2');
add_line(profile,'Q Command/1','WindCommandBus/3');
add_line(profile,'Enable/1','WindCommandBus/4');

% Wind-specific command expressions; retained inherited soft-start is the
% commissioning dispatch ramp and not an aerodynamic model.
set_param([profile '/P Base Limit'],'UpperLimit','W1.command.P_dispatch_base_W');
set_param([profile '/P Increment'],'Time','W1.command.P_dispatch_step_time_s', ...
    'After','W1.command.P_dispatch_step_W');
set_param([profile '/Q Base Command'],'Value','W1.command.Q_base_var');
set_param([profile '/Q Increment'],'Time','W1.command.Q_step_time_s','After','W1.command.Q_step_var');
set_param([profile '/Enable Off'],'Time','W1.command.enable_off_time_s', ...
    'After','-W1.command.enable_drop');
set_param([profile '/Enable On'],'Time','W1.command.enable_on_time_s', ...
    'After','W1.command.enable_drop');

rec=[model '/03 StatusBus Recorder'];
set_param(rec,'Name','03 Wind StatusBus Recorder','VariableName','wind_gfl_status');
rec=[model '/03 Wind StatusBus Recorder'];
set_param(model,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_wind_gfl_system_level_sm_r1.m'));" );

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'Wind-GFL R1 standalone commissioning — 5 MW / 6.25 MVA, 690 V / 10 kV, 50 Hz\n' ...
    'WindCommandBus [Pavailable,Pdispatch,Q,enable] | PCC_10kV | StatusBus (21 channels)\n' ...
    'Local Wind PCC PLL; average system-level PCS. Source layers can be replaced by turbine+PMSG+MSC+DC without changing external ports.']));
a.Position=[45 20 1390 115];a.FontSize=14;a.FontWeight='bold';

% Explicit readable placement at the wind branch owner level.
set_param([branch '/WindCommandBus'],'Position',[25 340 55 354]);
set_param(aero,'Position',[115 300 330 395]);
set_param(msc,'Position',[385 295 585 400]);
set_param(pcs,'Position',[650 290 780 405]);
set_param([branch '/04 Step-up and PCC'],'Position',[865 300 1015 390]);
set_param([branch '/PCC_10kV'],'Position',[1105 320 1135 350]);
set_param([branch '/Wind StatusBus Elements'],'Position',[870 465 875 540]);
set_param([branch '/StatusBus'],'Position',[1105 495 1135 509]);
scopeNames={'scope_WIND1_PrimaryMeasurementBus','scope_WIND1_PCCMeasurementBus', ...
    'scope_WIND1_CurrentCommandBus'};
for k=1:numel(scopeNames)
    set_param([branch '/' scopeNames{k}],'Position',[20 430+30*(k-1) 205 450+30*(k-1)], ...
        'ShowName','off','FontSize','8');
end
set_param([pcs '/CommandBus'],'Position',[25 105 55 119]);
set_param([pcs '/01 Secondary Control'],'Position',[170 65 355 205]);
set_param([pcs '/02 Primary Converter and Filter'],'Position',[420 220 595 350]);
set_param([pcs '/AC_690V'],'Position',[675 270 705 300]);
set_param([pcs '/StatusBus'],'Position',[675 105 705 119]);
set_param(branch,'BackgroundColor','[0.91,0.95,1.00]');
set_param(branch,'AttributesFormatString',sprintf([ ...
    '5 MW / 6.25 MVA | 690 V / 10 kV\n' ...
    'Local PCC PLL + P/Q-to-dq current command\n' ...
    'Average PCS; full turbine/PMSG replacement boundary retained']));
set_param(profile,'AttributesFormatString',sprintf([ ...
    'WindCommandBus = [Pavailable, Pdispatch, Q, enable]\n' ...
    'standalone commissioning scenario only']));

% Remove stale physical line fragments inherited from the source copy.  A
% fragment is deleted only when it has no source, no destination and reports
% Connected=off; the valid Simscape branch segments report Connected=on.
topLines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line');
for h=topLines(:).'
    try
        if get_param(h,'SrcPortHandle')==-1 && all(get_param(h,'DstPortHandle')==-1) ...
                && strcmp(get_param(h,'Connected'),'off')
            delete_line(h);
        end
    catch
        % Deleting a parent segment can invalidate child segment handles.
    end
end

% Compact top-level reading order and keep the three-phase path horizontal.
set_param(profile,'Position',[45 235 205 385]);
set_param(branch,'Position',[275 165 920 515]);
set_param(rec,'Position',[1000 205 1160 245]);
set_param([model '/Strong Synchronous Machine (Governor + AVR)'], ...
    'Position',[1000 290 1330 540]);
cleanup_unused_parent_outputs([model '/Strong Synchronous Machine (Governor + AVR)']);
set_param([model '/Physical Network Solver'],'Position',[1000 585 1065 640]);
set_param(model,'StopTime','.90','MaxStep','1e-5','Location',[40 40 1510 900]);

set_param(model,'SimulationCommand','update');
try,set_param(model,'SampleTimeColors','off');catch,end
save_system(model,modelFile);
try,hilite_system(model,'none');catch,end
render_layer(model,fullfile(root,'build','Wind_GFL_R1_top.png'),false);
render_layer(branch,fullfile(root,'build','Wind_GFL_R1_branch.png'),false);
render_layer(aero,fullfile(root,'build','Wind_GFL_R1_aerodynamic_mppt.png'),true);
render_layer(msc,fullfile(root,'build','Wind_GFL_R1_dc_msc.png'),true);
render_layer(pcs,fullfile(root,'build','Wind_GFL_R1_gfl_pcs.png'),false);
render_layer([branch '/04 Step-up and PCC'],fullfile(root,'build','Wind_GFL_R1_stepup_pcc.png'),false);
close_system(model,0);
fprintf('WIND_GFL_R1_BUILD_OK=1\nMODEL=%s\n',modelFile);

function clear_subsystem(sys)
b=find_system(sys,'SearchDepth',1,'Type','Block');
for k=2:numel(b),delete_block(b{k});end
end

function cleanup_unconnected_outports(sys)
b=find_system(sys,'SearchDepth',1,'BlockType','Outport');
for k=1:numel(b)
    p=get_param(b{k},'PortHandles');ln=get_param(p.Inport(1),'Line');
    if ln<0,delete_block(b{k});end
end
end

function cleanup_unused_parent_outputs(sys)
p=get_param(sys,'PortHandles');unused=[];
for k=1:numel(p.Outport)
    ln=get_param(p.Outport(k),'Line');
    if ln<0 || strcmp(get_param(ln,'Connected'),'off'),unused(end+1)=k;end %#ok<AGROW>
end
outs=find_system(sys,'SearchDepth',1,'BlockType','Outport');
for k=numel(outs):-1:1
    if ismember(str2double(get_param(outs{k},'Port')),unused),delete_block(outs{k});end
end
end

function remove_disconnected_lines(sys)
ln=find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
for h=ln(:).'
    try
        if strcmp(get_param(h,'Connected'),'off'),delete_line(h);end
    catch
    end
end
end

function render_layer(sys,file,doArrange)
try
    if doArrange,Simulink.BlockDiagram.arrangeSystem(sys,'FullLayout','true');end
    print(['-s' sys],'-dpng','-r140',file);
catch ME
    fprintf('PNG_WARNING %s: %s\n',sys,ME.message);
end
end
