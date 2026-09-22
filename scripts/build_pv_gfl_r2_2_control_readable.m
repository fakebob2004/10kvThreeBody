% Stage-1 derivative focused on PV-GFL control readability.
% No plant/control equation, parameter, scenario, solver or log is changed.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
stage1Base=fullfile(root,'build','BESS_GFM_PV_GFL_Stage1_R1.slx');
stage1Hash='e4df4591a206fa82f3eab43e7fad958e117157dda7d8eb1d6d5271ac7814614b';
assert(strcmpi(sha256(stage1Base),stage1Hash),'Frozen Stage-1 R1 changed.');

% Reproduce the already validated first readability pass.
run(fullfile(scriptDir,'build_bess_pv_stage1_r1_1_readable.m'));
source=fullfile(root,'build','BESS_GFM_PV_GFL_Stage1_R1_1_Readable.slx');
model='BESS_GFM_PV_GFL_Stage1_R1_2_PV_CONTROL_READABLE';
dst=fullfile(root,'build',[model '.slx']);copyfile(source,dst,'f');load_system(dst);

pv=[model '/03 PV-GFL Branch'];pcs=[pv '/01 GFL PCS'];
sec=[pcs '/01 Secondary Control'];pll=[sec '/01 Local SRF-PLL'];
ccg=[sec '/02 Current Command Generation'];status=[sec '/03 Status Assembly'];
primary=[pcs '/02 Primary Converter and Filter'];stepup=[pv '/02 Step-up and PCC'];

% One drawing = one abstraction layer. Do not ghost child contents through
% subsystem icons; the old previews were visually indistinguishable from
% duplicate or cross-boundary wiring.
subs=find_system(model,'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem');
for k=1:numel(subs)
    try,set_param(subs{k},'ContentPreviewEnabled','off');catch,end
end

% Remove only graphical lines with no valid source or destination.
delete_dangling_lines(model);

% State the ownership contract on every level a human reviewer opens.
set_param(pv,'AttributesFormatString',sprintf([ ...
    'CommandBus {P*,Q*,enable} | StatusBus {16 fields}\n' ...
    'local PCC PLL | 5 MW / 6.25 MVA | 0.69/10 kV']));
set_param(pcs,'AttributesFormatString',sprintf([ ...
    'local fast control + average PCS/filter\n' ...
    'no shared theta, PLL or DC link']));
set_param(sec,'AttributesFormatString',sprintf([ ...
    'P/Q command -> dq current -> local execution\n' ...
    'only compact buses cross this boundary']));
set_param(pll,'AttributesFormatString',sprintf([ ...
    'PV-local 10 kV PCC voltage only\n' ...
    'wrapped phase-error PI | 45-55 Hz']));
set_param(ccg,'AttributesFormatString',sprintf([ ...
    'P/Q -> dq | enable gate | circle limit\n' ...
    '150 Hz tracking -> abc current command']));
set_param(status,'AttributesFormatString',sprintf([ ...
    'ordered 16-field status vector\n' ...
    'measurement + command + PLL + limits']));
set_param(primary,'AttributesFormatString',sprintf([ ...
    'average controlled-current PCS\n' ...
    'interface RL + damped shunt C']));
set_param(stepup,'AttributesFormatString',sprintf([ ...
    '6.3 MVA, 0.69/10 kV\n' ...
    'PCC-local V/I/P/Q measurement']));

% Improve only the owner-level drawings. Child block positions and all
% functional connectivity remain from the accepted R1.1 derivative.
set_param([sec '/CommandBus'],'Position',[25 210 55 224]);
set_param(pll,'Position',[140 65 350 175]);
set_param(ccg,'Position',[420 180 685 330]);
set_param(status,'Position',[780 120 1020 295]);
set_param([sec '/StatusBus'],'Position',[1115 210 1145 224]);

% Current-command drawing: the main control chain occupies the upper plane;
% the eight telemetry From blocks and their mux occupy a separate lower
% plane. No signal or tag is renamed, and connectivity is unchanged.
setpos(ccg,'In2',[20 255 50 269]);
setpos(ccg,'Primary MeasurementBus From',[55 65 195 95]);
setpos(ccg,'Primary Measurement Selector',[225 45 230 135]);
setpos(ccg,'CommandBus Selector',[95 220 100 350]);
setpos(ccg,'P and Voltage',[245 190 250 250]);
setpos(ccg,'P to Id',[285 205 385 235]);
setpos(ccg,'Q and Voltage',[245 300 250 360]);
setpos(ccg,'Q to Iq',[285 315 385 345]);
setpos(ccg,'Enable Clamp',[285 400 365 430]);
setpos(ccg,'Raw dq Command',[420 220 425 340]);
setpos(ccg,'Enable Gate',[470 230 510 340]);
setpos(ccg,'Gated dq Command',[545 220 550 340]);
setpos(ccg,'dq Magnitude Input',[590 135 595 205]);
setpos(ccg,'dq Command Magnitude',[625 150 735 180]);
setpos(ccg,'Raw Limit Ratio',[770 150 890 180]);
setpos(ccg,'Current Circle Factor',[925 145 1005 190]);
setpos(ccg,'Current Limit Active',[1040 150 1145 180]);
setpos(ccg,'Id Limit',[650 235 700 270]);
setpos(ccg,'Id Tracking',[745 230 835 270]);
setpos(ccg,'Iq Limit',[650 310 700 345]);
setpos(ccg,'Iq Tracking',[745 305 835 345]);
setpos(ccg,'In1',[790 400 820 414]);
setpos(ccg,'Line-to-Phase Angle Compensation',[835 390 960 420]);
setpos(ccg,'dq theta',[875 220 880 350]);
setpos(ccg,'ia',[930 225 1070 255]);
setpos(ccg,'ib',[930 285 1070 315]);
setpos(ccg,'ic',[930 345 1070 375]);
setpos(ccg,'iabc Command',[1110 225 1115 375]);
setpos(ccg,'CurrentCommandBus Goto',[1190 285 1330 315]);

