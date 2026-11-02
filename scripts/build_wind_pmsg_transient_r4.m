%BUILD_WIND_PMSG_TRANSIENT_R4 Derive corrected-loss, local-PLL R4 from R3.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
source=fullfile(root,'build','Wind_PMSG_Transient_R3.slx');
model='Wind_PMSG_Transient_R4';file=fullfile(root,'build',[model '.slx']);
assert(isfile(source),'Missing immutable R3 source: %s',source);
run(fullfile(root,'parameters','init_wind_pmsg_transient_r4.m'));
if bdIsLoaded(model),close_system(model,0);end
copyfile(source,file,'f');load_system(file);
set_param(model,'InitFcn',char("root=fileparts(fileparts(get_param(bdroot,'FileName'))); " + ...
    "run(fullfile(root,'parameters','init_wind_pmsg_transient_r4.m'));"), ...
    'Description',['R4 derived from immutable R3: calibrated PMSG copper loss, ' ...
    'active local PCC SRF-PLL, two-mass shaft, explicit dq machine, average MSC ' ...
    'and switching 5 kHz GSC.']);
control=[model '/04 GFL Control and SPWM'];activateLocalPLL(control);
layoutWindOwners(model);

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(model,[45 535 1690 590],sprintf([ ...
    'DIRECT-DRIVE PMSG TRANSIENT R4 — 5 MW / 6.25 MVA\n' ...
    'Two-mass shaft + calibrated PMSG dq/MSC -> physical DC link -> local-PLL switching GSC -> 10 kV PCC']));
note(model,[50 610 1690 650], ...
    'Local PCC SRF-PLL drives both outer and dq-current transforms; nominal 50 Hz angle is monitor-only.');
save_system(model,file);set_param(model,'SimulationCommand','update');save_system(model,file);
close_system(model,0);fprintf('WIND_PMSG_TRANSIENT_R4_BUILD_OK=1\nMODEL=%s\n',file);

function activateLocalPLL(sys)
align=[sys '/PLL Angle Alignment'];p=get_param(align,'PortHandles');ln=get_param(p.Inport(1),'Line');
if ln>0,delete_line(ln);end
source=[sys '/PLL Angle for Control'];
if getSimulinkBlockHandle(source)<0
 add_block('simulink/Signal Routing/From',source,'Position',[60 660 195 690], ...
  'GotoTag','THETA_PLL_DIAG','ShowName','off');
end
set_param(source,'Position',[20 193 140 223]);
set_param(align,'Position',[180 188 290 228],'Bias','Control.PLL.ControlAngleBias');
set_param([sys '/Control Angle Distribution'],'Position',[330 193 465 223]);
set_param([sys '/Nominal Grid Omega'],'Position',[20 745 110 775]);
set_param([sys '/Nominal Grid Angle'],'Position',[150 740 190 780]);
add_line(sys,'PLL Angle for Control/1','PLL Angle Alignment/1','autorouting','on');
monitor=[sys '/Nominal Angle Monitor'];
if getSimulinkBlockHandle(monitor)<0
 add_block('simulink/Sinks/Terminator',monitor,'Position',[230 750 250 770]);
 add_line(sys,'Nominal Grid Angle/1','Nominal Angle Monitor/1','autorouting','on');
