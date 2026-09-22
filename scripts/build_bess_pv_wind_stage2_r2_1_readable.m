% Readability-only derivative of the accepted Stage-2 R2 Resource API model.
% No controller, plant, interface value, scenario, solver, or logging value changes.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
src=fullfile(root,'build','BESS_PV_WIND_STAGE2_R2_API.slx');
model='BESS_PV_WIND_STAGE2_R2_1_READABLE';
dst=fullfile(root,'build',[model '.slx']);
expected='ef0cccabfebb035bb9385d955d3462050f51d5344303cbdbbf29df78220efaaf';
assert(strcmpi(sha256(src),expected),'Accepted Stage-2 R2 API SHA-256 changed.');
copyfile(src,dst,'f');load_system(dst);

blocks={'01 BESS DC Source','02 GFM PCS and Step-up','03 PV-GFL Branch', ...
    '04 Wind-GFL Branch','05 Island Load','06 Supervision and Results', ...
    '07 Resource API Layer'};
for k=1:numel(blocks)
    set_param([model '/' blocks{k}],'ContentPreviewEnabled','off');
end

% Top level: physical resources occupy the upper engineering plane.  The
% API and scenario/telemetry plane stays below, with no control line hidden.
setpos(model,'01 BESS DC Source',[40 245 270 395]);
setpos(model,'02 GFM PCS and Step-up',[335 220 600 420]);
setpos(model,'03 PV-GFL Branch',[725 95 1010 280]);
setpos(model,'04 Wind-GFL Branch',[725 385 1010 570]);
setpos(model,'05 Island Load',[1160 245 1400 425]);
set_param([model '/01 BESS DC Source'],'AttributesFormatString', ...
    sprintf('BESS energy + local DC/DC\n1200 V, 10 MWh -> 1500 Vdc'));
set_param([model '/02 GFM PCS and Step-up'],'AttributesFormatString', ...
    sprintf('GFM voltage/frequency owner\n6.25 MVA, 0.69/10 kV'));
set_param([model '/03 PV-GFL Branch'],'AttributesFormatString', ...
    sprintf('PV-GFL | local PLL + PQ/current control\n5 MW / 6.25 MVA | independent DC link'));
set_param([model '/04 Wind-GFL Branch'],'AttributesFormatString', ...
    sprintf('Wind-GFL | system-level average PCS\n5 MW / 6.25 MVA | local PLL'));
set_param([model '/05 Island Load'],'AttributesFormatString', ...
    sprintf('10 kV PCC load\n5 MW + j1.5 Mvar'));
set_param([model '/06 Supervision and Results'],'AttributesFormatString', ...
    sprintf('Scenario profiles + telemetry\nno fast-control ownership'));
set_param([model '/07 Resource API Layer'],'AttributesFormatString', ...
    sprintf('5 ms ResourceStatus -> Coordinator -> ResourceCommand\nfast dq / PLL / current loops remain local'));

% Resource API drawing: raw status is sampled once per 5 ms decision,
% legacy profiles enter as autonomous commands, and status monitoring is
% a transparent pass-through.  This is layout only.
api=[model '/07 Resource API Layer'];
delete_dangling_lines(api);
setpos(api,'PV_ProfileCommand',[20 70 50 84]);
setpos(api,'Wind_ProfileCommand',[20 115 50 129]);
setpos(api,'BESS_StatusRaw',[20 185 50 199]);
setpos(api,'PV_StatusRaw',[20 230 50 244]);
setpos(api,'Wind_StatusRaw',[20 275 50 289]);
setpos(api,'BESS Status Snapshot',[125 175 245 205]);
setpos(api,'PV Status Snapshot',[125 220 245 250]);
setpos(api,'Wind Status Snapshot',[125 265 245 295]);
setpos(api,'MATLAB Function Coordinator',[330 85 610 350]);
setpos(api,'Coordinator Enable',[90 390 230 420]);
setpos(api,'Resource Modes',[260 390 400 420]);
setpos(api,'BESS Desired Command',[430 390 570 420]);
setpos(api,'Coordinator Numeric Config',[600 390 750 420]);
setpos(api,'PV_Command',[735 70 765 84]);
setpos(api,'Wind_Command',[735 115 765 129]);
setpos(api,'PV_Status',[735 230 765 244]);
setpos(api,'Wind_Status',[735 275 765 289]);
setpos(api,'API_Log',[735 330 765 344]);
set_param(api,'AttributesFormatString',sprintf([ ...
    'Typed API: Command {P,Q,enable,mode} | Status {12 fields}\n' ...
    'One-sample status snapshot makes the 5 ms exchange causal']));

