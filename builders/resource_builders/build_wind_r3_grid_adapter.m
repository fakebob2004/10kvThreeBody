function path=build_wind_r3_grid_adapter(parent,name,pos)
%BUILD_WIND_R3_GRID_ADAPTER Import five functional R3 owners, never its grid.
% Source R3 is immutable. The adapter enables its local PLL, namespaces tags,
% exposes resource commands/status and uses the accepted average duty bridge.
root=setup_v2_paths();source=fullfile(root,'build','Wind_PMSG_Transient_R3.slx');
avgFile=fullfile(root,'models','resources','Wind_DirectDrive_Average.slx');
assert(isfile(source)&&isfile(avgFile),'Missing supplied Wind R3 / average-duty asset.');
src='Wind_PMSG_Transient_R3';avg='Wind_DirectDrive_Average';
load_system(source);load_system(avgFile);
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

% IMPORTANT: R3's diagnostic PLL previously did not drive the current loops.
align=[control '/PLL Angle Alignment'];ph=get_param(align,'PortHandles');
ln=get_param(ph.Inport(1),'Line');if ln>0,delete_line(ln);end
add_block('simulink/Signal Routing/From',[control '/PLL Angle for Control'], ...
 'Position',[20 660 145 690],'GotoTag','THETA_PLL_DIAG');
add_line(control,'PLL Angle for Control/1','PLL Angle Alignment/1','autorouting','on');
set_param(align,'Bias','Control.PLL.ControlAngleBias');
add_block('simulink/Sinks/Terminator',[control '/Nominal Angle Monitor'],'Position',[285 800 305 820]);
add_line(control,'Nominal Grid Angle/1','Nominal Angle Monitor/1');

add_command_adapter(path,owners{2});
add_status_adapter(path,owners{1});
% Eliminate cross-resource hidden tag paths, including all inherited globals.
for kind={'Goto','From','GotoTagVisibility'}
 blocks=find_system(path,'LookUnderMasks','all','FollowLinks','on','BlockType',kind{1});
 for j=1:numel(blocks)
  tag=get_param(blocks{j},'GotoTag');if startsWith(tag,'WIND_R3__'),continue,end
  set_param(blocks{j},'GotoTag',['WIND_R3__' tag]);
  if strcmp(kind{1},'Goto')&&strcmp(get_param(blocks{j},'TagVisibility'),'global')
   set_param(blocks{j},'TagVisibility','scoped');
   vis=[path '/Scope ' tag];if getSimulinkBlockHandle(vis)<0
    add_block('simulink/Signal Routing/Goto Tag Visibility',vis, ...
     'Position',[25 650+30*j 150 670+30*j],'GotoTag',['WIND_R3__' tag]);
   end
  end
 end
end
a=Simulink.Annotation(path,['Wind R3 commissioning adapter: two-mass/PMSG/MSC/DC states retained. ' ...
 'Local PCC PLL drives current control. GSC averaged; source grid not imported.']);
a.Position=[65 5 1470 40];
scopes=find_system(path,'SearchDepth',1,'BlockType','GotoTagVisibility');
for j=1:numel(scopes)
 x=70+300*mod(j-1,4);y=700+45*floor((j-1)/4);
 set_param(scopes{j},'Position',[x y x+260 y+25],'ShowName','off','FontSize',8);
