function modelFile=build_grid_supported_integration(resourceSet)
%BUILD_GRID_SUPPORTED_INTEGRATION Incremental renewable commissioning; never island.
% Supported sets: {'PV'}, {'Wind'}, {'PV','Wind'}. BESS is intentionally not
% paralleled unsynchronized: its upgraded controller has not been supplied.
if nargin<1,resourceSet={'PV','Wind'};end
assert(all(ismember(resourceSet,{'PV','Wind'})),'Only commissioned GFL resources are permitted.');
root=setup_v2_paths;init_grid_supported_integration;
hasPV=ismember('PV',resourceSet);hasWind=ismember('Wind',resourceSet);
assert(hasPV||hasWind);
m=['GRID_SUPPORTED_' upper(strjoin(resourceSet,'_')) '_R1'];
if bdIsLoaded(m),close_system(m,0);end
new_system(m);load_system('ee_lib');load_system('fl_lib');load_system('nesl_utility');
folder=fullfile(root,'models','integration');if ~exist(folder,'dir'),mkdir(folder);end
modelFile=fullfile(folder,[m '.slx']);

% Reuse the exact fixed-speed 100 MVA synchronous-machine commissioning fixture.
pvFile=fullfile(root,'models','resources','pv_resource_dynamic_standalone.slx');
load_system(pvFile);fixture=[m '/Strong Synchronous Machine - Always Connected'];
add_block('pv_resource_dynamic_standalone/Strong Synchronous Machine Test Grid',fixture, ...
 'Position',[950 90 1260 275]);close_system('pv_resource_dynamic_standalone',0);
set_param([fixture '/Machine Record'],'VariableName','integration_machine');
% The always-connected machine must initially carry the connected load.
% Zero P/Q initial conditions caused a nonphysical 5.22e8 V solve at t=0.
set_param([fixture '/Synchronous Machine'],'Pt0','5e6','Qt0','1.5e6');
delete_line(fixture,'Governor Speed/1','Speed PS/1');delete_block([fixture '/Governor Speed']);
add_block('simulink/Sources/Step',[fixture '/Governor Speed'], ...
 'Position',[40 350 160 380],'Time','10','Before','2*pi*50','After','2*pi*50');
add_line(fixture,'Governor Speed/1','Speed PS/1');
meas=add_pcc_measurement(m,'Synchronous Machine PCC','V2.PV',[660 90 855 265]);
set_param([meas '/Local PCC Voltage Record'],'VariableName','integration_bus_vabc','SaveFormat','Timeseries');
add_line(m,v2_port(fixture,'LConn',1),v2_port(meas,'LConn',1),'autorouting','on');
busPort=v2_port(meas,'RConn',1);
add_status_record(m,meas,'SM',{'P_W','Q_var','Vll_rms_V'},[950 350 1170 440]);

if hasPV
 pv=build_pv_resource(m,'PV Resource','V2.PV',[160 300 490 455]);
 add_resource_command(m,'PV Command',2e6,0.6,1e6,[35 330 125 425]);
 add_line(m,'PV Command/1','PV Resource/1','autorouting','on');
 add_line(m,v2_physical_port(pv),busPort,'autorouting','on');
 add_status_record(m,pv,'PV',status_fields(),[550 365 770 450]);
end
if hasWind
 wind=build_wind_r3_grid_adapter(m,'Wind Resource',[160 560 490 715]);
 add_resource_command(m,'Wind Command',5e6,10,0,[35 580 125 675]);
 add_line(m,'Wind Command/1','Wind Resource/1','autorouting','on');
 % Keep the already commissioned Wind path continuously grid-connected.
 add_line(m,v2_physical_port(wind),busPort,'autorouting','on');
 set_param([wind '/01 Wind Turbine Two-Mass Aerodynamics/Wind Speed Step'],'Time','0.75');
 add_status_record(m,wind,'Wind',status_fields(),[550 610 770 695]);
else
 add_block('nesl_utility/Solver Configuration',[m '/Physical Network Solver'], ...
  'Position',[850 535 915 600]);
 add_line(m,v2_port([m '/Physical Network Solver'],'RConn',1),busPort);
end
add_block('ee_lib/Passive/Constant Power Load (Three-Phase)',[m '/Island-Ready Load - Grid Connected'], ...
 'Position',[955 550 1215 665],'FRated','50','active_power','5e6','active_power_unit','W', ...
 'reactive_power','1.5e6','reactive_power_unit','V*A','Vline_rms_min','7000','Vline_rms_ini','10000');
