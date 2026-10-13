%BUILD_WIND_COURSE_AVERAGE Create an average-GSC derivative of SPWM R2.
% The accepted SPWM model remains untouched.  Turbine, averaged PMSG/MSC,
% physical DC link, filter, transformer and PCC are retained verbatim.

scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
source=fullfile(root,'build','Wind_DirectDrive_SPWM_R2.slx');
model='Wind_DirectDrive_Average';
modelFile=fullfile(root,'models','resources',[model '.slx']);
assert(isfile(source),'Missing SPWM source model: %s',source);
run(fullfile(root,'parameters','init_wind_course_average.m'));
if bdIsLoaded(model),close_system(model,0);end
copyfile(source,modelFile,'f');load_system(modelFile);
load_system('ee_lib');load_system('nesl_utility');

set_param(model,'InitFcn',char("root=fileparts(fileparts(fileparts(get_param(bdroot,'FileName')))); " + ...
    "run(fullfile(root,'parameters','init_wind_course_average.m'));"), ...
    'StopTime','Base.Simulation.StopTime','MaxStep','Base.Simulation.MaxStep', ...
    'Description',['Direct-drive 5 MW wind turbine with averaged PMSG/MSC, ' ...
    'physical DC link, average-value grid-side VSC and active local SRF-PLL.']);

oldPlant=[model '/03 DC Link and Two-Level GSC'];
set_param(oldPlant,'Name','03 DC Link and Average GSC');
plant=[model '/03 DC Link and Average GSC'];
replaceSwitchingPlant(plant);

oldControl=[model '/04 GFL Control and SPWM'];
set_param(oldControl,'Name','04 GFL Control');
control=[model '/04 GFL Control'];
replacePWMInterface(control);
activateLocalPLL(control);
tidyLocalPLL([control '/02 Synchronization SRF-PLL']);

% The original short physical gate boundary remains in place.  Its signal is
% now six continuous duty ratios rather than six binary switching pulses.

set_param(plant,'Position',[785 270 1060 440]);
set_param(control,'Position',[400 315 700 485]);
set_param([model '/05 Filter Transformer and PCC'],'Position',[1135 270 1420 440]);
set_param([model '/06 Grid Equivalent and Source'],'Position',[1500 270 1755 440]);
replaceTopAnnotations(model);
enableNamedSignalLogging(model,'Vabc_mod');

save_system(model,modelFile);
set_param(model,'SimulationCommand','update');
save_system(model,modelFile);
fprintf('WIND_AVERAGE_COMPILE_OK=1\n');

renderSystem(model,fullfile(root,'build','WIND_AVERAGE_01_Top.png'));
renderSystem(plant,fullfile(root,'build','WIND_AVERAGE_02_DC_GSC.png'));
renderSystem(control,fullfile(root,'build','WIND_AVERAGE_03_Control.png'));
renderSystem([control '/02 Synchronization SRF-PLL'], ...
    fullfile(root,'build','WIND_AVERAGE_04_PLL.png'));
renderSystem([control '/05 dq Current Controller'], ...
    fullfile(root,'build','WIND_AVERAGE_05_Current_Control.png'));
renderSystem([model '/05 Filter Transformer and PCC'], ...
    fullfile(root,'build','WIND_AVERAGE_06_Grid_Interface.png'));
close_system(model,0);
fprintf('WIND_COURSE_AVERAGE_BUILD_OK=1\nMODEL=%s\n',modelFile);

function replaceSwitchingPlant(sys)
bridge=[sys '/Two-Level Three-Phase Bridge'];
set_param(bridge,'Name','Averaged-Switch Three-Phase Bridge');
bridge=[sys '/Averaged-Switch Three-Phase Bridge'];
set_param(bridge,'fidelity_option','ee.enum.converters.fidelity.detailed', ...
    'device_type','ee.enum.converters.switchingdevice.averaged');
