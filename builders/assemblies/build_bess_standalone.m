function modelFile=build_bess_standalone(strategy)
%BUILD_BESS_STANDALONE Generate the maintainable v2 BESS-GFM island harness.
root=setup_v2_paths();define_resource_buses(true);define_v2_parameters(true);
if nargin<1,strategy='droop';end
assert(any(strcmp(strategy,{'droop','dvoc'})));
model='bess_resource_standalone';folder=fullfile(root,'models','resources');
if strcmp(strategy,'dvoc'),configure_bess_dvoc();model='bess_resource_dvoc';end
if ~exist(folder,'dir'),mkdir(folder);end;modelFile=fullfile(folder,[model '.slx']);
if bdIsLoaded(model),close_system(model,0);end
new_system(model);load_system('ee_lib');load_system('fl_lib');load_system('nesl_utility');

bess=build_bess_resource(model,'BESS Resource','V2.BESS',[300 180 780 460]);
add_command_profile(model,'BESS Command',[40 225 220 405]);
add_island_load_harness(model,bess);
add_status_recorder(model);
add_block('nesl_utility/Solver Configuration',[model '/Physical Network Solver'], ...
    'Position',[895 590 960 645]);
add_line(model,v2_port([model '/Physical Network Solver'],'RConn',1),v2_physical_port(bess));
add_line(model,'BESS Command/1','BESS Resource/1','autorouting','on');
add_line(model,'BESS Resource/1','BESS Status Recorder/1','autorouting','on');

a=Simulink.Annotation(model,sprintf([ ...
    'BESS-GFM RESOURCE v2 — generated from empty model\n' ...
    'Stable chain: GFM Strategy -> Virtual Impedance Policy/Interface -> Common Protection -> Average Voltage Converter\n' ...
    'Island harness: 4 MW + 1.2 Mvar, then +1 MW + 0.3 Mvar at 0.30 s']));
a.Position=[45 20 1330 105];a.FontSize=14;a.FontWeight='bold';
initCmd=char("root=fileparts(fileparts(fileparts(get_param(bdroot,'FileName')))); " + ...
    "addpath(root); setup_v2_paths; define_resource_buses(true); define_v2_parameters(true);");
if strcmp(strategy,'dvoc'),initCmd=[initCmd ' configure_bess_dvoc;'];end
if strcmp(strategy,'dvoc')
    set_param(bess,'Position',[300 180 690 430]);
    set_param([model '/Load Step Command'],'Position',[720 315 795 345]);
end
set_param(model,'InitFcn',initCmd,'StopTime','0.8','MaxStep','1e-5', ...
    'SolverType','Variable-step','Solver','ode23t','Location',[50 50 1500 900]);
v2_disable_previews(model);v2_route_level(model);
set_param(model,'SimulationCommand','update');save_system(model,modelFile);
artifact=fullfile(root,'artifacts','architecture_v2');
if strcmp(strategy,'dvoc'),artifact=fullfile(root,'artifacts','bess_dvoc');end
v2_render(model,fullfile(artifact,'BESS_01_Standalone.png'));
v2_render(bess,fullfile(artifact,'BESS_02_Resource.png'));
v2_render([bess '/01 BESS Source and DC Side'],fullfile(artifact,'BESS_03_Source_DC.png'));
v2_render([bess '/02 PCS'],fullfile(artifact,'BESS_04_GFM_PCS.png'));
v2_render([bess '/02 PCS/01 GFM Strategy'],fullfile(artifact,['BESS_05_' strategy '_Strategy.png']));
v2_render([bess '/02 PCS/02 Virtual Impedance Policy'],fullfile(artifact,'BESS_06_VI_Policy.png'));
v2_render([bess '/02 PCS/03 Virtual Impedance Interface'],fullfile(artifact,'BESS_07_VI_Interface.png'));
v2_render([bess '/03 AC Interface'],fullfile(artifact,'BESS_08_AC_Interface.png'));
close_system(model,0);fprintf('BESS_V2_BUILD_PASS=1\nMODEL=%s\n',modelFile);
end

function add_command_profile(model,name,pos)
s=[model '/' name];add_block('built-in/Subsystem',s,'Position',pos, ...
    'BackgroundColor','[1.00,0.94,0.78]','ContentPreviewEnabled','off', ...
    'AttributesFormatString','resource-level command only; no Id/Iq/PWM/theta access');
values={'4e6','1.2e6','690','50','1','1'};
names={'P ref','Q ref','V ref','f ref','Enable','Mode'};
fields={'P_ref_W','Q_ref_var','V_ref_V','f_ref_Hz','enable','mode'};
for k=1:6
    y=25+52*(k-1);
    add_block('simulink/Sources/Constant',[s '/' names{k}], ...
        'Position',[25 y 115 y+30],'Value',values{k});