add_line(m,v2_port([m '/Island-Ready Load - Grid Connected'],'LConn',1),busPort,'autorouting','on');
set_param(m,'InitFcn','setup_v2_paths; init_grid_supported_integration;', ...
 'SolverType','Fixed-step','Solver','ode14x','FixedStep','1e-5', ...
 'SimulationMode','normal','StopTime','1.1','SignalLogging','on', ...
 'ReturnWorkspaceOutputs','on','SignalLoggingName','logsout');
a=Simulink.Annotation(m,['GRID-SUPPORTED COMMISSIONING ONLY | 10 kV / 50 Hz | ' ...
 '100 MVA fixed-speed synchronous machine always connected; no islanding switch.']);
a.Position=[45 15 1260 60];a.FontSize=14;
set_param(m,'Description',['PV physical DC + optional Wind R3 averaged GSC integration. ' ...
 'The synchronous machine remains connected in every test. No BESS replacement or island certification.']);
v2_disable_previews(m);v2_route_level(m);
set_param(m,'SimulationCommand','update');save_system(m,modelFile);
art=fullfile(root,'artifacts','grid_supported_integration');
v2_render(m,fullfile(art,[m '_Top.png']));
if hasWind
 v2_render([m '/Wind Resource'],fullfile(art,[m '_Wind.png']));
 v2_render([m '/Wind Resource/04 GFL Control and SPWM'],fullfile(art,[m '_Wind_Control.png']));
end
fprintf('GRID_SUPPORTED_BUILD_PASS=1 MODEL=%s\n',modelFile);close_system(m,0);
end

function add_resource_command(m,name,p0,event,dp,pos)
s=[m '/' name];add_block('built-in/Subsystem',s,'Position',pos,'ContentPreviewEnabled','off');
add_block('simulink/Sources/Constant',[s '/P Base'],'Position',[20 25 100 55],'Value',num2str(p0));
add_block('simulink/Sources/Step',[s '/P Increment'],'Position',[20 80 100 110], ...
 'Time',num2str(event),'Before','0','After',num2str(dp));
add_block('simulink/Math Operations/Sum',[s '/P Reference'],'Position',[140 30 170 95],'Inputs','++');
add_line(s,'P Base/1','P Reference/1');add_line(s,'P Increment/1','P Reference/2');
names={'Q Reference','V Reference','f Reference','Enable','Mode'};values={'0','690','50','1','0'};
for k=1:5
 if k==1
  add_block('simulink/Sources/Step',[s '/' names{k}], ...
   'Position',[210 20+50*k 310 50+50*k],'Time','10','Before','0','After','0');
 else
  add_block('simulink/Sources/Constant',[s '/' names{k}], ...
   'Position',[210 20+50*k 310 50+50*k],'Value',values{k});
 end
end

add_block('simulink/Signal Routing/Bus Creator',[s '/Command'], ...
 'Position',[380 20 385 310],'Inputs','6','OutDataTypeStr','Bus: ResourceCommandBus');
sig=[{'P Reference'} names];
fields={'P_ref_W','Q_ref_var','V_ref_V','f_ref_Hz','enable','mode'};
for k=1:6,v2_named_line(s,[sig{k} '/1'],sprintf('Command/%d',k),fields{k});end
add_block('simulink/Ports & Subsystems/Out1',[s '/ResourceCommandBus'], ...
 'Position',[440 155 470 169],'OutDataTypeStr','Bus: ResourceCommandBus');
add_line(s,'Command/1','ResourceCommandBus/1');
end

function add_status_record(m,source,token,fields,pos)
s=[m '/' token ' Telemetry'];add_block('built-in/Subsystem',s,'Position',pos,'ContentPreviewEnabled','off');
add_block('simulink/Ports & Subsystems/In1',[s '/Status'],'Position',[20 75 50 89]);
add_block('simulink/Signal Routing/Bus Selector',[s '/Fields'], ...
 'Position',[90 25 95 300],'OutputSignals',strjoin(fields,','));add_line(s,'Status/1','Fields/1');
add_block('simulink/Signal Routing/Mux',[s '/Vector'],'Position',[180 25 185 300],'Inputs',num2str(numel(fields)));
for k=1:numel(fields),add_line(s,sprintf('Fields/%d',k),sprintf('Vector/%d',k));end
add_block('simulink/Sinks/To Workspace',[s '/Record'],'Position',[230 135 390 175], ...
 'VariableName',['integration_' lower(token)],'SaveFormat','Timeseries','MaxDataPoints','inf');
add_line(s,'Vector/1','Record/1');
src=get_param(source,'PortHandles');dst=get_param(s,'PortHandles');add_line(m,src.Outport(1),dst.Inport(1),'autorouting','on');
end
function fields=status_fields()
fields={'P_W','Q_var','Vpcc_V','frequency_Hz','available_power_W','power_headroom_W', ...
 'current_limit_factor','energy_state_pu','Vdc_V','control_mode','healthy'};
end
