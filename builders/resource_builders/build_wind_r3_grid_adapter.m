function path=build_wind_r3_grid_adapter(parent,name,pos)
%BUILD_WIND_R3_GRID_ADAPTER Legacy entry point importing corrected R4 owners.
% R3 remains immutable evidence. R4 already has its local PLL active; this
% adapter namespaces tags, exposes resource commands/status and substitutes
% only the accepted average-duty grid-side bridge.
root=setup_v2_paths();source=fullfile(root,'build','Wind_PMSG_Transient_R4.slx');
avgFile=fullfile(root,'models','resources','Wind_DirectDrive_Average.slx');
assert(isfile(source)&&isfile(avgFile),'Missing corrected Wind R4 / average-duty asset.');
src='Wind_PMSG_Transient_R4';avg='Wind_DirectDrive_Average';
srcWasLoaded=bdIsLoaded(src);avgWasLoaded=bdIsLoaded(avg);
load_system(source);load_system(avgFile);
assert(strcmp(get_param(src,'FileName'),source) && strcmp(get_param(src,'Dirty'),'off'), ...
 'Expected the unmodified Wind R4 model at the project source path.');
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
 'ContentPreviewEnabled','off','BackgroundColor','[0.88 0.94 1]');
owners={'01 Wind Turbine Two-Mass Aerodynamics','02 PMSG dq Machine and Average MSC', ...
 '03 DC Link and Two-Level GSC','04 GFL Control and SPWM','05 Filter Transformer and PCC'};
positions={[75 60 355 175],[425 60 735 175],[795 205 1075 345], ...
 [425 260 735 420],[1150 205 1430 345]};
for k=1:numel(owners),add_block([src '/' owners{k}],[path '/' owners{k}],'Position',positions{k});end
v2_add_pmio(path,'PCC_10kV',1,'Right','foundation.electrical.three_phase',[1490 260 1520 290]);
add_block('simulink/Ports & Subsystems/In1',[path '/ResourceCommandBus'], ...
 'Position',[20 480 50 494],'OutDataTypeStr','Bus: ResourceCommandBus');
add_block('simulink/Ports & Subsystems/Out1',[path '/ResourceStatusBus'], ...
 'Position',[1490 560 1520 574],'OutDataTypeStr','Bus: ResourceStatusBus');
L=@(a,b)add_line(path,a,b,'autorouting','on');
L([owners{1} '/2'],[owners{2} '/1']);L([owners{2} '/1'],[owners{1} '/1']);
L([owners{2} '/2'],[owners{3} '/1']);L([owners{2} '/2'],[owners{4} '/1']);
add_line(path,v2_port([path '/' owners{4}],'RConn',1),v2_port([path '/' owners{3}],'LConn',1));
add_line(path,v2_port([path '/' owners{3}],'RConn',1),v2_port([path '/' owners{5}],'LConn',1));
add_line(path,v2_port([path '/' owners{5}],'RConn',1),v2_physical_port([path '/PCC_10kV']));

% Retain MSC, shaft, DC capacitor, sensors and AC plant. Only GSC fidelity changes.
plant=[path '/' owners{3}];control=[path '/' owners{4}];
connect_average_brake([plant '/DC Control and Monitoring']);
set_param([plant '/Two-Level Three-Phase Bridge'], ...
 'device_type','ee.enum.converters.switchingdevice.averaged');
pwm=[control '/06 SPWM and Physical Gate Interface'];
ph=get_param(pwm,'PortHandles');oldLine=get_param(ph.Inport(1),'Line');
modSource=get_param(oldLine,'SrcPortHandle');delete_line(oldLine);
gateLine=get_param(ph.RConn(1),'Line');if gateLine>0,delete_line(gateLine);end
delete_block(pwm);
newDuty=[control '/06 Average Duty Interface'];
add_block([avg '/04 GFL Control/06 Average Duty Interface'],newDuty,'Position',[1190 455 1410 610]);
ph=get_param(newDuty,'PortHandles');add_line(control,modSource,ph.Inport(1));
add_line(control,ph.RConn(1),v2_port([control '/Gate Drive'],'RConn',1));

% R4 already uses the local PLL. Reconnect explicitly after copying so this
% adapter fails closed if a future source drifts back to the nominal angle.
align=[control '/PLL Angle Alignment'];ph=get_param(align,'PortHandles');
ln=get_param(ph.Inport(1),'Line');if ln>0,delete_line(ln);end
pllSource=[control '/PLL Angle for Control'];
if getSimulinkBlockHandle(pllSource)<0
 add_block('simulink/Signal Routing/From',pllSource, ...
  'Position',[20 660 145 690],'GotoTag','THETA_PLL_DIAG');
