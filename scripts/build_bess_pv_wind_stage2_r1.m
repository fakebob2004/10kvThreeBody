% Build Stage 2 R1 without modifying any accepted source artifact.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
stage1File=fullfile(root,'build','BESS_GFM_PV_GFL_Stage1_R1.slx');
windFile=fullfile(root,'build','Wind_GFL_5MW_SystemLevel_SM_R1.slx');
model='BESS_PV_WIND_STAGE2_R1';modelFile=fullfile(root,'build',[model '.slx']);
assert(strcmpi(sha256(stage1File),'e4df4591a206fa82f3eab43e7fad958e117157dda7d8eb1d6d5271ac7814614b'), ...
    'Frozen Stage 1 R1 SHA-256 changed.');
assert(isfile(windFile),'Accepted Wind-GFL R1 artifact is missing.');
copyfile(stage1File,modelFile,'f');load_system(modelFile);load_system(windFile);
run(fullfile(scriptDir,'init_bess_pv_wind_stage2_r1.m'));

% Make one deterministic slot for the wind resource.
set_param([model '/04 Island Load'],'Name','05 Island Load');
set_param([model '/05 Supervision and Results'],'Name','06 Supervision and Results');
loadSys=[model '/05 Island Load'];sup=[model '/06 Supervision and Results'];

wind=[model '/04 Wind-GFL Branch'];
add_block('Wind_GFL_5MW_SystemLevel_SM_R1/01 Wind-GFL System-Level Branch',wind, ...
    'Position',[750 655 1080 845]);
set_param(wind,'BackgroundColor','[0.86,0.92,1.00]', ...
    'AttributesFormatString',sprintf(['Accepted Wind R1 | 5 MW / 6.25 MVA\n' ...
    'local PCC PLL + circular dq limit\nonly AC coupling to BESS/PV']));
% The accepted PV and Wind branches were independently commissioned and
% therefore inherited the same local diagnostic workspace name.  Rename
% only the Wind copy to keep resource-local diagnostics independent.
set_param([wind '/03 GFL PCS/02 Primary Converter and Filter/Local Voltage Record'], ...
    'VariableName','wind_stage2_vabc');

% Wind command/status remain owned by supervision; only compact vectors
% cross the resource boundary.
windCmd=[sup '/02 Wind Command Profile'];
add_block('Wind_GFL_5MW_SystemLevel_SM_R1/02 Wind Commissioning Command Profile',windCmd, ...
    'Position',[70 675 310 845]);
set_param([windCmd '/P Available Base'],'Value','S2.wind.P_available_W');
set_param([windCmd '/P Available Increment'],'After','0','Time','S2.event_time_s');
set_param([windCmd '/P Base Limit'],'UpperLimit','S2.wind.P_base_W');
set_param([windCmd '/P Increment'],'After','S2.wind.P_step_W','Time','S2.event_time_s');
set_param([windCmd '/Q Base Command'],'Value','0');set_param([windCmd '/Q Increment'],'After','0');
set_param([windCmd '/Enable Off'],'Time','10','After','0');
set_param([windCmd '/Enable On'],'Time','11','After','0');
add_block('simulink/Ports & Subsystems/Out1',[sup '/Wind_CommandBus'], ...
    'Position',[390 735 420 749],'Port','2');
add_block('simulink/Ports & Subsystems/In1',[sup '/Wind_StatusBus'], ...
    'Position',[45 865 75 879],'Port','2');
add_line(sup,'02 Wind Command Profile/1','Wind_CommandBus/1','autorouting','on');

% Extend the accepted Stage-1 logger from 33 to 54 channels:
% BESS(15), PV(16), Wind(21), fixed-load P/Q(2).
mux=[sup '/Stage1 Combined Mux'];set_param(mux,'Name','Stage2 Combined Mux');
mux=[sup '/Stage2 Combined Mux'];mph=get_param(mux,'PortHandles');
for idx=3:4
    ln=get_param(mph.Inport(idx),'Line');if ln>0,delete_line(ln);end