set_param([sys '/Converter AC Measurement'],'Position',[1020 145 1210 265]);
set_param([sys '/AC_Terminal'],'Position',[1250 190 1280 220]);

anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(sys,[55 590 1210 650],sprintf([ ...
    'Physical path: precharge -> 1500 V rail (Cdc + MSC current injection) -> averaged-switch GSC -> AC measurement.\n' ...
    'The original bridge terminals and polarity are preserved; six continuous [0,1] duty ratios replace binary switching pulses.']));
end

function replacePWMInterface(sys)
pwm=[sys '/06 SPWM and Physical Gate Interface'];
gate=[sys '/Gate Drive'];
convTemplate=[pwm '/Gate 1 to Physical Signal'];
muxTemplate=[pwm '/Six-Pulse Gate Multiplexer'];
avg=[sys '/06 Average Duty Interface'];
add_block('built-in/Subsystem',avg,'Position',[1165 455 1360 610], ...
    'BackgroundColor','[0.95,0.87,0.42]','ContentPreviewEnabled','off');
for k=1:6
    add_block(convTemplate,[avg sprintf('/Duty %d to Physical',k)], ...
        'Position',[650 35+55*(k-1) 745 60+55*(k-1)]);
end
add_block(muxTemplate,[avg '/Six-Pulse Duty Multiplexer'], ...
    'Position',[800 25 890 365]);
deleteBlockAndLines(pwm);
add_block('simulink/Ports & Subsystems/In1',[avg '/Vabc Command'], ...
    'Position',[20 145 50 165]);
add_block('simulink/Discrete/Unit Delay',[avg '/One Control-Step Delay'], ...
    'Position',[80 135 130 175],'SampleTime','Control.Ts', ...
    'InitialCondition','[0 0 0]');
add_block('simulink/Discontinuities/Saturation',[avg '/Modulation Limit'], ...
    'Position',[165 135 260 175],'UpperLimit','Converter.ModulationMax', ...
    'LowerLimit','-Converter.ModulationMax');
add_block('simulink/Math Operations/Gain',[avg '/Half Modulation'], ...
    'Position',[295 135 365 175],'Gain','0.5');
add_block('simulink/Math Operations/Bias',[avg '/High-Side Duty'], ...
    'Position',[400 135 485 175],'Bias','0.5');
add_block('simulink/Signal Routing/Demux',[avg '/Phase Duty Selector'], ...
    'Position',[520 75 525 250],'Outputs','3');
add_line(avg,'Vabc Command/1','One Control-Step Delay/1');
add_line(avg,'One Control-Step Delay/1','Modulation Limit/1');
add_line(avg,'Modulation Limit/1','Half Modulation/1');
add_line(avg,'Half Modulation/1','High-Side Duty/1');
add_line(avg,'High-Side Duty/1','Phase Duty Selector/1');
phases={'A','B','C'};
for k=1:3
    y=45+110*(k-1);
    add_block('simulink/Math Operations/Gain',[avg '/' phases{k} ' Duty Negate'], ...
        'Position',[555 y+45 595 y+75],'Gain','-1');
    add_block('simulink/Math Operations/Bias',[avg '/' phases{k} ' Low Duty'], ...
        'Position',[610 y+45 645 y+75],'Bias','1');
    add_line(avg,sprintf('Phase Duty Selector/%d',k),sprintf('Duty %d to Physical/1',2*k-1));
    add_line(avg,sprintf('Phase Duty Selector/%d',k),[phases{k} ' Duty Negate/1']);
    add_line(avg,[phases{k} ' Duty Negate/1'],[phases{k} ' Low Duty/1']);
    add_line(avg,[phases{k} ' Low Duty/1'],sprintf('Duty %d to Physical/1',2*k));
end
mux=get_param([avg '/Six-Pulse Duty Multiplexer'],'PortHandles');
for k=1:6
    conv=get_param([avg sprintf('/Duty %d to Physical',k)],'PortHandles');
    add_line(avg,conv.RConn(1),mux.LConn(k),'autorouting','on');