end
add_block('simulink/Signal Routing/Bus Creator',[s '/Resource Command'], ...
    'Position',[215 25 220 315],'Inputs','6','OutDataTypeStr','Bus: ResourceCommandBus');
add_block('simulink/Ports & Subsystems/Out1',[s '/ResourceCommandBus'], ...
    'Position',[285 160 315 174],'OutDataTypeStr','Bus: ResourceCommandBus');
for k=1:6
    v2_named_line(s,[names{k} '/1'],sprintf('Resource Command/%d',k),fields{k});
end
add_line(s,'Resource Command/1','ResourceCommandBus/1');v2_route_level(s);
end

function add_island_load_harness(model,bess)
cpl='ee_lib/Passive/Constant Power Load (Three-Phase)';
breaker=sprintf('ee_lib/Switches & Breakers/Circuit Breaker\n(Three-Phase)');
sps=sprintf('nesl_utility/Simulink-PS\nConverter');
add_block(cpl,[model '/Base Island Load'], ...
    'Position',[1010 170 1160 245],'FRated','V2.BESS.rating.f_Hz', ...
    'active_power','4e6','active_power_unit','W','reactive_power','1.2e6', ...
    'reactive_power_unit','V*A','Vline_rms_min','0.70*V2.BESS.rating.V_pcc_V', ...
    'Vline_rms_ini','V2.BESS.rating.V_pcc_V');
add_block(breaker,[model '/Step Load Breaker'],'Position',[940 310 1050 380], ...
    'control_port_option','ee.enum.controlport.ps');
add_block(cpl,[model '/One MW Step Load'],'Position',[1110 305 1260 380], ...
    'FRated','V2.BESS.rating.f_Hz','active_power','1e6','active_power_unit','W', ...
    'reactive_power','0.3e6','reactive_power_unit','V*A', ...
    'Vline_rms_min','0.70*V2.BESS.rating.V_pcc_V', ...
    'Vline_rms_ini','V2.BESS.rating.V_pcc_V');
add_block('simulink/Sources/Step',[model '/Load Step Command'], ...
    'Position',[705 315 795 345],'Time','.30','Before','1','After','0');
add_block(sps,[model '/Load Step to PS'],'Position',[820 300 920 360], ...
    'Unit','V','FilteringAndDerivatives','zero');
add_line(model,v2_physical_port(bess),v2_port([model '/Base Island Load'],'LConn',1),'autorouting','on');
add_line(model,v2_physical_port(bess),v2_port([model '/Step Load Breaker'],'LConn',2),'autorouting','on');
add_line(model,v2_port([model '/Step Load Breaker'],'RConn',1), ...
    v2_port([model '/One MW Step Load'],'LConn',1),'autorouting','on');
add_line(model,'Load Step Command/1','Load Step to PS/1');
add_line(model,v2_port([model '/Load Step to PS'],'RConn',1), ...
    v2_port([model '/Step Load Breaker'],'LConn',1),'autorouting','on');
end

function add_status_recorder(model)
s=[model '/BESS Status Recorder'];add_block('built-in/Subsystem',s, ...
    'Position',[810 470 1090 550],'BackgroundColor','[0.92,0.92,0.92]', ...
    'ContentPreviewEnabled','off');
add_block('simulink/Ports & Subsystems/In1',[s '/ResourceStatusBus'], ...
    'Position',[20 75 50 89],'OutDataTypeStr','Bus: ResourceStatusBus');
add_block('simulink/Signal Routing/Bus Selector',[s '/Status Selector'], ...
    'Position',[90 25 95 220], ...
    'OutputSignals','P_W,Q_var,Vpcc_V,frequency_Hz,available_power_W,power_headroom_W,current_limit_factor,energy_state_pu,Vdc_V,control_mode,healthy');
add_block('simulink/Sources/Clock',[s '/Time'],'Position',[90 240 120 270]);
add_block('simulink/Signal Routing/Mux',[s '/Regression Vector'], ...
    'Position',[250 25 255 285],'Inputs','12');
add_line(s,'Time/1','Regression Vector/1');
for k=1:11
    add_line(s,sprintf('Status Selector/%d',k),sprintf('Regression Vector/%d',k+1),'autorouting','on');
end
add_line(s,'ResourceStatusBus/1','Status Selector/1');
add_block('simulink/Sinks/To Workspace',[s '/BESS v2 Result'], ...
    'Position',[330 125 455 165],'VariableName','bess_v2_result', ...
    'SaveFormat','Array','MaxDataPoints','inf');
add_line(s,'Regression Vector/1','BESS v2 Result/1');v2_route_level(s);
end