end
% Keep nominal-angle diagnostics away from the local control chain.
set_param([control '/PLL Angle for Control'],'Position',[20 200 145 230]);
set_param([control '/PLL Angle Alignment'],'Position',[190 200 300 235]);
set_param([control '/Control Angle Distribution'],'Position',[350 205 485 235]);
set_param([control '/Nominal Grid Omega'],'Position',[760 50 880 80]);
set_param([control '/Nominal Grid Angle'],'Position',[930 45 975 85]);
set_param([control '/Nominal Angle Monitor'],'Position',[1040 55 1060 75]);
set_param([control '/06 Average Duty Interface'],'Position',[1190 455 1410 610]);
annotations=find_system(control,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(annotations),delete(annotations);end
note=Simulink.Annotation(control,'Local PCC PLL -> current references -> current circle -> dq PI -> averaged GSC duties. Nominal angle is monitor-only.');
note.Position=[170 10 1400 35];
v2_disable_previews(path);v2_route_level(path);close_system(src,0);close_system(avg,0);
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
add_block('simulink/Logic and Bit Operations/Compare To Constant',[path '/Unity PF Contract'], ...
 'Position',[340 580 475 615],'relop','==','const','0');
add_block('simulink/Model Verification/Assertion',[path '/Reject Unsupported Wind Q'], ...
 'Position',[520 580 555 615]);
add_line(path,'Command Selector/2','Unity PF Contract/1');
add_line(path,'Unity PF Contract/1','Reject Unsupported Wind Q/1');
tags={'DISPATCH_W','Q_REF_VAR','ENABLE'};
for k=1:3
 add_block('simulink/Signal Routing/Goto',[path '/Command ' tags{k}], ...
  'Position',[160 450+45*k 290 475+45*k],'GotoTag',tags{k},'TagVisibility','global');
 add_line(path,sprintf('Command Selector/%d',k),['Command ' tags{k} '/1']);
end
path=resource;
m=[path '/' machineName];old=[m '/Torque to iq'];ph=get_param(old,'PortHandles');
ln=get_param(ph.Inport(1),'Line');src=get_param(ln,'SrcPortHandle');delete_line(ln);
add_block('simulink/Signal Routing/From',[m '/Dispatch Power'],'Position',[25 450 140 480],'GotoTag','DISPATCH_W');
add_block('simulink/Signal Routing/From',[m '/Dispatch Enable'],'Position',[25 500 140 530],'GotoTag','ENABLE');
add_block('simulink/Signal Routing/Mux',[m '/Dispatch Inputs'],'Position',[170 445 175 570],'Inputs','4');
add_line(m,src,v2_port([m '/Dispatch Inputs'],'Inport',1));
add_line(m,'Dispatch Power/1','Dispatch Inputs/2');add_line(m,'Generator Speed omega_g/1','Dispatch Inputs/3');
add_line(m,'Dispatch Enable/1','Dispatch Inputs/4');
add_block('simulink/User-Defined Functions/Fcn',[m '/Dispatch Torque Cap'], ...
 'Position',[215 450 460 490], ...
 'Expr','0.5*(u(1)+u(2)/(abs(u(3))+0.1)-abs(u(1)-u(2)/(abs(u(3))+0.1)))*u(4)');
add_line(m,'Dispatch Inputs/1','Dispatch Torque Cap/1');add_line(m,'Dispatch Torque Cap/1','Torque to iq/1');
% Q is still unity-PF only in this first adapter; fail nonzero Q explicitly.
% The public command is recorded, not silently claimed as a tested Q controller.
add_block('simulink/Sinks/To Workspace',[path '/Wind Command Record'], ...
 'Position',[340 490 510 530],'VariableName','wind_resource_command','SaveFormat','Timeseries');
add_line(path,'ResourceCommandBus/1','Wind Command Record/1');
end

function add_status_adapter(path,aeroName)
s=[path '/Resource Status'];add_block('built-in/Subsystem',s,'Position',[1080 470 1390 620],'ContentPreviewEnabled','off');
add_block('simulink/Ports & Subsystems/In1',[s '/Aerodynamic Power'],'Position',[20 40 50 54]);
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
add_block('simulink/Signal Routing/Mux',[s '/Power Headroom Inputs'],'Position',[200 20 205 95],'Inputs','2');
add_line(s,'Aerodynamic Power/1','Power Headroom Inputs/1');add_line(s,'Sense P_PCC/1','Power Headroom Inputs/2');
add_block('simulink/User-Defined Functions/Fcn',[s '/Headroom'],'Position',[240 30 420 65], ...
 'Expr','0.5*(u(1)-u(2)+abs(u(1)-u(2)))');add_line(s,'Power Headroom Inputs/1','Headroom/1');
add_block('simulink/User-Defined Functions/Fcn',[s '/DC Energy pu'],'Position',[230 440 420 475], ...
 'Expr','(u/Converter.Vdc_nom)^2');add_line(s,'Sense Vdc_Meas/1','DC Energy pu/1');
add_block('simulink/Sources/Constant',[s '/Mode'],'Position',[470 420 530 450],'Value','0');
add_block('simulink/User-Defined Functions/Fcn',[s '/Health'],'Position',[470 470 640 505], ...
 'Expr','(u>900)*(u<1800)');add_line(s,'Sense Vdc_Meas/1','Health/1');
add_block('simulink/Signal Routing/Bus Creator',[s '/ResourceStatusBus'],'Position',[710 30 715 520], ...
 'Inputs','11','OutDataTypeStr','Bus: ResourceStatusBus');
sig={'Sense P_PCC/1','Sense Q_PCC/1','Vll RMS/1','Frequency Hz/1','Aerodynamic Power/1', ...
 'Headroom/1','Limit Factor/1','DC Energy pu/1','Sense Vdc_Meas/1','Mode/1','Health/1'};
fields={'P_W','Q_var','Vpcc_V','frequency_Hz','available_power_W','power_headroom_W', ...
 'current_limit_factor','energy_state_pu','Vdc_V','control_mode','healthy'};
for k=1:11,v2_named_line(s,sig{k},sprintf('ResourceStatusBus/%d',k),fields{k});end
add_line(s,'ResourceStatusBus/1','Status/1');
add_line(path,[aeroName '/1'],'Resource Status/1','autorouting','on');
add_line(path,'Resource Status/1','ResourceStatusBus/1','autorouting','on');
end
