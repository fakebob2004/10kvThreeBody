% Readability-only derivative of the accepted Stage-1 R1 model.
% No controller, plant, measurement, scenario, solver, or logging value is changed.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
src=fullfile(root,'build','BESS_GFM_PV_GFL_Stage1_R1.slx');
model='BESS_GFM_PV_GFL_Stage1_R1_1_Readable';
dst=fullfile(root,'build',[model '.slx']);
expected='e4df4591a206fa82f3eab43e7fad958e117157dda7d8eb1d6d5271ac7814614b';
assert(strcmpi(sha256(src),expected),'Accepted Stage-1 R1 SHA-256 changed.');
copyfile(src,dst,'f');load_system(dst);

pv=[model '/03 PV-GFL Branch'];
pcs=[pv '/01 GFL PCS'];
sec=[pcs '/01 Secondary Control'];
pri=[pcs '/02 Primary Converter and Filter'];
step=[pv '/02 Step-up and PCC'];

% Remove four dangling createSubsystem outputs.  Out4 is the sole real
% StatusBus connection; preserve it and make the boundary deterministic.
for n={'Out1','Out2','Out3','Out5'}
    p=[sec '/' n{1}];if getSimulinkBlockHandle(p)>0,delete_block(p);end
end
set_param([sec '/In1'],'Name','CommandBus','Port','1');
set_param([sec '/Out4'],'Name','StatusBus','Port','1');

% First-level Secondary Control contains only three functional modules plus
% its explicit boundary ports.  Group by signal semantics, never by ConnN.
pllBlocks=paths(sec,{'PCC MeasurementBus From','PCC Measurement Selector','02 Local SRF-PLL'});
pll=group_exact(sec,pllBlocks,'01 Local SRF-PLL');
core=find_system(pll,'SearchDepth',1,'Name','02 Local SRF-PLL');
if ~isempty(core),set_param(core{1},'Name','SRF-PLL Core');end

cgNames={'CommandBus Selector','Current Circle Factor','Current Limit Active', ...
    'CurrentCommandBus Goto','Enable Clamp','Enable Gate','Gated dq Command', ...
    'Id Limit','Id Tracking','Iq Limit','Iq Tracking', ...
    'Line-to-Phase Angle Compensation','P and Voltage','P to Id', ...
    'Primary Measurement Selector','Primary MeasurementBus From', ...
    'Q and Voltage','Q to Iq','Raw Limit Ratio','Raw dq Command', ...
    'dq Command Magnitude','dq Magnitude Input','dq theta','ia','ib','ic', ...
    'iabc Command'};
cg=group_exact(sec,paths(sec,cgNames),'02 Current Command Generation');

stNames={'StatusBus Elements','Time','Current Limit Status','omega to Hz'};
st=group_exact(sec,paths(sec,stNames),'03 Status Assembly');
consolidate_current_status(sec,cg,st);

% Deterministic first-level control drawing.
set_param([sec '/CommandBus'],'Position',[25 245 55 259]);
set_param(pll,'Position',[130 80 330 190]);
set_param(cg,'Position',[405 185 660 330]);
set_param(st,'Position',[765 155 980 300]);
set_param([sec '/StatusBus'],'Position',[1080 225 1110 239]);
Simulink.BlockDiagram.arrangeSystem(pll);
Simulink.BlockDiagram.arrangeSystem(st);

