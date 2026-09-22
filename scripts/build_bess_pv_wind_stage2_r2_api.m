% Add an external-algorithm Resource API layer to frozen Stage 2 R1.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
src=fullfile(root,'build','BESS_PV_WIND_STAGE2_R1.slx');
model='BESS_PV_WIND_STAGE2_R2_API';dst=fullfile(root,'build',[model '.slx']);
expected='d35a751620ba3a40442df958ad418100d4844f60f797b70c21f56985a2c2ffd9';
assert(strcmpi(sha256(src),expected),'Frozen Stage 2 R1 SHA-256 changed.');
copyfile(src,dst,'f');load_system(dst);run(fullfile(scriptDir,'init_bess_pv_wind_stage2_r1.m'));
sup=[model '/06 Supervision and Results'];pv=[model '/03 PV-GFL Branch'];wind=[model '/04 Wind-GFL Branch'];

% Supervision exports the already accepted BESS status vector and receives
% one flattened API diagnostic vector.  R1 logger remains unchanged.
add_block('simulink/Ports & Subsystems/Out1',[sup '/BESS_StatusRaw'], ...
    'Port','3','Position',[390 905 420 919]);
add_line(sup,'R7_Result_Mux/1','BESS_StatusRaw/1','autorouting','on');
add_block('simulink/Ports & Subsystems/In1',[sup '/Resource_API_Log'], ...
    'Port','3','Position',[45 930 75 944]);
add_block('simulink/Sinks/To Workspace',[sup '/Resource API Results'], ...
    'VariableName','resource_api_result','SaveFormat','Array','MaxDataPoints','inf', ...
    'Position',[125 915 255 955]);
add_line(sup,'Resource_API_Log/1','Resource API Results/1');

api=[model '/07 Resource API Layer'];
add_block('simulink/Ports & Subsystems/Subsystem',api,'Position',[690 735 1010 885]);
clear_subsystem(api);
inNames={'PV_ProfileCommand','Wind_ProfileCommand','BESS_StatusRaw','PV_StatusRaw','Wind_StatusRaw'};
outNames={'PV_Command','Wind_Command','PV_Status','Wind_Status','API_Log'};
for k=1:numel(inNames)
    add_block('simulink/Ports & Subsystems/In1',[api '/' inNames{k}], ...
        'Port',num2str(k),'Position',[25 30+45*k 55 44+45*k]);
end
for k=1:numel(outNames)
    add_block('simulink/Ports & Subsystems/Out1',[api '/' outNames{k}], ...
        'Port',num2str(k),'Position',[705 30+45*k 735 44+45*k]);
end
add_block('simulink/Sources/Constant',[api '/Coordinator Enable'], ...
    'Value','S2_API.runtime.coordinator_enable','SampleTime','S2_API.sample_time_s', ...
    'Position',[90 315 230 345]);
add_block('simulink/Sources/Constant',[api '/Resource Modes'], ...
    'Value','S2_API.runtime.mode','SampleTime','S2_API.sample_time_s', ...
    'Position',[90 360 230 390]);
add_block('simulink/Sources/Constant',[api '/BESS Desired Command'], ...
    'Value','S2_API.runtime.bess_command','SampleTime','S2_API.sample_time_s', ...
    'Position',[90 405 230 435]);
add_block('simulink/Sources/Constant',[api '/Coordinator Numeric Config'], ...
    'Value','S2_API.coordinator_config','SampleTime','inf', ...
    'Position',[90 450 230 480]);
mf=[api '/MATLAB Function Coordinator'];
add_block('simulink/User-Defined Functions/MATLAB Function',mf,'Position',[300 75 610 425]);
rt=sfroot;chart=find(rt,'-isa','Stateflow.EMChart','Path',mf);assert(numel(chart)==1);
chart.Script=coordinator_script();
set_data_size(chart,'bess','[1 15]');set_data_size(chart,'pv','[1 16]');
set_data_size(chart,'wind','[1 21]');set_data_size(chart,'pvLegacy','[1 3]');
set_data_size(chart,'windLegacy','[1 4]');set_data_size(chart,'coordEnable','1');
set_data_size(chart,'modes','[1 3]');set_data_size(chart,'bessDesired','[1 3]');
set_data_size(chart,'config','[1 11]');
set_data_size(chart,'pvCmdOut','[1 3]');set_data_size(chart,'windCmdOut','[1 4]');
set_data_size(chart,'apiLog','[1 48]');
% Coordinator decisions use a one-sample (5 ms) status snapshot.  Besides
% representing a realizable real-time exchange, this breaks the otherwise
% instantaneous status -> command -> plant -> status algebraic loop.
statusInputs={'BESS_StatusRaw','PV_StatusRaw','Wind_StatusRaw'};
statusDelayNames={'BESS Status Snapshot','PV Status Snapshot','Wind Status Snapshot'};
statusWidths=[15 16 21];
for k=1:3
    delayName=statusDelayNames{k};
    add_block('simulink/Discrete/Unit Delay',[api '/' delayName], ...
        'SampleTime','S2_API.sample_time_s', ...
        'InitialCondition',sprintf('zeros(1,%d)',statusWidths(k)), ...
        'Position',[150 55+45*k 225 79+45*k]);
    srcPH=get_param([api '/' statusInputs{k}],'PortHandles');
    delayPH=get_param([api '/' delayName],'PortHandles');
    mfPH=get_param(mf,'PortHandles');
    add_line(api,srcPH.Outport(1),delayPH.Inport(1),'autorouting','on');
    add_line(api,delayPH.Outport(1),mfPH.Inport(k),'autorouting','on');
