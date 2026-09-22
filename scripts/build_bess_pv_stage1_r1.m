% Build Stage 1 only from frozen R8 and the accepted R2.1 PV branch.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
r8File=fullfile(root,'build','BESS_GFM_10kV_Readable_R8.slx');
pvFile=fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx');
model='BESS_GFM_PV_GFL_Stage1_R1';modelFile=fullfile(root,'build',[model '.slx']);
pngFile=fullfile(root,'build',[model '.png']);
assert(isfile(r8File)&&isfile(pvFile),'Frozen R8 or accepted PV R2.1 artifact is missing.');
assert(strcmpi(sha256(r8File),'83f6cb534e71126fa7d6930047639230ba1ca2a531153e29cd9cc265325a40ba'), ...
    'Frozen R8 SHA-256 does not match the accepted artifact.');
copyfile(r8File,modelFile,'f');load_system(modelFile);load_system(pvFile);
run(fullfile(scriptDir,'init_bess_pv_stage1_r1.m'));

% Preserve R8 internals and make room for the accepted PV branch.
set_param([model '/03 Island Load Scenario'],'Name','04 Island Load');
set_param([model '/04 Supervision and Results'],'Name','05 Supervision and Results');
loadSys=[model '/04 Island Load'];sup=[model '/05 Supervision and Results'];
set_param([loadSys '/Adjusted_Island_Load'],'active_power','G.load.base_P_W', ...
    'reactive_power','G.load.base_Q_var');
set_param([loadSys '/One_MW_Step_Load'],'active_power','0','reactive_power','0');

pv=[model '/03 PV-GFL Branch'];
add_block('PV_GFL_864_SystemLevel_SM_R2_1_Readable/01 PV-GFL Branch R2.1',pv, ...
    'Position',[760 455 1080 665]);
set_param(pv,'BackgroundColor','[0.82,0.94,0.80]', ...
    'AttributesFormatString',sprintf(['Accepted R2.1 | 5 MW / 6.25 MVA\n' ...
    'local PCC PLL + circular dq limit\nonly AC coupling to BESS-GFM']));

% Put the PV command generator and recorder under supervision.  Only the
% compact CommandBus/StatusBus cross the PV branch boundary.
cmd=[sup '/01 PV Command Profile'];
add_block('PV_GFL_864_SystemLevel_SM_R2_1_Readable/02 Commissioning Command Profile',cmd, ...
    'Position',[70 330 310 500]);
set_param([cmd '/P Base Limit'],'UpperLimit','S1.pv.P_initial_W');
set_param([cmd '/P Increment'],'Time','S1.pv.P_step_time_s', ...
    'After','S1.pv.P_final_W-S1.pv.P_initial_W');
set_param([cmd '/Q Base Command'],'Value','S1.pv.Q_ref_var');
set_param([cmd '/Q Increment'],'Time','S1.pv.P_step_time_s','After','0');
set_param([cmd '/Enable Off'],'Time','10','After','0');
set_param([cmd '/Enable On'],'Time','11','After','0');
add_block('simulink/Ports & Subsystems/Out1',[sup '/PV_CommandBus'], ...
    'Position',[390 390 420 404],'Port','1');
add_block('simulink/Ports & Subsystems/In1',[sup '/PV_StatusBus'], ...
    'Position',[45 535 75 549],'Port','1');
add_line(sup,'01 PV Command Profile/1','PV_CommandBus/1','autorouting','on');

% Combined 33-channel Stage-1 log: R8(15), PV(16), fixed load P/Q.
add_block('simulink/Sources/Constant',[sup '/Pload Record'], ...
    'Position',[90 585 175 615],'Value','S1.load.P_W');
add_block('simulink/Sources/Constant',[sup '/Qload Record'], ...
    'Position',[90 630 175 660],'Value','S1.load.Q_var');
add_block('simulink/Signal Routing/Mux',[sup '/Stage1 Combined Mux'], ...
    'Position',[460 435 465 650],'Inputs','4');
add_block('simulink/Sinks/To Workspace',[sup '/Stage1 Results'], ...
    'Position',[520 525 625 565],'VariableName','stage1_result', ...
    'SaveFormat','Array','MaxDataPoints','inf');
add_line(sup,'R7_Result_Mux/1','Stage1 Combined Mux/1','autorouting','on');
add_line(sup,'PV_StatusBus/1','Stage1 Combined Mux/2','autorouting','on');
add_line(sup,'Pload Record/1','Stage1 Combined Mux/3','autorouting','on');
add_line(sup,'Qload Record/1','Stage1 Combined Mux/4','autorouting','on');
add_line(sup,'Stage1 Combined Mux/1','Stage1 Results/1');

% The only source-to-source coupling is this shared 10 kV physical node.
pvPH=get_param(pv,'PortHandles');loadPH=get_param(loadSys,'PortHandles');
supPH=get_param(sup,'PortHandles');
add_line(model,supPH.Outport(1),pvPH.Inport(1),'autorouting','on');
add_line(model,pvPH.Outport(1),supPH.Inport(1),'autorouting','on');
add_line(model,pvPH.RConn(1),loadPH.LConn(1),'autorouting','on');

% Architecture gate before save.
assert(numel(pvPH.Inport)==1&&numel(pvPH.Outport)==1&& ...
    numel([pvPH.LConn pvPH.RConn])==1,'PV branch interface is not minimal.');
tags=find_system(pv,'LookUnderMasks','all','RegExp','on','BlockType','(From|Goto)');
for k=1:numel(tags)
    tag=get_param(tags{k},'GotoTag');
    assert(~startsWith(tag,'R8_'),'PV branch contains a hidden R8 cross-source route.');
end

set_param([model '/01 BESS DC Source'],'Position',[65 175 330 355]);
set_param([model '/02 GFM PCS and Step-up'],'Position',[405 175 685 355]);
set_param(loadSys,'Position',[1100 175 1340 355], ...
    'AttributesFormatString','Fixed 5 MW + j1.5 Mvar\nload step disabled in Stage 1');
set_param(pv,'Position',[750 430 1080 650]);
set_param(sup,'Position',[405 500 685 675], ...
    'AttributesFormatString','PV command + combined telemetry\nstage1_result (33 channels)');
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'Stage 1 R1 — BESS-GFM + accepted PV-GFL R2.1, natural AC coordination only\n' ...
    'Fixed load 5 MW + j1.5 Mvar | PV 2 -> 3 MW at 0.30 s | no wind/coordinator/shared DC or angle\n' ...
    'PV external contract: CommandBus + PCC_10kV + StatusBus']));
a.Position=[55 25 1370 120];a.FontSize=14;a.FontWeight='bold';
set_param(model,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_bess_pv_stage1_r1.m'));" );
set_param(model,'StopTime','0.9','MaxStep','1e-5','Location',[45 45 1500 900]);
set_param(model,'SimulationCommand','update');save_system(model,modelFile);
try,print(['-s' model],'-dpng',pngFile);catch ME,fprintf('PNG_WARNING=%s\n',ME.message);end
close_system(model,0);close_system('PV_GFL_864_SystemLevel_SM_R2_1_Readable',0);
fprintf('BESS_PV_STAGE1_R1_BUILD_OK=1\nMODEL=%s\n',modelFile);

function h=sha256(file)
[ok,out]=system(sprintf('/usr/bin/shasum -a 256 "%s"',file));assert(ok==0);
h=extractBefore(strtrim(out),' ');
end