end
add_line(control,'PLL Angle for Control/1','PLL Angle Alignment/1','autorouting','on');
set_param(align,'Bias','Control.PLL.ControlAngleBias');
if getSimulinkBlockHandle([control '/Nominal Angle Monitor'])<0
 add_block('simulink/Sinks/Terminator',[control '/Nominal Angle Monitor'],'Position',[285 800 305 820]);
 add_line(control,'Nominal Grid Angle/1','Nominal Angle Monitor/1');
end

add_command_adapter(path,owners{2});
add_status_adapter(path,owners{1});
% Eliminate cross-resource hidden tag paths, including all inherited globals.
for kind={'Goto','From','GotoTagVisibility'}
 blocks=find_system(path,'LookUnderMasks','all','FollowLinks','on','BlockType',kind{1});
 for j=1:numel(blocks)
  tag=get_param(blocks{j},'GotoTag');if startsWith(tag,'WIND_R4__'),continue,end
  set_param(blocks{j},'GotoTag',['WIND_R4__' tag]);
  if strcmp(kind{1},'Goto')&&strcmp(get_param(blocks{j},'TagVisibility'),'global')
   set_param(blocks{j},'TagVisibility','scoped');
   vis=[path '/Scope ' tag];if getSimulinkBlockHandle(vis)<0
    add_block('simulink/Signal Routing/Goto Tag Visibility',vis, ...
     'Position',[25 650+30*j 150 670+30*j],'GotoTag',['WIND_R4__' tag]);
   end
  end
 end
end
a=Simulink.Annotation(path,['Wind R4 commissioning adapter: corrected PMSG loss, two-mass/MSC/DC states retained. ' ...
 'Local PCC PLL drives current control. GSC averaged; source grid not imported.']);
a.Position=[65 5 1470 40];
scopes=find_system(path,'SearchDepth',1,'BlockType','GotoTagVisibility');
for j=1:numel(scopes)
 x=70+300*mod(j-1,4);y=700+45*floor((j-1)/4);
 set_param(scopes{j},'Position',[x y x+260 y+25],'ShowName','off','FontSize',8);
