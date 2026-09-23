function modelFile=build_wind_standalone()
%BUILD_WIND_STANDALONE Generate the v2 Wind-GFL commissioning harness.
root=setup_v2_paths();define_resource_buses(true);define_v2_parameters(true);
define_wind_test_fixture(true);
model='wind_resource_standalone';folder=fullfile(root,'models','resources');
if ~exist(folder,'dir'),mkdir(folder);end;modelFile=fullfile(folder,[model '.slx']);
if bdIsLoaded(model),close_system(model,0);end
new_system(model);load_system('ee_lib');load_system('fl_lib');load_system('nesl_utility');
wind=build_wind_resource(model,'Wind Resource','V2.Wind',[300 175 760 455]);
add_command_profile(model,'Wind Command',[40 220 220 400]);
grid=add_strong_machine_fixture(model,'Strong Synchronous Machine Test Grid',root,[880 165 1250 450]);
define_wind_test_fixture(true);
add_status_recorder(model,'wind_v2_result');
add_block('nesl_utility/Solver Configuration',[model '/Physical Network Solver'], ...
    'Position',[890 560 955 615]);
add_line(model,v2_physical_port(wind),v2_port(grid,'RConn',1),'autorouting','on');
add_line(model,v2_port([model '/Physical Network Solver'],'RConn',1),v2_physical_port(wind));
add_line(model,'Wind Command/1','Wind Resource/1','autorouting','on');
add_line(model,'Wind Resource/1','Wind Status Recorder/1','autorouting','on');
a=Simulink.Annotation(model,sprintf([ ...
    'WIND RESOURCE v2 — generated from empty model\n' ...
    'Resource: Wind availability/DC -> shared GFL PCS -> independent Filter/Transformer/PCC\n' ...
    'Standalone harness: strong synchronous machine + local load; no BESS or PV']));
a.Position=[45 20 1160 100];a.FontSize=14;a.FontWeight='bold';
initCmd=char("root=fileparts(fileparts(fileparts(get_param(bdroot,'FileName')))); " + ...
    "addpath(root); setup_v2_paths; define_resource_buses(true); define_v2_parameters(true); " + ...
    "define_wind_test_fixture(true);");
set_param(model,'InitFcn',initCmd,'StopTime','1.0','MaxStep','1e-5', ...
    'SolverType','Variable-step','Solver','ode23t','Location',[50 50 1450 880]);
v2_disable_previews(model);v2_route_level(model);
set_param(model,'SimulationCommand','update');save_system(model,modelFile);
artifact=fullfile(root,'artifacts','architecture_v2');
v2_render(model,fullfile(artifact,'Wind_01_Standalone.png'));
v2_render(wind,fullfile(artifact,'Wind_02_Resource.png'));
v2_render([wind '/01 Wind Source and DC Side'],fullfile(artifact,'Wind_03_Source_DC.png'));
v2_render([wind '/02 PCS'],fullfile(artifact,'Wind_04_GFL_PCS.png'));
v2_render([wind '/03 AC Interface'],fullfile(artifact,'Wind_05_AC_Interface.png'));
close_system(model,0);fprintf('WIND_V2_BUILD_PASS=1\nMODEL=%s\n',modelFile);
end

function add_command_profile(model,name,pos)
s=[model '/' name];add_block('built-in/Subsystem',s,'Position',pos, ...
    'BackgroundColor','[1.00,0.94,0.78]','ContentPreviewEnabled','off');
add_block('simulink/Sources/Constant',[s '/P Base'],'Position',[20 25 100 55],'Value','0');
add_block('simulink/Sources/Step',[s '/P Increment'],'Position',[20 70 100 100], ...
    'Time','.30','Before','0','After','2e6');
add_block('simulink/Math Operations/Sum',[s '/P ref'],'Position',[145 35 175 95],'Inputs','++');
add_block('simulink/Sources/Constant',[s '/Q Base'],'Position',[20 125 100 155],'Value','0');
add_block('simulink/Sources/Step',[s '/Q Increment'],'Position',[20 170 100 200], ...
    'Time','.30','Before','0','After','0');