for k=1:8
    setpos(ccg,sprintf('CCG_Telem_%02d From',k),[1010 500+32*k 1120 520+32*k]);
end
setpos(ccg,'Status Telemetry Mux',[1180 520 1185 790]);
setpos(ccg,'StatusTelemetryBus',[1260 645 1290 659]);
% Keep producer-side Goto blocks near their signals, outside the main
% left-to-right path wherever possible.
setpos(ccg,'CCG_Telem_01 Goto',[115 370 215 386]);
setpos(ccg,'CCG_Telem_02 Goto',[115 395 215 411]);
setpos(ccg,'CCG_Telem_03 Goto',[695 200 795 216]);
setpos(ccg,'CCG_Telem_04 Goto',[695 360 795 376]);
setpos(ccg,'CCG_Telem_05 Goto',[385 75 485 91]);
setpos(ccg,'CCG_Telem_06 Goto',[1015 110 1115 126]);
setpos(ccg,'CCG_Telem_07 Goto',[1145 135 1245 151]);
setpos(ccg,'CCG_Telem_08 Goto',[370 440 470 456]);
ccgAnns=find_system(ccg,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(ccgAnns),delete(ccgAnns(k));end
labels={ ...
    '1  Command + voltage to dq reference',[55 15 390 35]; ...
    '2  Enable gate + circular current limit',[420 15 830 35]; ...
    '3  150 Hz tracking + dq/abc synthesis',[875 15 1280 35]; ...
    '4  Local telemetry export (8 signals)',[970 485 1320 505]};
for k=1:size(labels,1)
    an=Simulink.Annotation(ccg,labels{k,1});an.Position=labels{k,2};
    an.FontWeight='bold';an.FontSize=11;
end

route_all(ccg);route_all(sec);route_all(pv);route_all(pcs);

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'Stage 1 R1.2 — PV-GFL control-readable derivative, equations unchanged\n' ...
    'Coordinator may set P*/Q*/enable/mode; PV owns PLL, dq reference, current circle limit and execution\n' ...
    'BESS-GFM and PV-GFL remain coupled only through the 10 kV AC network']));
a.Position=[45 20 1410 100];a.FontSize=14;a.FontWeight='bold';
set_param(model,'SimulationCommand','update');
try,hilite_system(model,'none');catch,end
save_system(model,dst);

systems={model,pv,pcs,sec,pll,ccg,status,primary,stepup};
names={'PV_R2_2_01_Top','PV_R2_2_02_Branch','PV_R2_2_03_PCS', ...
    'PV_R2_2_04_Secondary_Control','PV_R2_2_05_Local_PLL', ...
    'PV_R2_2_06_Current_Command','PV_R2_2_07_Status_Assembly', ...
    'PV_R2_2_08_Primary_Power','PV_R2_2_09_Stepup_PCC'};
for k=1:numel(systems)
    try
        set_param(systems{k},'ZoomFactor','FitSystem');hilite_system(systems{k},'none');
        print(['-s' systems{k}],'-dpng',fullfile(root,'build',[names{k} '.png']));
    catch ME
        warning('PNG export failed for %s: %s',systems{k},ME.message);
    end
end
fprintf('PV_GFL_R2_2_CONTROL_READABLE_BUILD_OK=1\nMODEL=%s\n',dst);
close_system(model,0);

function delete_dangling_lines(root)
ln=find_system(root,'FindAll','on','Type','line');
for k=1:numel(ln)
    try
        if strcmpi(get_param(ln(k),'LineType'),'connection'),continue,end
        src=get_param(ln(k),'SrcPortHandle');dst=get_param(ln(k),'DstPortHandle');
        if isempty(src)||src<0||isempty(dst)||all(dst<0),delete_line(ln(k));end
    catch
    end
end
end
function route_all(sys)
ln=find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
if ~isempty(ln),Simulink.BlockDiagram.routeLine(ln);end
end
function setpos(parent,name,pos)
p=[parent '/' name];assert(getSimulinkBlockHandle(p)>0,['Missing block: ' p]);
set_param(p,'Position',pos);
end
function h=sha256(file)
[ok,out]=system(sprintf('/usr/bin/shasum -a 256 "%s"',file));assert(ok==0);
h=extractBefore(strtrim(out),' ');
end