% Supervision owns scenarios/logging; the API owns the coordinator boundary.
% They interact heavily with each other but expose only resource-level
% command/status signals, so package them together at the plant top level.
sup=[model '/06 Supervision and Results'];
before=find_system(model,'SearchDepth',1,'BlockType','SubSystem');
Simulink.BlockDiagram.createSubsystem([getSimulinkBlockHandle(sup) getSimulinkBlockHandle(api)]);
after=find_system(model,'SearchDepth',1,'BlockType','SubSystem');
fresh=setdiff(after,before,'stable');assert(numel(fresh)==1,'Coordination grouping was not deterministic.');
set_param(fresh{1},'Name','06 Coordination and Monitoring');
coord=[model '/06 Coordination and Monitoring'];
sup=[coord '/06 Supervision and Results'];api=[coord '/07 Resource API Layer'];
set_param(coord,'Position',[350 635 790 845],'ContentPreviewEnabled','off', ...
    'BackgroundColor','[0.90,0.88,0.96]', ...
    'AttributesFormatString',sprintf([ ...
    'Resource API + scenario profiles + telemetry\n' ...
    'resource boundaries only; no local dq/PLL ownership']));
setpos(coord,'06 Supervision and Results',[40 85 315 285]);
setpos(coord,'07 Resource API Layer',[430 55 790 315]);
setpos(coord,'PV_StatusRaw',[385 205 415 219]);
setpos(coord,'Wind_StatusRaw',[385 265 415 279]);
setpos(coord,'PV_Command',[835 95 865 109]);
setpos(coord,'Wind_Command',[835 155 865 169]);
route_all(coord);route_all(api);

% Re-route existing lines after block motion; endpoints and connectivity do
% not change.  Simscape and Simulink lines are both included.
route_all(model);
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'Stage 2 R2.1 — Three independent resources on one 10 kV AC PCC\n' ...
    'BESS-GFM forms V/f | PV-GFL and Wind-GFL inject P/Q using local PLLs\n' ...
    'Only AC-network coupling; Resource API is supervisory at 5 ms']));
a.Position=[40 20 1390 90];a.FontSize=15;a.FontWeight='bold';

set_param(model,'SimulationCommand','update');
try,set_param(model,'SampleTimeColors','off');catch,end
try,hilite_system(model,'none');hilite_system(coord,'none');hilite_system(api,'none');catch,end
set_param(model,'ZoomFactor','FitSystem');set_param(api,'ZoomFactor','FitSystem');
save_system(model,dst);

systems={model,coord,api,[model '/01 BESS DC Source'], ...
    [model '/02 GFM PCS and Step-up'],[model '/03 PV-GFL Branch'], ...
    [model '/04 Wind-GFL Branch']};
pngNames={'STAGE2_R2_1_01_Top','STAGE2_R2_1_02_Coordination', ...
    'STAGE2_R2_1_03_Resource_API','STAGE2_R2_1_04_BESS_DC', ...
    'STAGE2_R2_1_05_BESS_GFM_PCS','STAGE2_R2_1_06_PV_GFL', ...
    'STAGE2_R2_1_07_Wind_GFL'};
for k=1:numel(systems)
    try
        print(['-s' systems{k}],'-dpng',fullfile(root,'build',[pngNames{k} '.png']));
    catch ME
        warning('PNG export failed for %s: %s',systems{k},ME.message);
    end
end
fprintf('STAGE2_R2_1_READABLE_BUILD_OK=1\nSOURCE_SHA256=%s\nMODEL=%s\n',expected,dst);
close_system(model,0);

function setpos(parent,name,pos)
p=[parent '/' name];assert(getSimulinkBlockHandle(p)>0,['Missing block: ' p]);
set_param(p,'Position',pos);
end
function route_all(sys)
ln=find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
if ~isempty(ln),Simulink.BlockDiagram.routeLine(ln);end
end
function delete_dangling_lines(sys)
ln=find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
for k=1:numel(ln)
    src=get_param(ln(k),'SrcPortHandle');dst=get_param(ln(k),'DstPortHandle');
    if isempty(src)||src<0||isempty(dst)||all(dst<0),delete_line(ln(k));end
end
end
function h=sha256(file)
[ok,out]=system(sprintf('/usr/bin/shasum -a 256 "%s"',file));assert(ok==0);
h=extractBefore(strtrim(out),' ');
end