add_block('simulink/Math Operations/Sum',[s '/Q ref'],'Position',[145 135 175 195],'Inputs','++');
add_block('simulink/Sources/Constant',[s '/V ref'],'Position',[215 25 295 55],'Value','690');
add_block('simulink/Sources/Constant',[s '/f ref'],'Position',[215 70 295 100],'Value','50');
add_block('simulink/Sources/Constant',[s '/Enable Base'],'Position',[215 125 295 155],'Value','1');
add_block('simulink/Sources/Step',[s '/Enable Off'],'Position',[215 170 295 200], ...
    'Time','10','Before','0','After','-1');
add_block('simulink/Sources/Step',[s '/Enable On'],'Position',[215 215 295 245], ...
    'Time','11','Before','0','After','1');
add_block('simulink/Math Operations/Sum',[s '/Enable'],'Position',[340 150 370 225],'Inputs','+++');
add_block('simulink/Sources/Constant',[s '/Mode'],'Position',[340 260 420 290],'Value','0');
add_block('simulink/Signal Routing/Bus Creator',[s '/Resource Command'], ...
    'Position',[470 30 475 300],'Inputs','6','OutDataTypeStr','Bus: ResourceCommandBus');
add_block('simulink/Ports & Subsystems/Out1',[s '/ResourceCommandBus'], ...
    'Position',[535 155 565 169],'OutDataTypeStr','Bus: ResourceCommandBus');
add_line(s,'P Base/1','P ref/1');add_line(s,'P Increment/1','P ref/2');
add_line(s,'Q Base/1','Q ref/1');add_line(s,'Q Increment/1','Q ref/2');
add_line(s,'Enable Base/1','Enable/1');add_line(s,'Enable Off/1','Enable/2');add_line(s,'Enable On/1','Enable/3');
sig={'P ref/1','Q ref/1','V ref/1','f ref/1','Enable/1','Mode/1'};
fields={'P_ref_W','Q_ref_var','V_ref_V','f_ref_Hz','enable','mode'};
for k=1:6,v2_named_line(s,sig{k},sprintf('Resource Command/%d',k),fields{k});end
add_line(s,'Resource Command/1','ResourceCommandBus/1');v2_route_level(s);
end

function add_status_recorder(model,varname)
s=[model '/Wind Status Recorder'];add_block('built-in/Subsystem',s,'Position',[810 455 1080 535], ...
    'BackgroundColor','[0.92,0.92,0.92]','ContentPreviewEnabled','off');
add_block('simulink/Ports & Subsystems/In1',[s '/ResourceStatusBus'], ...
    'Position',[20 75 50 89],'OutDataTypeStr','Bus: ResourceStatusBus');
add_block('simulink/Signal Routing/Bus Selector',[s '/Status Selector'], ...
    'Position',[90 25 95 220], ...
    'OutputSignals','P_W,Q_var,Vpcc_V,frequency_Hz,available_power_W,power_headroom_W,current_limit_factor,energy_state_pu,Vdc_V,control_mode,healthy');
add_block('simulink/Sources/Clock',[s '/Time'],'Position',[90 240 120 270]);
add_block('simulink/Signal Routing/Mux',[s '/Regression Vector'], ...
    'Position',[250 25 255 285],'Inputs','12');
add_line(s,'Time/1','Regression Vector/1');
for k=1:11,add_line(s,sprintf('Status Selector/%d',k),sprintf('Regression Vector/%d',k+1),'autorouting','on');end
add_line(s,'ResourceStatusBus/1','Status Selector/1');
add_block('simulink/Sinks/To Workspace',[s '/Wind v2 Result'], ...
    'Position',[330 125 455 165],'VariableName',varname,'SaveFormat','Array','MaxDataPoints','inf');
add_line(s,'Regression Vector/1','Wind v2 Result/1');v2_route_level(s);
end