end
add_block(gate,[avg '/Average Gate Duty'], ...
    'Position',[940 180 970 210],'Side','Right','Orientation','left');
set_param([avg '/Average Gate Duty'],'Name','Duty6');
out=get_param([avg '/Duty6'],'PortHandles');
add_line(avg,mux.RConn(1),out.RConn(1),'autorouting','on');
note(avg,[100 410 900 455], ...
    'd_high=(m+1)/2; d_low=1-d_high; output order is [AH AL BH BL CH CL]. One control-step delay is retained.');
set_param(gate,'Position',[1400 520 1430 550],'Orientation','left');
add_line(sys,'05 dq Current Controller/1','06 Average Duty Interface/1','autorouting','on');
avgPorts=get_param(avg,'PortHandles');gatePorts=get_param(gate,'PortHandles');
add_line(sys,avgPorts.RConn(1),gatePorts.RConn(1),'autorouting','on');
set_param(avg,'ContentPreviewEnabled','off');
lines=find_system(sys,'FindAll','on','Type','line','Name','Vabc_mod');
if isempty(lines)
    inner=get_param([sys '/05 dq Current Controller'],'PortHandles');
    ln=get_param(inner.Outport(1),'Line');if ln>0,set_param(ln,'Name','Vabc_mod');end
end
end

function tidyLocalPLL(sys)
% Keep the inherited PLL equations unchanged while making the signal flow
% readable from left to right. Re-route only this subsystem's Simulink lines.
positions={ ...
    'Vabc PCC',[20 180 50 200]; ...
    'PCC Voltage Prefilter',[80 140 230 240]; ...
    'Clarke abc to alpha beta',[285 165 420 215]; ...
    'Park Voltage',[475 140 620 240]; ...
    'Separate Vd Vq',[665 145 670 235]; ...
    'Vd PLL Internal Monitor',[735 120 765 140]; ...
    'Normalize Vq',[725 195 815 235]; ...
    'Vq PLL Internal Monitor',[735 310 765 330]; ...
    'PLL Kp',[865 185 945 215]; ...
    'PLL Ki',[865 270 945 300]; ...
    'Integrate Vq Error',[985 265 1025 305]; ...
    'Delta Omega',[1070 205 1110 255]; ...
    'Nominal Omega',[1060 75 1160 105]; ...
    'Omega Command',[1200 145 1240 195]; ...
    'Omega Limits',[1280 145 1330 195]; ...
    'omega Internal Monitor',[1370 95 1400 115]; ...
    'Angle Integrator',[1370 145 1410 195]; ...
    'theta',[1480 155 1510 175]};
connections=topLevelConnections(sys);
for k=1:size(positions,1)
    path=[sys '/' positions{k,1}];
    if getSimulinkBlockHandle(path)>0,set_param(path,'Position',positions{k,2});end
end
lines=find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
for h=lines(:).'
    try
        delete_line(h);
    catch ME
        warning('WindAverage:PLLDeleteLine','PLL line cleanup skipped: %s',ME.message);
    end
end
for k=1:numel(connections)
    try
        h=add_line(sys,connections(k).src,connections(k).dst,'autorouting','smart');
        if strlength(connections(k).name)>0,set_param(h,'Name',connections(k).name);end
    catch ME
        error('WindAverage:PLLRoute','Failed to restore PLL connection %d: %s',k,ME.message);
    end
end
anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(sys,[85 370 1450 410], ...
    'PCC voltage prefilter -> Clarke/Park -> normalized Vq PI -> omega0 bias -> angle integration. Lock target: Vq = 0.');
end

function c=topLevelConnections(sys)
c=struct('src',{},'dst',{},'name',{});
blocks=find_system(sys,'SearchDepth',1,'Type','Block');
for b=2:numel(blocks)
    ph=get_param(blocks{b},'PortHandles');
    for dst=ph.Inport(:).'
        ln=get_param(dst,'Line');
        if ln<=0,continue,end
        src=get_param(ln,'SrcPortHandle');
        if src<=0,continue,end
        c(end+1)=struct('src',src,'dst',dst,'name',string(get_param(ln,'Name'))); %#ok<AGROW>
    end