end
set_param(mux,'Inputs','5');
add_line(sup,'Wind_StatusBus/1','Stage2 Combined Mux/3','autorouting','on');
add_line(sup,'Pload Record/1','Stage2 Combined Mux/4','autorouting','on');
add_line(sup,'Qload Record/1','Stage2 Combined Mux/5','autorouting','on');
set_param([sup '/Stage1 Results'],'Name','Stage2 Results','VariableName','stage2_result');
set_param([sup '/Pload Record'],'Value','S2.load.base_P_W');
set_param([sup '/Qload Record'],'Value','S2.load.base_Q_var');

% Default Stage-2 drawing is Case A: PV 2->3 MW, Wind fixed at 2 MW,
% fixed 5 MW+j1.5 Mvar load.  Validator reconfigures the same blocks for
% Cases B-D without altering controller equations.
set_param([loadSys '/Adjusted_Island_Load'],'active_power','S2.load.base_P_W', ...
    'reactive_power','S2.load.base_Q_var');
set_param([loadSys '/One_MW_Step_Load'],'active_power','0','reactive_power','0');

windPH=get_param(wind,'PortHandles');loadPH=get_param(loadSys,'PortHandles');
supPH=get_param(sup,'PortHandles');
add_line(model,supPH.Outport(2),windPH.Inport(1),'autorouting','on');
add_line(model,windPH.Outport(1),supPH.Inport(2),'autorouting','on');
add_line(model,windPH.RConn(1),loadPH.LConn(1),'autorouting','on');

% Architecture gates: minimal boundaries and no cross-resource named route.
check_resource([model '/03 PV-GFL Branch'],1,1,1);
check_resource(wind,1,1,1);
for resource={[model '/03 PV-GFL Branch'],wind}
    tags=find_system(resource{1},'LookUnderMasks','all','RegExp','on','BlockType','(From|Goto)');
    for k=1:numel(tags)
        tag=get_param(tags{k},'GotoTag');
        assert(~startsWith(tag,'R8_'),'GFL branch reads a hidden BESS route.');
    end
end

set_param([model '/01 BESS DC Source'],'Position',[55 175 305 350]);
set_param([model '/02 GFM PCS and Step-up'],'Position',[360 175 635 350]);
set_param([model '/03 PV-GFL Branch'],'Position',[705 175 1010 365]);
set_param(wind,'Position',[705 500 1010 690]);
set_param(loadSys,'Position',[1110 260 1360 445]);
set_param(sup,'Position',[360 500 635 720], ...
    'AttributesFormatString','PV/Wind commands + 54-channel telemetry\nstage2_result');
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'Stage 2 R1 — BESS-GFM + PV-GFL + Wind-GFL, natural AC coupling baseline\n' ...
    'Independent converters/DC links/PLLs | common 10 kV conserving network only\n' ...
    'Default Case A: PV 2->3 MW, Wind 2 MW, Load 5 MW+j1.5 Mvar | no coordinator']));
a.Position=[45 20 1410 115];a.FontSize=14;a.FontWeight='bold';
set_param(model,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_bess_pv_wind_stage2_r1.m'));" );
set_param(model,'StopTime','1.2','MaxStep','1e-5','Location',[40 40 1510 920]);
set_param(model,'SimulationCommand','update');save_system(model,modelFile);
try,set_param(model,'SampleTimeColors','off');catch,end
try,print(['-s' model],'-dpng',fullfile(root,'build','BESS_PV_WIND_STAGE2_R1.png'));catch ME,fprintf('PNG_WARNING=%s\n',ME.message);end
close_system(model,0);close_system('Wind_GFL_5MW_SystemLevel_SM_R1',0);
fprintf('STAGE2_R1_BUILD_OK=1\nMODEL=%s\n',modelFile);

function check_resource(sys,ni,no,np)
ph=get_param(sys,'PortHandles');
assert(numel(ph.Inport)==ni&&numel(ph.Outport)==no&&numel([ph.LConn ph.RConn])==np, ...
    ['Minimal boundary failed: ' sys]);
end
function h=sha256(file)
[ok,out]=system(sprintf('/usr/bin/shasum -a 256 "%s"',file));assert(ok==0);h=extractBefore(strtrim(out),' ');
end