end
% Keep nominal-angle diagnostics away from the local control chain.
% Preserve the dedicated horizontal PLL lane from the standalone R4.
set_param([control '/Nominal Grid Omega'],'Position',[760 50 880 80]);
set_param([control '/Nominal Grid Angle'],'Position',[930 45 975 85]);
set_param([control '/Nominal Angle Monitor'],'Position',[1040 55 1060 75]);
set_param(newDuty,'Position',[1340 212 1560 368]);
% Align the two physical ports, then align the duty input to its producer.
dutyPorts=get_param(newDuty,'PortHandles');
srcXY=get_param(modSource,'Position');dstXY=get_param(dutyPorts.Inport(1),'Position');
dy=srcXY(2)-dstXY(2);
set_param(newDuty,'Position',get_param(newDuty,'Position')+[0 dy 0 dy]);
gate=[control '/Gate Drive'];gatePorts=get_param(gate,'PortHandles');
dutyXY=get_param(dutyPorts.RConn(1),'Position');gateXY=get_param(gatePorts.RConn(1),'Position');
dy=dutyXY(2)-gateXY(2);
set_param(gate,'Position',get_param(gate,'Position')+[0 dy 0 dy]);
annotations=find_system(control,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(annotations),delete(annotations);end
note=Simulink.Annotation(control,'Local PCC PLL -> current references -> current circle -> dq PI -> averaged GSC duties. Nominal angle is monitor-only.');
note.Position=[170 10 1400 35];
v2_route_level(control);
v2_disable_previews(path);v2_route_level(path);
if ~srcWasLoaded,close_system(src,0);end
if ~avgWasLoaded,close_system(avg,0);end
end

function connect_average_brake(s)
% Use the existing controlled source for the algebraic sum of MSC injection
% and resistor draw. Both currents are positive magnitudes before subtraction.
for b={'Brake Hysteresis','Vdc over Brake R'}
 delete_line(s,'Vdc Measured/1',[b{1} '/1']);
 add_line(s,'Sampled DC Voltage/1',[b{1} '/1'],'autorouting','on');
end
delete_line(s,'Brake Current Estimate/1','Brake Current/1');
add_block('simulink/Discontinuities/Saturation',[s '/Brake Current Limit'], ...
 'LowerLimit','0','UpperLimit','Wind.brake_current_limit_A','Position',[460 295 545 330]);
add_line(s,'Brake Current Estimate/1','Brake Current Limit/1','autorouting','on');
add_line(s,'Brake Current Limit/1','Brake Current/1','autorouting','on');
delete_line(s,'MSC DC Current Limit/1','Injection Sign/1');
add_block('simulink/Math Operations/Sum',[s '/Net DC Injection'], ...
 'Inputs','+-','Position',[520 62 550 108]);
add_line(s,'MSC DC Current Limit/1','Net DC Injection/1','autorouting','on');
add_line(s,'Brake Current Limit/1','Net DC Injection/2','autorouting','on');
add_line(s,'Net DC Injection/1','Injection Sign/1','autorouting','on');
end

function add_command_adapter(path,machineName)
resource=path;path=[resource '/Command Interface'];
add_block('built-in/Subsystem',path,'Position',[70 470 350 610],'ContentPreviewEnabled','off');
add_block('simulink/Ports & Subsystems/In1',[path '/ResourceCommandBus'], ...
 'Position',[20 40 50 54],'OutDataTypeStr','Bus: ResourceCommandBus');
add_line(resource,'ResourceCommandBus/1','Command Interface/1','autorouting','on');
add_block('simulink/Signal Routing/Bus Selector',[path '/Command Selector'], ...
 'Position',[100 470 105 560],'OutputSignals','P_ref_W,Q_ref_var,enable');
add_line(path,'ResourceCommandBus/1','Command Selector/1');
set_param([path '/ResourceCommandBus'],'Position',[20 100 50 114]);
set_param([path '/Command Selector'],'Position',[130 55 135 160]);
tags={'DISPATCH_W','Q_REF_VAR','ENABLE'};
for k=1:3
 add_block('simulink/Signal Routing/Goto',[path '/Command ' tags{k}], ...
  'Position',[215 35+35*k 330 55+35*k],'GotoTag',tags{k},'TagVisibility','global');
 add_line(path,sprintf('Command Selector/%d',k),['Command ' tags{k} '/1']);
end
path=resource;
m=[path '/' machineName '/01 Torque and Current References'];old=[m '/Torque to iq'];ph=get_param(old,'PortHandles');
ln=get_param(ph.Inport(1),'Line');src=get_param(ln,'SrcPortHandle');delete_line(ln);
add_block('simulink/Signal Routing/From',[m '/Dispatch Power'],'Position',[25 450 140 480],'GotoTag','DISPATCH_W');
add_block('simulink/Signal Routing/From',[m '/Dispatch Enable'],'Position',[25 500 140 530],'GotoTag','ENABLE');
add_block('simulink/Signal Routing/Mux',[m '/Dispatch Inputs'],'Position',[170 445 175 570],'Inputs','4');
add_line(m,src,v2_port([m '/Dispatch Inputs'],'Inport',1));
add_line(m,'Dispatch Power/1','Dispatch Inputs/2');
add_line(m,'Dispatch Enable/1','Dispatch Inputs/4');
add_block('simulink/Discontinuities/Saturation',[m '/Speed Floor'], ...
 'LowerLimit','PMSG.speed_floor_rad_s','UpperLimit','inf','Position',[80 570 160 600]);
add_line(m,'omega_g/1','Speed Floor/1','autorouting','on');
add_line(m,'Speed Floor/1','Dispatch Inputs/3','autorouting','on');
add_block('simulink/User-Defined Functions/Fcn',[m '/Dispatch Torque Cap'], ...
 'Position',[215 450 460 490], ...
 'Expr','0.5*(u(1)+u(2)/u(3)-abs(u(1)-u(2)/u(3)))*u(4)');
add_line(m,'Dispatch Inputs/1','Dispatch Torque Cap/1');add_line(m,'Dispatch Torque Cap/1','Torque to iq/1');
capBlocks={'Dispatch Power','Dispatch Enable','Dispatch Inputs','Speed Floor','Dispatch Torque Cap'};
capHandles=cellfun(@(b)get_param([m '/' b],'Handle'),capBlocks);
Simulink.BlockDiagram.createSubsystem(capHandles,'Name','Dispatch Torque Limit');
cap=[m '/Dispatch Torque Limit'];
set_param(cap,'Position',[290 140 445 200],'ContentPreviewEnabled','off');
Simulink.BlockDiagram.arrangeSystem(cap);
Simulink.BlockDiagram.arrangeSystem(m);
outer=[path '/04 GFL Control and SPWM/03 DC Voltage and Current Reference'];
delete_line(outer,'Iq Zero/1','Iq raw/1');delete_block([outer '/Iq Zero']);
add_block('simulink/Signal Routing/From',[outer '/Reactive Dispatch'],'GotoTag','Q_REF_VAR','Position',[40 430 180 455]);
add_block('simulink/Signal Routing/From',[outer '/Generation Enable'],'GotoTag','ENABLE','Position',[40 480 180 505]);
add_block('simulink/Math Operations/Product',[outer '/Enabled Q'],'Position',[225 433 260 493]);
add_block('simulink/Continuous/Transfer Fcn',[outer '/Q Command Filter'],'Numerator','1','Denominator','[0.02 1]','Position',[300 445 410 480]);
add_block('simulink/Signal Routing/Mux',[outer '/Q and Vd'],'Inputs','2','Position',[485 415 490 480]);
add_block('simulink/User-Defined Functions/Fcn',[outer '/Reactive Current Reference'], ...
 'Expr','-2*u(1)/(abs(u(2))+100+abs(abs(u(2))-100))','Position',[540 425 710 465]);
set_param([outer '/Iq raw'],'Position',[765 437 795 451]);
add_line(outer,'Reactive Dispatch/1','Enabled Q/1');add_line(outer,'Generation Enable/1','Enabled Q/2');
add_line(outer,'Enabled Q/1','Q Command Filter/1');add_line(outer,'Q Command Filter/1','Q and Vd/1');
add_line(outer,'Separate Vdq/1','Q and Vd/2','autorouting','on');
add_line(outer,'Q and Vd/1','Reactive Current Reference/1');add_line(outer,'Reactive Current Reference/1','Iq raw/1');
notes=find_system(outer,'FindAll','on','SearchDepth',1,'Type','annotation');
for n=notes(:).',if contains(string(get_param(n,'Text')),'Iq*=0'),delete(n);end,end
v2_route_level(outer);v2_route_level([resource '/Command Interface']);
add_block('simulink/Sinks/To Workspace',[path '/Wind Command Record'], ...
 'Position',[340 490 510 530],'VariableName','wind_resource_command','SaveFormat','Timeseries');
add_line(path,'ResourceCommandBus/1','Wind Command Record/1');
end

function add_status_adapter(path,aeroName)
s=[path '/Resource Status'];add_block('built-in/Subsystem',s,'Position',[1080 470 1390 620],'ContentPreviewEnabled','off');
add_block('simulink/Ports & Subsystems/In1',[s '/Actual MSC Power'],'Position',[20 40 50 54]);
add_block('simulink/Ports & Subsystems/In1',[s '/Generator Speed'],'Position',[20 70 50 84],'Port','2');
add_block('simulink/Ports & Subsystems/Out1',[s '/Status'],'Position',[810 190 840 204],'OutDataTypeStr','Bus: ResourceStatusBus');
tags={'P_PCC','Q_PCC','Vabc_PCC_Meas','OMEGA_PLL_DIAG','Vdc_Meas','ID_RAW_LOCAL','IQ_RAW_LOCAL'};
% PLL omega tag differs across the seed; create a stable observer below.
tags{4}='OMEGA_RESOURCE';
control=[path '/04 GFL Control and SPWM'];pll=[control '/02 Synchronization SRF-PLL'];
measurements=[control '/01 Measurements and dq'];
for item={'P','Q'}
 token=item{1};
 add_block('simulink/Signal Routing/Goto',[measurements '/Resource ' token], ...
  'Position',[1250 400+55*strcmp(token,'Q') 1380 430+55*strcmp(token,'Q')], ...
  'GotoTag',[token '_PCC'],'TagVisibility','global');
 src=get_param([measurements '/' token ' Low-Pass'],'PortHandles');
 dst=get_param([measurements '/Resource ' token],'PortHandles');
 add_line(measurements,src.Outport(1),dst.Inport(1));
end
% The Omega Saturation output is the actual frequency estimator state.
sat={[pll '/Omega Limits']};assert(getSimulinkBlockHandle(sat{1})>0,'Missing PLL frequency limiter');
add_block('simulink/Signal Routing/Goto',[pll '/Resource Omega'], ...
 'Position',[1400 330 1530 360],'GotoTag','OMEGA_RESOURCE','TagVisibility','global');
p=get_param(sat{1},'PortHandles');q=get_param([pll '/Resource Omega'],'PortHandles');add_line(pll,p.Outport(1),q.Inport(1));
for k=1:numel(tags)
 add_block('simulink/Signal Routing/From',[s '/Sense ' tags{k}], ...
  'Position',[20 85+45*k 145 110+45*k],'GotoTag',tags{k});
end
% Raw dq references are local to the outer loop; use exported current-limit signals.
set_param([s '/Sense ID_RAW_LOCAL'],'GotoTag','ID_REF_RESOURCE');
set_param([s '/Sense IQ_RAW_LOCAL'],'GotoTag','IQ_REF_RESOURCE');
lim=[control '/04 Circular Current Limiter'];
axes={'Id raw','Iq raw'};
for k=1:2
 src=get_param([lim '/' axes{k}],'PortHandles');
 tag={'ID_REF_RESOURCE','IQ_REF_RESOURCE'};
 add_block('simulink/Signal Routing/Goto',[lim '/Resource ' tag{k}], ...
  'Position',[20 380+40*k 155 405+40*k],'GotoTag',tag{k},'TagVisibility','global');
 dst=get_param([lim '/Resource ' tag{k}],'PortHandles');add_line(lim,src.Outport(1),dst.Inport(1));
end
add_block('simulink/User-Defined Functions/Fcn',[s '/Vll RMS'],'Position',[210 170 370 205], ...
 'Expr','sqrt((u(1)^2+u(2)^2+u(3)^2)/3)');
add_line(s,'Sense Vabc_PCC_Meas/1','Vll RMS/1');
add_block('simulink/Math Operations/Gain',[s '/Frequency Hz'],'Position',[210 230 370 260],'Gain','1/(2*pi)');
add_line(s,'Sense OMEGA_RESOURCE/1','Frequency Hz/1');
add_block('simulink/Signal Routing/Mux',[s '/Current References'],'Position',[190 350 195 440],'Inputs','2');
add_line(s,'Sense ID_RAW_LOCAL/1','Current References/1');add_line(s,'Sense IQ_RAW_LOCAL/1','Current References/2');
add_block('simulink/User-Defined Functions/Fcn',[s '/Limit Factor'],'Position',[230 360 420 400], ...
 'Expr','2*Converter.IdqMax/(sqrt(u(1)^2+u(2)^2)+Converter.IdqMax+abs(sqrt(u(1)^2+u(2)^2)-Converter.IdqMax)+1e-9)');
add_line(s,'Current References/1','Limit Factor/1');
% Deliverable available power is estimated from the current rotor speed and
% the same MPPT torque/copper-loss model as the machine, not raw aero capture.
add_block('simulink/User-Defined Functions/Fcn',[s '/Available MPPT Torque'], ...
 'Position',[90 20 250 50], ...
 'Expr','0.5*(Wind.Kopt_Nm_per_rad_s2*u^2+PMSG.torque_limit_Nm-abs(Wind.Kopt_Nm_per_rad_s2*u^2-PMSG.torque_limit_Nm))');
add_line(s,'Generator Speed/1','Available MPPT Torque/1');
add_block('simulink/Math Operations/Product',[s '/Available Airgap Power'], ...
 'Position',[285 20 325 55]);
add_line(s,'Available MPPT Torque/1','Available Airgap Power/1');
add_line(s,'Generator Speed/1','Available Airgap Power/2');
add_block('simulink/Math Operations/Gain',[s '/Available iq'], ...
 'Position',[285 70 405 100],'Gain','-1/(1.5*PMSG.pole_pairs*PMSG.psi_f_Wb)');
add_line(s,'Available MPPT Torque/1','Available iq/1');
add_block('simulink/Math Operations/Product',[s '/Available iq squared'], ...
 'Position',[440 65 480 105]);
add_line(s,'Available iq/1','Available iq squared/1');add_line(s,'Available iq/1','Available iq squared/2');
add_block('simulink/Math Operations/Gain',[s '/Estimated Copper Loss'], ...
 'Position',[515 70 645 100],'Gain','1.5*PMSG.Rs_ohm');
add_line(s,'Available iq squared/1','Estimated Copper Loss/1');
add_block('simulink/Math Operations/Sum',[s '/Available Machine Power'], ...
 'Position',[675 20 710 70],'Inputs','+-');
add_line(s,'Available Airgap Power/1','Available Machine Power/1');
add_line(s,'Estimated Copper Loss/1','Available Machine Power/2');
add_block('simulink/Math Operations/Gain',[s '/Available MSC Efficiency'], ...
 'Position',[745 25 845 55],'Gain','PMSG.msc_efficiency');
add_line(s,'Available Machine Power/1','Available MSC Efficiency/1');
add_block('simulink/Math Operations/Bias',[s '/Available Auxiliary Loss'], ...
 'Position',[875 25 965 55],'Bias','-PMSG.loss_constant_W');
add_line(s,'Available MSC Efficiency/1','Available Auxiliary Loss/1');
add_block('simulink/Discontinuities/Saturation',[s '/Available Power Limit'], ...
 'Position',[995 20 1080 60],'LowerLimit','0','UpperLimit','PMSG.Sn_W');
add_line(s,'Available Auxiliary Loss/1','Available Power Limit/1');
add_block('simulink/Signal Routing/Mux',[s '/Power Headroom Inputs'],'Position',[520 115 525 190],'Inputs','2');
add_line(s,'Available Power Limit/1','Power Headroom Inputs/1');add_line(s,'Actual MSC Power/1','Power Headroom Inputs/2');
add_block('simulink/User-Defined Functions/Fcn',[s '/Headroom'],'Position',[560 130 700 165], ...
 'Expr','0.5*(u(1)-u(2)+abs(u(1)-u(2)))');add_line(s,'Power Headroom Inputs/1','Headroom/1');
% Incremental reserve is measured on the MSC side. Suppress dispatchable
% reserve in standby, when the GSC remains online only to support Vdc.
add_block('simulink/Signal Routing/From',[s '/Dispatch Enabled'],'GotoTag','ENABLE');
add_block('simulink/Math Operations/Product',[s '/Online Headroom']);
add_line(s,'Headroom/1','Online Headroom/1');add_line(s,'Dispatch Enabled/1','Online Headroom/2');
add_block('simulink/User-Defined Functions/Fcn',[s '/DC Energy pu'],'Position',[230 440 420 475], ...
 'Expr','(u/Converter.Vdc_nom)^2');add_line(s,'Sense Vdc_Meas/1','DC Energy pu/1');
add_block('simulink/Sources/Constant',[s '/Mode'],'Position',[470 420 530 450],'Value','0');
add_block('simulink/User-Defined Functions/Fcn',[s '/Health'],'Position',[470 470 640 505], ...
 'Expr','(u>PMSG.Validation.vdc_min_V)*(u<PMSG.Validation.vdc_max_V)');add_line(s,'Sense Vdc_Meas/1','Health/1');
add_block('simulink/Signal Routing/Bus Creator',[s '/ResourceStatusBus'],'Position',[710 30 715 520], ...
 'Inputs','11','OutDataTypeStr','Bus: ResourceStatusBus');
sig={'Sense P_PCC/1','Sense Q_PCC/1','Vll RMS/1','Frequency Hz/1','Available Power Limit/1', ...
 'Online Headroom/1','Limit Factor/1','DC Energy pu/1','Sense Vdc_Meas/1','Mode/1','Health/1'};
fields={'P_W','Q_var','Vpcc_V','frequency_Hz','available_power_W','power_headroom_W', ...
 'current_limit_factor','energy_state_pu','Vdc_V','control_mode','healthy'};
for k=1:11,v2_named_line(s,sig{k},sprintf('ResourceStatusBus/%d',k),fields{k});end
add_line(s,'ResourceStatusBus/1','Status/1');
add_line(path,'02 PMSG dq Machine and Average MSC/2','Resource Status/1','autorouting','on');
add_line(path,[aeroName '/2'],'Resource Status/2','autorouting','on');
add_line(path,'Resource Status/1','ResourceStatusBus/1','autorouting','on');
% Keep the electrical capability estimate behind one speed-in/power-out
% boundary. Telemetry fields and the command-enable gate remain visible.
chain={'Available MPPT Torque','Available Airgap Power','Available iq','Available iq squared', ...
 'Estimated Copper Loss','Available Machine Power','Available MSC Efficiency', ...
 'Available Auxiliary Loss','Available Power Limit'};
handles=cellfun(@(n)get_param([s '/' n],'Handle'),chain);
Simulink.BlockDiagram.createSubsystem(handles,'Name','MSC Available Power');
Simulink.BlockDiagram.arrangeSystem([s '/MSC Available Power']);
Simulink.BlockDiagram.arrangeSystem(s);
end