% Correct the current-command drawing after grouping: control chain flows
% from references on the left to CurrentCommandBus on the right.
setpos(cg,'CommandBus Selector',[100 250 105 360]);
setpos(cg,'P and Voltage',[245 215 250 275]);
setpos(cg,'Q and Voltage',[245 330 250 390]);
setpos(cg,'P to Id',[285 230 385 260]);
setpos(cg,'Q to Iq',[285 345 385 375]);
setpos(cg,'Raw dq Command',[420 245 425 365]);
setpos(cg,'Enable Clamp',[285 430 365 460]);
setpos(cg,'Enable Gate',[470 250 510 360]);
setpos(cg,'Gated dq Command',[545 245 550 365]);
setpos(cg,'dq Magnitude Input',[590 170 595 240]);
setpos(cg,'dq Command Magnitude',[625 185 735 215]);
setpos(cg,'Raw Limit Ratio',[770 185 890 215]);
setpos(cg,'Current Circle Factor',[925 180 1005 225]);
setpos(cg,'Current Limit Active',[1040 185 1145 215]);
setpos(cg,'Id Limit',[650 270 700 305]);
setpos(cg,'Iq Limit',[650 345 700 380]);
setpos(cg,'Id Tracking',[745 265 835 305]);
setpos(cg,'Iq Tracking',[745 340 835 380]);
setpos(cg,'Line-to-Phase Angle Compensation',[710 430 835 460]);
setpos(cg,'dq theta',[875 265 880 400]);
setpos(cg,'ia',[920 255 1060 285]);
setpos(cg,'ib',[920 315 1060 345]);
setpos(cg,'ic',[920 375 1060 405]);
setpos(cg,'iabc Command',[1100 260 1105 405]);
setpos(cg,'CurrentCommandBus Goto',[1180 320 1320 350]);
setpos(cg,'Primary MeasurementBus From',[70 65 210 95]);
setpos(cg,'Primary Measurement Selector',[245 45 250 135]);

% Primary power stage: physical energy path is left-to-right; conversion
% and telemetry stay below it.
set_param([pri '/Conn1'],'Name','AC_690V');
setpos(pri,'CurrentCommandBus From',[25 45 165 75]);
setpos(pri,'Current Command to PS',[190 205 290 265]);
setpos(pri,'Average GFL Current Injection',[235 55 340 135]);
setpos(pri,'Converter Neutral',[255 170 285 200]);
setpos(pri,'Converter-Side VI Sensor',[400 55 495 135]);
setpos(pri,'Interface RL',[555 70 640 120]);
setpos(pri,'Damped Shunt C',[665 165 750 215]);
setpos(pri,'Filter Ground',[780 175 810 205]);
setpos(pri,'AC_690V',[855 85 885 99]);
setpos(pri,'vabc to Simulink',[390 255 490 291]);
setpos(pri,'iabc to Simulink',[510 255 610 291]);
setpos(pri,'Line Voltage Peak Magnitude',[390 320 560 356]);
setpos(pri,'Actual Current Magnitude',[590 320 740 356]);
setpos(pri,'Primary MeasurementBus',[775 270 780 360]);
setpos(pri,'Primary MeasurementBus Goto',[825 300 960 330]);
setpos(pri,'Local Voltage Record',[825 350 925 380]);

% Step-up: identify ports from existing physical placement/connectivity,
% then give them engineering names.  Measurement plumbing stays below.
set_param([step '/Conn2'],'Name','AC_690V');
set_param([step '/Conn1'],'Name','PCC_10kV');
setpos(step,'AC_690V',[20 80 50 94]);
setpos(step,'T_PV_0p69_10kV',[125 35 240 125]);
setpos(step,'PCC 10kV VI Sensor',[310 35 385 125]);
setpos(step,'PV PCC Power Sensor',[455 52 535 118]);
setpos(step,'PCC_10kV',[650 80 680 94]);
setpos(step,'PCC vabc to Simulink',[300 185 415 225]);
setpos(step,'PCC iabc to Simulink',[300 245 415 285]);
setpos(step,'PCC Current Local Terminator',[455 255 475 275]);
setpos(step,'P to Simulink',[455 185 555 221]);
setpos(step,'Q to Simulink',[455 230 555 266]);
setpos(step,'PCC Voltage LL RMS',[590 180 720 220]);
setpos(step,'PCC MeasurementBus',[760 180 765 300]);
setpos(step,'PCC MeasurementBus Goto',[805 220 940 250]);