end
add_line(api,'PV_ProfileCommand/1','MATLAB Function Coordinator/4','autorouting','on');
add_line(api,'Wind_ProfileCommand/1','MATLAB Function Coordinator/5','autorouting','on');
add_line(api,'Coordinator Enable/1','MATLAB Function Coordinator/6','autorouting','on');
add_line(api,'Resource Modes/1','MATLAB Function Coordinator/7','autorouting','on');
add_line(api,'BESS Desired Command/1','MATLAB Function Coordinator/8','autorouting','on');
add_line(api,'Coordinator Numeric Config/1','MATLAB Function Coordinator/9','autorouting','on');
add_line(api,'MATLAB Function Coordinator/1','PV_Command/1','autorouting','on');
add_line(api,'MATLAB Function Coordinator/2','Wind_Command/1','autorouting','on');
add_line(api,'PV_StatusRaw/1','PV_Status/1','autorouting','on');
add_line(api,'Wind_StatusRaw/1','Wind_Status/1','autorouting','on');
add_line(api,'MATLAB Function Coordinator/3','API_Log/1','autorouting','on');

% Reroute existing compact command/status vectors through the API layer.
% Resolve every boundary by its named internal Inport/Outport.  Do not rely
% on raw PortHandles ordering: mixed Simulink and Simscape conserving ports
% make that ordering visually plausible but unsafe for scripted rewiring.
supPvCmd=boundary_port(sup,'PV_CommandBus','out');
supWindCmd=boundary_port(sup,'Wind_CommandBus','out');
supBessStatus=boundary_port(sup,'BESS_StatusRaw','out');
supPvStatus=boundary_port(sup,'PV_StatusBus','in');
supWindStatus=boundary_port(sup,'Wind_StatusBus','in');
supApiLog=boundary_port(sup,'Resource_API_Log','in');
pvCmd=boundary_port(pv,'CommandBus','in');
pvStatus=boundary_port(pv,'StatusBus','out');
windCmd=boundary_port(wind,'WindCommandBus','in');
windStatus=boundary_port(wind,'StatusBus','out');
apiPvProfile=boundary_port(api,'PV_ProfileCommand','in');
apiWindProfile=boundary_port(api,'Wind_ProfileCommand','in');
apiBessStatus=boundary_port(api,'BESS_StatusRaw','in');
apiPvStatus=boundary_port(api,'PV_StatusRaw','in');
apiWindStatus=boundary_port(api,'Wind_StatusRaw','in');
apiPvCmd=boundary_port(api,'PV_Command','out');
apiWindCmd=boundary_port(api,'Wind_Command','out');
apiPvStatusOut=boundary_port(api,'PV_Status','out');
apiWindStatusOut=boundary_port(api,'Wind_Status','out');
apiLog=boundary_port(api,'API_Log','out');
delete_if_line(supPvCmd);delete_if_line(supWindCmd);
delete_if_line(pvStatus);delete_if_line(windStatus);
add_line(model,supPvCmd,apiPvProfile,'autorouting','on');
add_line(model,supWindCmd,apiWindProfile,'autorouting','on');
add_line(model,supBessStatus,apiBessStatus,'autorouting','on');
add_line(model,pvStatus,apiPvStatus,'autorouting','on');
add_line(model,windStatus,apiWindStatus,'autorouting','on');
add_line(model,apiPvCmd,pvCmd,'autorouting','on');
add_line(model,apiWindCmd,windCmd,'autorouting','on');
add_line(model,apiPvStatusOut,supPvStatus,'autorouting','on');
add_line(model,apiWindStatusOut,supWindStatus,'autorouting','on');
add_line(model,apiLog,supApiLog,'autorouting','on');

set_param(api,'BackgroundColor','[0.92,0.88,1.00]', ...
    'AttributesFormatString',sprintf(['ResourceCommand: P,Q,enable,mode | ResourceStatus: 12 fields\n' ...
    '5 ms State -> external .m algorithm -> Command | coordinator disabled by default']));