end
pll=[sys '/02 Synchronization SRF-PLL'];
Simulink.BlockDiagram.arrangeSystem(pll);
ports=get_param(align,'PortHandles');
set_param(ports.Outport,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','wind_control_angle');
anns=find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(sys,[450 75 1260 150], ...
 ['LOCAL SYNCHRONIZATION ACTIVE: PCC SRF-PLL -> alignment -> outer P/Vdc ' ...
  'and dq current control. Nominal angle is monitor-only.']);
lines=find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
Simulink.BlockDiagram.routeLine(lines);
end
function note(s,pos,t),a=Simulink.Annotation(s,t);a.Position=pos;a.FontSize=10;a.ForegroundColor='blue';end

function layoutWindOwners(model)
a=[model '/01 Wind Turbine Two-Mass Aerodynamics'];
place(a,{'Initial Wind Speed',[20 30 125 60];'Wind Speed Step',[20 85 125 115]; ...
 'Wind Speed Profile',[165 47 200 95];'Wind Speed',[240 15 270 35]; ...
 'lambda inputs',[300 60 305 120];'Tip-Speed Ratio',[345 70 465 110]; ...
 'Cp Curve',[510 70 620 110];'Power inputs',[675 60 680 120]; ...
 'Aerodynamic Power Equation',[730 70 895 110];'Power Limit',[940 70 1040 110]; ...
 'Aerodynamic Power',[1100 80 1130 100];'Aero Torque inputs',[950 160 955 230]; ...
 'Aerodynamic Torque',[735 176 875 216];'Turbine accel inputs',[640 170 645 260]; ...
 'Turbine Acceleration',[440 195 585 235];'Turbine Inertia',[315 195 365 235]; ...
 'Shaft Speed Difference',[420 325 465 380];'Shaft Twist',[530 330 580 375]; ...
 'Shaft inputs',[660 300 665 390];'Flexible Shaft',[720 325 855 365]; ...
 'Electromagnetic Torque Te',[520 465 550 485];'Generator accel inputs',[660 430 665 520]; ...
 'Generator Acceleration',[720 455 880 495];'Generator Inertia',[945 455 995 495]; ...
 'Generator Speed omega_g',[1050 465 1080 485]});
for n={'Aero Torque inputs','Aerodynamic Torque','Turbine accel inputs','Turbine Acceleration','Turbine Inertia'}
 set_param([a '/' n{1}],'Orientation','left');
end
finish(a,570);
s=[model '/02 PMSG dq Machine and Average MSC'];
partitionMachine(s);
finish(s,410);
end

function finish(s,y)
notes=find_system(s,'FindAll','on','SearchDepth',1,'Type','annotation');
for h=notes(:).',set_param(h,'Position',[30 y]);end
lines=find_system(s,'FindAll','on','SearchDepth',1,'Type','line');
Simulink.BlockDiagram.routeLine(lines);
end

function partitionMachine(s)
% Partition the original scalar graph. Copy block parameters and restore
% every input edge from its original source, including integrator feedback.
ref='01 Torque and Current References';ctrl='02 MSC Current Control';
plant='03 PMSG Electrical Dynamics';power='04 MSC DC Power';
piBlocks={};
for axis={'d','q'}
    x=axis{1};
    piBlocks=[piBlocks,{['i' x ' Error'],['Kp ' x],['Ki ' x],['Integral ' x], ...
        ['I Limit ' x],['PI ' x],['v' x ' inputs'],['v' x ' Decoupling']}]; %#ok<AGROW>
end
groups={ref,{'MPPT Torque Reference','id Reference','Torque to iq','iq Limit'}, ...
    {'Generator Speed omega_g','omega_g'}, {'id Reference','id_ref';'iq Limit','iq_ref'},[150 75 370 165]; ...
    ctrl,[piBlocks,{'Measured DC Voltage','Sampled Vdc','Voltage limit inputs', ...
    'Circular Voltage Scale','Limited vd','Limited vq'}], ...
    {'id Reference','id_ref';'iq Limit','iq_ref';'Electrical Speed','omega_e';'id State','id';'iq State','iq'}, ...
    {'Limited vd','vd';'Limited vq','vq'},[470 65 690 240]; ...
    plant,{'did inputs','did dt','id State','diq inputs','diq dt','iq State','Torque inputs','Electromagnetic Torque'}, ...
    {'Limited vd','vd';'Limited vq','vq';'Electrical Speed','omega_e'}, ...
    {'Electromagnetic Torque','Te';'id State','id';'iq State','iq'},[820 65 1040 205]; ...
    power,{'Power inputs','Generated DC Power','MSC Power Limit'}, ...
    {'Limited vd','vd';'Limited vq','vq';'id State','id';'iq State','iq'}, ...
    {'MSC Power Limit','Pdc'},[1110 225 1300 355]};
% Master map from each producer to its port on the parent canvas.
src=containers.Map({'Generator Speed omega_g','Electrical Speed'}, ...
    {'Generator Speed omega_g/1','Electrical Speed/1'});
for k=1:size(groups,1)
    g=groups{k,1};path=[s '/' g];blocks=groups{k,2};ins=groups{k,3};outs=groups{k,4};
    add_block('built-in/Subsystem',path,'Position',groups{k,5},'ContentPreviewEnabled','off');
    local=containers.Map('KeyType','char','ValueType','char');
    for j=1:size(ins,1)
        add_block('built-in/Inport',[path '/' ins{j,2}],'Port',num2str(j));
        local(ins{j,1})=[ins{j,2} '/1'];
    end
    for j=1:numel(blocks)
        b=blocks{j};add_block([s '/' b],[path '/' b]);local(b)=[b '/1'];
    end
    for j=1:numel(blocks)
        b=blocks{j};ph=get_param([s '/' b],'PortHandles');
        for i=1:numel(ph.Inport)
            line=get_param(ph.Inport(i),'Line');from=get_param(line,'SrcBlockHandle');
            producer=get_param(from,'Name');add_line(path,local(producer),sprintf('%s/%d',b,i),'autorouting','on');
        end
    end
    for i=1:size(outs,1)
        add_block('built-in/Outport',[path '/' outs{i,2}],'Port',num2str(i));
        add_line(path,local(outs{i,1}),[outs{i,2} '/1'],'autorouting','on');
        src(outs{i,1})=sprintf('%s/%d',g,i);
    end
    for j=1:numel(blocks)
        b=blocks{j};a=get_param([s '/' b],'PortHandles');p=get_param([path '/' b],'PortHandles');
        if strcmp(get_param(a.Outport,'DataLogging'),'on')
            set_param(p.Outport,'DataLogging','on','DataLoggingNameMode','Custom', ...
                'DataLoggingName',get_param(a.Outport,'DataLoggingName'));
        end
    end
    Simulink.BlockDiagram.arrangeSystem(path);
end
% Rebuild only this canvas. Its physical interfaces, outer wires and
% original model's immutable source blocks live outside this operation.
lines=find_system(s,'SearchDepth',1,'FindAll','on','Type','line');
for h=lines(:).',if ishandle(h),delete_line(h);end,end
for k=1:size(groups,1)
    for b=groups{k,2},delete_block([s '/' b{1}]);end
end
place(s,{'Generator Speed omega_g',[20 105 50 125];'Electrical Speed',[195 235 320 275]; ...
    'Electromagnetic Torque Te',[1150 75 1180 95];'MSC DC Power',[1370 280 1400 300]});
add_line(s,'Generator Speed omega_g/1','Electrical Speed/1','autorouting','on');
for k=1:size(groups,1)
    ins=groups{k,3};
    for i=1:size(ins,1)
        add_line(s,src(ins{i,1}),sprintf('%s/%d',groups{k,1},i),'autorouting','on');
    end
end
add_line(s,src('Electromagnetic Torque'),'Electromagnetic Torque Te/1','autorouting','on');
add_line(s,src('MSC Power Limit'),'MSC DC Power/1','autorouting','on');
end

function place(owner,rows)
for k=1:size(rows,1)
    set_param([owner '/' rows{k,1}],'Position',rows{k,2});
end
end