% Clean outer drawings.  No signal meaning or connection is changed.
set_param([pcs '/CommandBus'],'Position',[25 215 55 229]);
set_param([pcs '/01 Secondary Control'],'Position',[150 165 420 315]);
set_param([pcs '/02 Primary Converter and Filter'],'Position',[525 70 800 235]);
set_param([pcs '/AC_690V'],'Position',[900 130 930 144]);
set_param([pcs '/StatusBus'],'Position',[900 275 930 289]);
set_param([pv '/CommandBus'],'Position',[25 235 55 249]);
set_param([pv '/01 GFL PCS'],'Position',[170 145 470 340]);
set_param([pv '/02 Step-up and PCC'],'Position',[600 135 870 305]);
set_param([pv '/PCC_10kV'],'Position',[985 205 1015 235]);
set_param([pv '/StatusBus'],'Position',[985 335 1015 349]);
set_param([pv '/scope_R21_PrimaryMeasurementBus'],'Position',[30 50 180 70]);
set_param([pv '/scope_R21_PCCMeasurementBus'],'Position',[30 80 180 100]);
set_param([pv '/scope_R21_CurrentCommandBus'],'Position',[30 110 180 130]);

systems={model,pv,pcs,sec,pll,cg,st,pri,step};
for k=1:numel(systems)
    try,set_param(systems{k},'ZoomFactor','FitSystem');catch,end
end
set_param(model,'SimulationCommand','update');
try,set_param(model,'SampleTimeColors','off');catch,end
% createSubsystem can leave signal highlighting active in the editor.  It
% is only a display state, but it makes exported review drawings look like
% broken red routes, so clear it before saving/rendering.
try,hilite_system(model,'none');catch,end
save_system(model,dst);

pngNames={'R1_1_01_Top','R1_1_02_PV_Branch','R1_1_03_GFL_PCS', ...
    'R1_1_04_Secondary_Control','R1_1_05_Local_PLL', ...
    'R1_1_06_Current_Command','R1_1_07_Status_Assembly', ...
    'R1_1_08_Primary_Power','R1_1_09_Step_up_PCC'};
for k=1:numel(systems)
    try
        print(['-s' systems{k}],'-dpng',fullfile(root,'build',[pngNames{k} '.png']));
    catch ME
        warning('PNG export failed for %s: %s',systems{k},ME.message);
    end
end
fprintf('STAGE1_R1_1_READABLE_BUILD_OK=1\nSOURCE_SHA256=%s\nMODEL=%s\n',expected,dst);
close_system(model,0);

function p=paths(parent,names)
p=cellfun(@(n)[parent '/' n],names,'UniformOutput',false);
assert(all(cellfun(@(x)getSimulinkBlockHandle(x)>0,p)),'Expected block is missing.');
end

function sub=group_exact(parent,blocks,newName)
before=find_system(parent,'SearchDepth',1,'BlockType','SubSystem');
handles=cellfun(@getSimulinkBlockHandle,blocks);
Simulink.BlockDiagram.createSubsystem(handles);
after=find_system(parent,'SearchDepth',1,'BlockType','SubSystem');
fresh=setdiff(after,before,'stable');assert(numel(fresh)==1,'Grouping was not deterministic.');
set_param(fresh{1},'Name',newName);sub=[parent '/' newName];
end

function setpos(parent,name,pos)
p=[parent '/' name];if getSimulinkBlockHandle(p)>0,set_param(p,'Position',pos);end
end

function consolidate_current_status(sec,cg,st)
% createSubsystem exposed eight scalar telemetry lines and four historical
% dangling outputs.  Keep the same eight values/order, but cross module
% boundaries as one vector and use local tags to avoid a wire fan-out.
oph=get_param(cg,'PortHandles');sources=[];statusPorts=[];
for k=1:numel(oph.Outport)
    lh=get_param(oph.Outport(k),'Line');
    if lh<=0,continue,end
    dp=get_param(lh,'DstPortHandle');dp=dp(dp>0);
    if isempty(dp),continue,end
    dstParent=get_param(dp(1),'Parent');
    if ~strcmp(dstParent,st),continue,end
    outBlock=find_system(cg,'SearchDepth',1,'BlockType','Outport','Port',num2str(k));
    assert(numel(outBlock)==1,'Current-generation output mapping is ambiguous.');
    iph=get_param(outBlock{1},'PortHandles');ilh=get_param(iph.Inport,'Line');
    sources(end+1)=get_param(ilh,'SrcPortHandle'); %#ok<AGROW>
    statusPorts(end+1)=get_param(dp(1),'PortNumber'); %#ok<AGROW>