end
end

function activateLocalPLL(sys)
alignment=[sys '/PLL Angle Alignment'];
p=get_param(alignment,'PortHandles');ln=get_param(p.Inport(1),'Line');
if ln>0,delete_line(ln);end
add_block('simulink/Signal Routing/From',[sys '/PLL Angle for Control'], ...
    'Position',[60 660 195 690],'GotoTag','THETA_PLL_DIAG', ...
    'ShowName','off');
set_param(alignment,'Position',[250 655 345 695]);
add_line(sys,'PLL Angle for Control/1','PLL Angle Alignment/1','autorouting','on');
add_block('simulink/Sinks/Terminator',[sys '/Nominal Angle Monitor'], ...
    'Position',[285 785 305 805]);
add_line(sys,'Nominal Grid Angle/1','Nominal Angle Monitor/1','autorouting','on');
set_param(alignment,'Bias','Control.PLL.ControlAngleBias');
anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(sys,[450 75 1260 150], ...
    ['LOCAL SYNCHRONIZATION ACTIVE: SRF-PLL angle -> negative-d-axis and ' ...
     'prefilter phase correction -> P/Q and dq current control. Nominal angle is monitor-only.']);
note(sys,[450 180 1260 225], ...
    'Main chain: DC/P reference -> current circle limit -> dq current controller -> continuous averaged-switch duty interface.');
end

function replaceTopAnnotations(model)
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(model,[45 535 1710 590],sprintf([ ...
    'DIRECT-DRIVE WIND GENERATOR — SYSTEM-LEVEL AVERAGE GSC — 5 MW / 6.25 MVA\n' ...
    'Cp(lambda,beta) + rotor inertia -> average PMSG/MSC -> physical 1500 V DC link -> averaged-switch GFL bridge -> 690 V/10 kV PCC']));
note(model,[50 610 1710 650], ...
    'Local SRF-PLL is active; the GSC uses averaged switches with continuous duty ratios, without carrier comparison or switching events.');
end

function deleteBlockAndLines(path)
if getSimulinkBlockHandle(path)<=0,return,end
ph=get_param(path,'PortHandles');fields=fieldnames(ph);lines=[];
for k=1:numel(fields)
    for h=ph.(fields{k})(:).'
        try
            ln=get_param(h,'Line');
            if ln>0,lines(end+1)=ln;end %#ok<AGROW>
        catch ME
            warning('WindAverage:PortInspection','Port inspection skipped: %s',ME.message);
        end
    end
end
for ln=unique(lines)
    try
        delete_line(ln);
    catch ME
        warning('WindAverage:DeleteLine','Line cleanup skipped: %s',ME.message);
    end
end
delete_block(path);
end

function enableNamedSignalLogging(model,name)
lines=find_system(model,'FindAll','on','Type','line','Name',name);
for h=lines(:).'
    src=get_param(h,'SrcPortHandle');
    if src>0
        try
            set_param(src,'DataLogging','on','DataLoggingNameMode','Custom', ...
                'DataLoggingName',name);
        catch ME
            warning('WindAverage:SignalLogging', ...
                'Could not enable logging for %s: %s',name,ME.message);
        end
    end
end
end

function renderSystem(systemName,fileName)
try
    open_system(systemName);set_param(systemName,'ZoomFactor','FitSystem');
    print(['-s' systemName],'-dpng','-r150',fileName);
catch ME
    warning('WindAverage:Render','Render skipped for %s: %s',systemName,ME.message);
end
end

function note(sys,pos,textValue)
a=Simulink.Annotation(sys,textValue);a.Position=pos;a.FontSize=11;a.FontWeight='bold';
a.ForegroundColor='blue';
end