set_param([model '/04 Wind-GFL Branch'],'Position',[1055 520 1360 705]);
set_param(api,'Position',[690 735 1010 885]);
set_param(model,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_bess_pv_wind_stage2_r1.m'));" );
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'Stage 2 R2 API — frozen three-source plant + external-algorithm Resource API\n' ...
    '5 ms State -> MATLAB Function wrapper -> scripts/stage2_coordinator_algorithm.m -> Command\n' ...
    'Default modes AUTONOMOUS: numerical behavior must reproduce Stage 2 R1 baseline']));
a.Position=[45 20 1430 115];a.FontSize=14;a.FontWeight='bold';
% Save and report the actual root connections before compilation.  This is
% intentionally before update so a failed compile still leaves an auditable
% derivative; the frozen R1 source remains untouched.
save_system(model,dst);
report_boundary('PV command',apiPvCmd,pvCmd);
report_boundary('Wind command',apiWindCmd,windCmd);
report_boundary('PV status',pvStatus,apiPvStatus);
report_boundary('Wind status',windStatus,apiWindStatus);
report_boundary('API PV status',apiPvStatusOut,supPvStatus);
report_boundary('API Wind status',apiWindStatusOut,supWindStatus);
try
    set_param(model,'SimulationCommand','update');
catch ME
    fprintf(2,'R2_UPDATE_DIAGNOSTIC_BEGIN\n%s\nR2_UPDATE_DIAGNOSTIC_END\n', ...
        getReport(ME,'extended','hyperlinks','off'));
    rethrow(ME);
end
save_system(model,dst);
try,print(['-s' model],'-dpng',fullfile(root,'build','BESS_PV_WIND_STAGE2_R2_API.png'));catch ME,fprintf('PNG_WARNING=%s\n',ME.message);end
close_system(model,0);fprintf('STAGE2_R2_API_BUILD_OK=1\nMODEL=%s\n',dst);

function s=coordinator_script()
s=sprintf([ ...
'function [pvCmdOut,windCmdOut,apiLog] = f(bess,pv,wind,pvLegacy,windLegacy,coordEnable,modes,bessDesired,config)\n' ...
'%%#codegen\n' ...
'pvCmdOut=zeros(1,3); windCmdOut=zeros(1,4); apiLog=zeros(1,48);\n' ...
'status=zeros(3,12);\n' ...
'status(1,:)=[bess(2) bess(3) pv(15) bess(4) 5e6 5e6-abs(bess(2)) bess(14) 1 bess(6) bess(7) 0 5e6];\n' ...
'status(2,:)=[pv(2) pv(3) pv(15) pv(7) 5e6 5e6-pv(2) pv(13) 1 -1 -1 -1 5e6];\n' ...
'status(3,:)=[wind(2) wind(3) wind(15) wind(7) wind(17) max(0,wind(17)-wind(2)) wind(13) 1 wind(20)/1500 wind(20) wind(21) wind(18)];\n' ...
'cmd=[bessDesired(1) bessDesired(2) bessDesired(3) modes(1); pvLegacy(1) pvLegacy(2) pvLegacy(3) modes(2); windLegacy(2) windLegacy(3) windLegacy(4) modes(3)];\n' ...
'commandOut=stage2_coordinator_algorithm(status,cmd,coordEnable,config);\n' ...
'pvCmdOut=commandOut(2,1:3); windCmdOut=[windLegacy(1) commandOut(3,1:3)];\n' ...
'apiLog=[reshape(commandOut.'',1,12) reshape(status.'',1,36)];\n' ...
'end\n']);
end
function clear_subsystem(sys)
b=find_system(sys,'SearchDepth',1,'Type','Block');for k=2:numel(b),delete_block(b{k});end
end
function delete_if_line(port)
ln=get_param(port,'Line');if ln>0,delete_line(ln);end
end
function h=boundary_port(sys,blockName,direction)
% Map a named internal boundary block to the corresponding parent handle.
idx=str2double(get_param([sys '/' blockName],'Port'));
ph=get_param(sys,'PortHandles');
if strcmp(direction,'in')
    h=ph.Inport(idx);
else
    h=ph.Outport(idx);
end
end
function set_data_size(chart,name,sizeText)
d=find(chart,'-isa','Stateflow.Data','Name',name);assert(numel(d)==1,['Missing chart data: ' name]);
d.Props.Array.Size=sizeText;
end
function report_boundary(label,srcPort,dstPort)
fprintf('R2_WIRE %-16s %s/%s -> %s/%s\n',label, ...
    get_param(get_param(srcPort,'Parent'),'Name'),num2str(get_param(srcPort,'PortNumber')), ...
    get_param(get_param(dstPort,'Parent'),'Name'),num2str(get_param(dstPort,'PortNumber')));
end
function h=sha256(file)
[ok,out]=system(sprintf('/usr/bin/shasum -a 256 "%s"',file));assert(ok==0);h=extractBefore(strtrim(out),' ');
end