end
[statusPorts,ord]=sort(statusPorts);sources=sources(ord);
assert(isequal(statusPorts,7:14),'Unexpected current/status telemetry mapping.');

add_block('simulink/Signal Routing/Mux',[cg '/Status Telemetry Mux'], ...
    'Inputs',num2str(numel(sources)),'Position',[1280 45 1285 290]);
muxPH=get_param([cg '/Status Telemetry Mux'],'PortHandles');
for k=1:numel(sources)
    tag=sprintf('CCG_Telem_%02d',k);
    srcBlock=get_param(sources(k),'Parent');pos=get_param(srcBlock,'Position');
    gy=pos(2)+mod(k-1,3)*18;
    g=[cg '/' tag ' Goto'];f=[cg '/' tag ' From'];
    add_block('simulink/Signal Routing/Goto',g,'GotoTag',tag, ...
        'TagVisibility','local','Position',[pos(3)+12 gy pos(3)+102 gy+16]);
    add_block('simulink/Signal Routing/From',f,'GotoTag',tag, ...
        'Position',[1135 35+30*k 1235 55+30*k]);
    gph=get_param(g,'PortHandles');fph=get_param(f,'PortHandles');
    add_line(cg,sources(k),gph.Inport,'autorouting','on');
    add_line(cg,fph.Outport,muxPH.Inport(k),'autorouting','on');
end

oldOut=find_system(cg,'SearchDepth',1,'BlockType','Outport');
for k=1:numel(oldOut),delete_block(oldOut{k});end
add_block('simulink/Ports & Subsystems/Out1',[cg '/StatusTelemetryBus'], ...
    'Port','1','Position',[1350 160 1380 174]);
add_line(cg,'Status Telemetry Mux/1','StatusTelemetryBus/1');

destinations=zeros(1,8);
oldStatusInputs=cell(1,8);
for k=1:8
    ip=find_system(st,'SearchDepth',1,'BlockType','Inport','Port',num2str(k+6));
    assert(numel(ip)==1,'Status input mapping is ambiguous.');
    oldStatusInputs{k}=ip{1};
    ph=get_param(ip{1},'PortHandles');lh=get_param(ph.Outport,'Line');
    dp=get_param(lh,'DstPortHandle');dp=dp(dp>0);assert(numel(dp)==1);
    destinations(k)=dp;
    delete_line(lh);
end
for k=8:-1:1,delete_block(oldStatusInputs{k});end
add_block('simulink/Ports & Subsystems/In1',[st '/CurrentGen Status Bus'], ...
    'Port','7','Position',[25 260 55 274]);
add_block('simulink/Signal Routing/Demux',[st '/CurrentGen Status Selector'], ...
    'Outputs','8','Position',[110 225 115 345]);
add_line(st,'CurrentGen Status Bus/1','CurrentGen Status Selector/1');
dph=get_param([st '/CurrentGen Status Selector'],'PortHandles');
for k=1:8,add_line(st,dph.Outport(k),destinations(k),'autorouting','on');end

% Parent lines were removed with the historical ports; reconnect the one
% vector contract between the two functional modules.
cph=get_param(cg,'PortHandles');sph=get_param(st,'PortHandles');
add_line(sec,cph.Outport(1),sph.Inport(7),'autorouting','on');
end

function h=sha256(file)
[ok,out]=system(sprintf('/usr/bin/shasum -a 256 "%s"',file));assert(ok==0);
h=extractBefore(strtrim(out),' ');
end
