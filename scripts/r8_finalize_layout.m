% Final visual layout/export for the staged R8 hierarchy build.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
modelName='BESS_GFM_10kV_Readable_R8';
modelFile=fullfile(projectRoot,'build',[modelName '.slx']);
pngFile=fullfile(projectRoot,'build',[modelName '.png']);
load_system(modelFile);open_system(modelName);
repair_monitor_limit_route(modelName);

% Logging is a sink; remove a possible unused generated interface.
sys=[modelName '/04 Supervision and Results'];
unused=find_system(sys,'SearchDepth',1,'BlockType','Outport');
for k=1:numel(unused),delete_block(unused{k});end

style([modelName '/01 BESS DC Source'],[90 190 350 390], ...
    '[1.0,0.95,0.72]','Battery + bidirectional DC/DC\n1200 V / 10 MWh -> 1500 Vdc');
style([modelName '/02 GFM PCS and Step-up'],[500 190 800 390], ...
    '[0.78,0.90,1.0]','GFM control + PCS/LCL + transformer\n6.25 MVA, 0.69 / 10 kV');
style([modelName '/03 Island Load Scenario'],[950 190 1190 390], ...
    '[0.91,0.84,0.98]','4 MW base + 1 MW step\nt = 0.30 s');
style([modelName '/04 Supervision and Results'],[500 540 800 680], ...
    '[0.90,0.90,0.90]','Read-only telemetry\ngfm_r7_result (15 channels)');

style([modelName '/01 BESS DC Source/01 Battery and DC Link'], ...
    [70 100 310 280],'[1.0,0.95,0.72]','1200 V / 10 MWh\n1500 V DC link');
style([modelName '/01 BESS DC Source/02 Bidirectional DC-DC Control'], ...
    [430 100 700 280],'[0.82,0.94,0.80]','Vdc PI: 10 Hz\nIbat PI: 300 Hz');
style([modelName '/02 GFM PCS and Step-up/03 GFM Control and Limits'], ...
    [70 100 360 300],'[0.78,0.90,1.0]','P-f / Q-V / Virtual Z\nAC limit: 1.20 pu');
style([modelName '/02 GFM PCS and Step-up/04 PCS Filter and Transformer'], ...
    [480 100 760 300],'[1.0,0.86,0.70]','6.25 MVA PCS + LCL\n0.69 / 10 kV transformer');

systems={ ...
    '01 BESS DC Source', ...
    '01 BESS DC Source/01 Battery and DC Link', ...
    '01 BESS DC Source/02 Bidirectional DC-DC Control', ...
    '02 GFM PCS and Step-up', ...
    '02 GFM PCS and Step-up/03 GFM Control and Limits', ...
    '02 GFM PCS and Step-up/04 PCS Filter and Transformer', ...
    '03 Island Load Scenario','04 Supervision and Results'};
for k=1:numel(systems)
    s=[modelName '/' systems{k}];
    try,Simulink.BlockDiagram.arrangeSystem(s,'FullLayout','true');catch,end
    set_param(s,'ScreenColor','white');
    try,set_param(s,'ContentPreviewEnabled','off');catch,end
end

anns=find_system(modelName,'FindAll','on','Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(modelName,sprintf([ ...
    'BESS-GFM 5 MW / 10 MWh — Human-readable hierarchy (R8)\n' ...
    'Power path: BESS DC Source  ->  GFM PCS + Step-up  ->  10 kV Island Load\n' ...
    'Boundary rule: each plant is packaged with its local controller; PV/Wind not included']));
a.Position=[80 40 1160 125];a.FontSize=16;a.FontWeight='bold';
a=Simulink.Annotation(modelName,sprintf([ ...
    'How to read: top level shows only power-domain boundaries; double-click for detailed modules.\n' ...
    'Blue lines are explicit Simscape power connections. Control/telemetry use named Goto/From routes.\n' ...
    'Key signals: Vdc_V, Ibat_A, P_ac_W, Q_ac_var, duty_pu, modulation_pu.\n' ...
    'Validated scenario: 4 MW -> 5 MW at 0.30 s; strict 4500 A current limiting and SOC direction interlock enabled.']));
a.Position=[80 760 1230 875];a.FontSize=11;

set_param(modelName,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_bess_gfm_dynamic_r7.m'));" );
set_param(modelName,'Location',[80 80 1450 920],'ZoomFactor','FitSystem');
try,hilite_system(modelName,'none');catch,end
save_system(modelName,modelFile);
set_param(modelName,'SimulationCommand','update');
fprintf('BESS_GFM_READABLE_R8_UPDATE_OK=1\n');
print(['-s' modelName],'-dpng',pngFile);
for k=1:numel(systems)
    out=fullfile(projectRoot,'build',sprintf('R8_%02d_%s.png',k, ...
        regexprep(systems{k},'[^A-Za-z0-9]+','_')));
    try,print(['-s' modelName '/' systems{k}],'-dpng',out);catch,end
end
save_system(modelName,modelFile);close_system(modelName,0);
fprintf('BESS_GFM_READABLE_R8_MODEL=%s\n',modelFile);

function style(block,pos,bg,attrs)
set_param(block,'Position',pos,'BackgroundColor',bg,'ForegroundColor','black', ...
    'ShowPortLabels','FromPortIcon','AttributesFormatString',attrs);
end

function repair_monitor_limit_route(model)
% The 14th telemetry channel is the AC current-limit factor.  Replace the
% final generated interface by the existing global route from the GFM unit.
sys=[model '/04 Supervision and Results'];
b=find_system(sys,'SearchDepth',1,'BlockType','Inport');
if isempty(b),return;end
b=b{1};pos=get_param(b,'Position');p=get_param(b,'PortHandles');
line=get_param(p.Outport,'Line');dst=[];
if line>0,dst=get_param(line,'DstPortHandle');end
delete_block(b);
from=[sys '/AC_Current_Limit_Factor_Route'];
add_block('simulink/Signal Routing/From',from, ...
    'GotoTag','R8_03_GFM_Control_and_Limits_p6_signal', ...
    'Position',pos,'ShowName','off');
fp=get_param(from,'PortHandles');
for k=1:numel(dst)
    if dst(k)>0&&get_param(dst(k),'Line')<0
        add_line(sys,fp.Outport,dst(k),'autorouting','on');
    end
end
end
