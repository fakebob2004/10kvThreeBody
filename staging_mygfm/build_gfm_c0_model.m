%BUILD_GFM_C0_MODEL Add a readable GFM controller to the frozen MYVSC B1 plant.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'Parameters'));
init_project; run(fullfile(root,'Parameters','gfm_parameters.m'));
assignin('base','GFM',GFM);

source='GFL_Inverter_B1'; model='GFM_Inverter_C0';
sourceFile=fullfile(root,[source '.slx']); modelFile=fullfile(root,[model '.slx']);
assert(isfile(sourceFile),'Missing B1 model.');
bdclose('all'); load_system(sourceFile); save_system(source,modelFile); close_system(source,0);
load_system(modelFile);
set_param(model,'StopTime','GFM.StopTime','SignalLogging','on','SignalLoggingName','logsout');

% Deliberate measurement interface: expose only Vdc and PCC abc voltage/current.
replaceTerminatorWithOutport([model '/Two-Level VSC'],'Vdc Internal Monitor','Vdc_Meas',1);
replaceTerminatorWithOutport([model '/Grid Interface (Filter XFMR PCC)'], ...
    'Vabc PCC Internal Monitor','Vabc_PCC_Meas',1);
replaceTerminatorWithOutport([model '/Grid Interface (Filter XFMR PCC)'], ...
    'Iabc PCC Internal Monitor','Iabc_PCC_Meas',2);

old=[model '/B1 Open-Loop Modulation and PWM'];
vsc=get_param([model '/Two-Level VSC'],'PortHandles');
gateLine=get_param(vsc.Inport(1),'Line');if gateLine>0,delete_line(gateLine);end
delete_block(old);
add_block('built-in/Subsystem',[model '/GFM Controller'], ...
    'Position',[210 40 570 205],'BackgroundColor','lightBlue', ...
    'FontWeight','bold','ContentPreviewEnabled','off');
buildGFMController([model '/GFM Controller']);

c=get_param([model '/GFM Controller'],'PortHandles');
vsc=get_param([model '/Two-Level VSC'],'PortHandles');
gi=get_param([model '/Grid Interface (Filter XFMR PCC)'],'PortHandles');
namedLine(add_line(model,c.Outport(1),vsc.Inport(1),'autorouting','on'),'GatePulses');
namedLine(add_line(model,vsc.Outport(1),c.Inport(1),'autorouting','on'),'Vdc_Meas');
namedLine(add_line(model,gi.Outport(1),c.Inport(2),'autorouting','on'),'Vabc_PCC_Meas');
namedLine(add_line(model,gi.Outport(2),c.Inport(3),'autorouting','on'),'Iabc_PCC_Meas');

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(model,[40 220 585 285],sprintf([ ...
    'C0 GRID-FORMING CONTROL\n' ...
    'No PLL: measured P/Q -> droop -> internal angle and voltage -> current/modulation limit -> PWM.']));
note(model,[600 420 1320 470], ...
    'Plant inherited unchanged from B1: detailed VSC | R-L filter + 0.4/10 kV transformer | SCR grid.');
set_param(model,'PreLoadFcn',sprintf("addpath('%s'); init_project; run(fullfile('%s','Parameters','gfm_parameters.m')); assignin('base','GFM',GFM);",strrep(root,"'","''"),strrep(root,"'","''")));
set_param(model,'InitFcn',"init_project; run(fullfile(fileparts(get_param(bdroot,'FileName')),'Parameters','gfm_parameters.m')); assignin('base','GFM',GFM);");
set_param(model,'Description','C0 readable grid-forming controller integrated into the frozen MYVSC B1 detailed switching plant.');
set_param(model,'Location',[30 70 1760 810],'ZoomFactor','FitSystem');
for n={'GatePulses','Vdc_Meas','Vabc_PCC_Meas','Iabc_PCC_Meas', ...
        'P_PCC_W','Q_PCC_var','theta_GFM_rad','frequency_GFM_Hz', ...
        'Vll_cmd_V','Ipeak_PCC_A','mabc_limited'}
    enableNamedSignalLogging(model,n{1});
end
disableSubsystemPreviews(model);
save_system(model,modelFile);set_param(model,'SimulationCommand','update');save_system(model,modelFile);
try,print(['-s' model],'-dpng',fullfile(root,[model '.png']));catch,end
try,print(['-s' model '/GFM Controller'],'-dpng',fullfile(root,'GFM_Controller_C0.png'));catch,end
close_system(model,0);fprintf('Created: %s\n',modelFile);

function buildGFMController(sys)
inport(sys,'Vdc',1,[20 70 50 90]);inport(sys,'Vabc PCC',2,[20 145 50 165]);
inport(sys,'Iabc PCC',3,[20 220 50 240]);outport(sys,'GatePulses',1,[965 145 995 165]);
subsys(sys,'01 Measurements and Power',[100 105 285 265],[0.88 0.94 1.00]);
buildMeasurements([sys '/01 Measurements and Power']);
subsys(sys,'02 P-f Droop and Angle',[345 55 525 165],[0.84 0.96 0.84]);
buildPF([sys '/02 P-f Droop and Angle']);
subsys(sys,'03 Q-V Droop and Magnitude',[345 215 525 325],[0.94 0.90 1.00]);
buildQV([sys '/03 Q-V Droop and Magnitude']);
subsys(sys,'04 Voltage Reference and Limits',[590 90 790 290],[1.00 0.91 0.72]);
buildVoltageReference([sys '/04 Voltage Reference and Limits']);
subsys(sys,'05 Carrier PWM',[835 105 925 245],[1.00 0.84 0.68]);
buildPWM([sys '/05 Carrier PWM']);

wire(sys,'Vabc PCC/1','01 Measurements and Power/1','Vabc_PCC');
wire(sys,'Iabc PCC/1','01 Measurements and Power/2','Iabc_PCC');
wire(sys,'01 Measurements and Power/1','02 P-f Droop and Angle/1','P_PCC_W');
wire(sys,'01 Measurements and Power/2','03 Q-V Droop and Magnitude/1','Q_PCC_var');
wire(sys,'02 P-f Droop and Angle/1','04 Voltage Reference and Limits/1','theta_GFM_rad');
wire(sys,'03 Q-V Droop and Magnitude/1','04 Voltage Reference and Limits/2','Vll_cmd_V');
wire(sys,'Vdc/1','04 Voltage Reference and Limits/3','Vdc_V');
wire(sys,'01 Measurements and Power/3','04 Voltage Reference and Limits/4','Ipeak_PCC_A');
wire(sys,'04 Voltage Reference and Limits/1','05 Carrier PWM/1','mabc_limited');
wire(sys,'05 Carrier PWM/1','GatePulses/1','GatePulses');
note(sys,[70 350 930 405], ...
    'Readable signal order: measurement -> P-f / Q-V -> voltage reference -> feasibility limits -> switching PWM.');
end

function buildMeasurements(sys)
inport(sys,'Vabc',1,[20 90 50 110]);inport(sys,'Iabc',2,[20 230 50 250]);
outport(sys,'P_W',1,[650 80 680 100]);outport(sys,'Q_var',2,[650 160 680 180]);
outport(sys,'Ipeak_A',3,[650 250 680 270]);
K='sqrt(2/3)*[1 -0.5 -0.5; 0 sqrt(3)/2 -sqrt(3)/2]''';
add_block('simulink/Math Operations/Gain',[sys '/Clarke Voltage'], ...
    'Position',[90 65 190 125],'Gain',K,'Multiplication','Matrix(u*K)');
add_block('simulink/Math Operations/Gain',[sys '/Clarke Current'], ...
    'Position',[90 205 190 265],'Gain',K,'Multiplication','Matrix(u*K)');
add_block('simulink/Signal Routing/Demux',[sys '/V alpha beta'], ...
    'Position',[235 60 240 130],'Outputs','2');
add_block('simulink/Signal Routing/Demux',[sys '/I alpha beta'], ...
    'Position',[235 200 240 270],'Outputs','2');
add_block('simulink/Math Operations/Product',[sys '/vAlpha iAlpha'], ...
    'Position',[300 55 350 90],'Inputs','2');
add_block('simulink/Math Operations/Product',[sys '/vBeta iBeta'], ...
    'Position',[300 105 350 140],'Inputs','2');
add_block('simulink/Math Operations/Sum',[sys '/Instantaneous P'], ...
    'Position',[395 72 430 123],'Inputs','++');
add_block('simulink/Math Operations/Product',[sys '/vBeta iAlpha'], ...
    'Position',[300 160 350 195],'Inputs','2');
add_block('simulink/Math Operations/Product',[sys '/vAlpha iBeta'], ...
    'Position',[300 210 350 245],'Inputs','2');
add_block('simulink/Math Operations/Sum',[sys '/Instantaneous Q'], ...
    'Position',[395 177 430 228],'Inputs','+-');
wc='2*pi*GFM.power_lpf_Hz';
add_block('simulink/Continuous/Transfer Fcn',[sys '/P Low-Pass'], ...
    'Position',[475 75 565 105],'Numerator',['[' wc ']'],'Denominator',['[1 ' wc ']']);
add_block('simulink/Continuous/Transfer Fcn',[sys '/Q Low-Pass'], ...
    'Position',[475 180 565 210],'Numerator',['[' wc ']'],'Denominator',['[1 ' wc ']']);
add_block('simulink/Math Operations/Abs',[sys '/Abs Current'], ...
    'Position',[300 285 350 315]);
add_block('simulink/Math Operations/MinMax',[sys '/Peak Phase Current'], ...
    'Position',[400 280 455 320],'Function','max','Inputs','1');
wire(sys,'Vabc/1','Clarke Voltage/1','');wire(sys,'Iabc/1','Clarke Current/1','');
wire(sys,'Clarke Voltage/1','V alpha beta/1','');wire(sys,'Clarke Current/1','I alpha beta/1','');
wire(sys,'V alpha beta/1','vAlpha iAlpha/1','');wire(sys,'I alpha beta/1','vAlpha iAlpha/2','');
wire(sys,'V alpha beta/2','vBeta iBeta/1','');wire(sys,'I alpha beta/2','vBeta iBeta/2','');
wire(sys,'vAlpha iAlpha/1','Instantaneous P/1','');wire(sys,'vBeta iBeta/1','Instantaneous P/2','');
wire(sys,'V alpha beta/2','vBeta iAlpha/1','');wire(sys,'I alpha beta/1','vBeta iAlpha/2','');
wire(sys,'V alpha beta/1','vAlpha iBeta/1','');wire(sys,'I alpha beta/2','vAlpha iBeta/2','');
wire(sys,'vBeta iAlpha/1','Instantaneous Q/1','');wire(sys,'vAlpha iBeta/1','Instantaneous Q/2','');
wire(sys,'Instantaneous P/1','P Low-Pass/1','');wire(sys,'P Low-Pass/1','P_W/1','P_PCC_W');
wire(sys,'Instantaneous Q/1','Q Low-Pass/1','');wire(sys,'Q Low-Pass/1','Q_var/1','Q_PCC_var');
wire(sys,'Iabc/1','Abs Current/1','');wire(sys,'Abs Current/1','Peak Phase Current/1','');
wire(sys,'Peak Phase Current/1','Ipeak_A/1','Ipeak_PCC_A');
end

function buildPF(sys)
inport(sys,'P_W',1,[20 120 50 140]);outport(sys,'theta_rad',1,[530 100 560 120]);
outport(sys,'frequency_Hz',2,[530 180 560 200]);
constant(sys,'P Reference','GFM.Pref_W',[80 45 175 75]);
add_block('simulink/Math Operations/Sum',[sys '/P Error'], ...
    'Position',[205 85 240 135],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[sys '/P-f Droop'], ...
    'Position',[275 90 365 130],'Gain','GFM.mp_rad_s_per_W');
constant(sys,'Rated Omega','GFM.omega0_rad_s',[275 25 365 55]);
add_block('simulink/Math Operations/Sum',[sys '/Omega Command'], ...
    'Position',[395 55 430 105],'Inputs','++');
add_block('simulink/Discontinuities/Saturation',[sys '/Omega Limits'], ...
    'Position',[455 55 495 105],'LowerLimit','GFM.omega_min_rad_s','UpperLimit','GFM.omega_max_rad_s');
add_block('simulink/Continuous/Integrator',[sys '/Angle Integrator'], ...
    'Position',[455 120 495 160],'InitialCondition','GFM.theta0_rad');
add_block('simulink/Math Operations/Gain',[sys '/rad s to Hz'], ...
    'Position',[455 180 495 215],'Gain','1/(2*pi)');
wire(sys,'P Reference/1','P Error/1','');wire(sys,'P_W/1','P Error/2','');
wire(sys,'P Error/1','P-f Droop/1','');wire(sys,'Rated Omega/1','Omega Command/1','');
wire(sys,'P-f Droop/1','Omega Command/2','');wire(sys,'Omega Command/1','Omega Limits/1','omega_cmd');
wire(sys,'Omega Limits/1','Angle Integrator/1','');wire(sys,'Angle Integrator/1','theta_rad/1','theta_GFM_rad');
wire(sys,'Omega Limits/1','rad s to Hz/1','');wire(sys,'rad s to Hz/1','frequency_Hz/1','frequency_GFM_Hz');
end

function buildQV(sys)
inport(sys,'Q_var',1,[20 115 50 135]);outport(sys,'Vll_cmd_V',1,[480 115 510 135]);
constant(sys,'Q Reference','GFM.Qref_var',[80 45 170 75]);
add_block('simulink/Math Operations/Sum',[sys '/Q Error'], ...
    'Position',[190 85 225 135],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[sys '/Q-V Droop'], ...
    'Position',[260 90 340 130],'Gain','GFM.nq_V_per_var');
constant(sys,'Rated Voltage','GFM.Vll_ref_V',[260 30 340 60]);
add_block('simulink/Math Operations/Sum',[sys '/Voltage Command'], ...
    'Position',[370 65 405 115],'Inputs','++');
add_block('simulink/Discontinuities/Saturation',[sys '/Voltage Limits'], ...
    'Position',[425 80 460 120],'LowerLimit','GFM.Vll_min_V','UpperLimit','GFM.Vll_max_V');
wire(sys,'Q Reference/1','Q Error/1','');wire(sys,'Q_var/1','Q Error/2','');
wire(sys,'Q Error/1','Q-V Droop/1','');wire(sys,'Rated Voltage/1','Voltage Command/1','');
wire(sys,'Q-V Droop/1','Voltage Command/2','');wire(sys,'Voltage Command/1','Voltage Limits/1','');
wire(sys,'Voltage Limits/1','Vll_cmd_V/1','Vll_cmd_V');
end

function buildVoltageReference(sys)
inport(sys,'theta_rad',1,[20 55 50 75]);inport(sys,'Vll_cmd_V',2,[20 130 50 150]);
inport(sys,'Vdc_V',3,[20 205 50 225]);inport(sys,'Ipeak_A',4,[20 280 50 300]);
outport(sys,'mabc_limited',1,[790 145 820 165]);
add_block('simulink/Discrete/Unit Delay',[sys '/Sample Vdc'], ...
    'Position',[70 195 145 230],'SampleTime','Control.PWM.Ts', ...
    'InitialCondition','Converter.Vdc_nom');
add_block('simulink/Discrete/Unit Delay',[sys '/Sample Ipeak'], ...
    'Position',[70 270 145 305],'SampleTime','Control.PWM.Ts', ...
    'InitialCondition','0');
wire(sys,'Vdc_V/1','Sample Vdc/1','Vdc_sampled');
wire(sys,'Ipeak_A/1','Sample Ipeak/1','Ipeak_sampled');
for k=1:3
    y=30+80*(k-1);name=sprintf('Phase %c Angle','A'+k-1);
    add_block('simulink/Math Operations/Bias',[sys '/' name], ...
        'Position',[100 y 180 y+35],'Bias',sprintf('GFM.phaseABC(%d)',k));
    add_block('simulink/Math Operations/Trigonometric Function',[sys '/sin ' char('A'+k-1)], ...
        'Position',[220 y 270 y+35],'Operator','sin');
    wire(sys,'theta_rad/1',[name '/1'],'');wire(sys,[name '/1'],['sin ' char('A'+k-1) '/1'],'');
end
add_block('simulink/Signal Routing/Mux',[sys '/Unit abc'], ...
    'Position',[315 45 320 235],'Inputs','3');
for k=1:3,wire(sys,['sin ' char('A'+k-1) '/1'],sprintf('Unit abc/%d',k),'');end
add_block('simulink/Math Operations/Gain',[sys '/Vll to Modulation Numerator'], ...
    'Position',[105 120 245 155],'Gain','2*sqrt(2)/sqrt(3)');
add_block('simulink/Math Operations/Divide',[sys '/Normalize by Vdc'], ...
    'Position',[300 120 350 170]);
wire(sys,'Vll_cmd_V/1','Vll to Modulation Numerator/1','');
wire(sys,'Vll to Modulation Numerator/1','Normalize by Vdc/1','');wire(sys,'Sample Vdc/1','Normalize by Vdc/2','');
add_block('simulink/Math Operations/MinMax',[sys '/Safe Ipeak'], ...
    'Position',[105 270 165 310],'Function','max','Inputs','2');
constant(sys,'Current Epsilon','GFM.current_epsilon_A',[70 330 165 360]);
wire(sys,'Sample Ipeak/1','Safe Ipeak/1','');wire(sys,'Current Epsilon/1','Safe Ipeak/2','');
constant(sys,'Peak Current Limit','GFM.Ipeak_limit_A',[215 300 320 330]);
add_block('simulink/Math Operations/Divide',[sys '/Current Headroom'], ...
    'Position',[360 275 410 325]);
wire(sys,'Peak Current Limit/1','Current Headroom/1','');wire(sys,'Safe Ipeak/1','Current Headroom/2','');
add_block('simulink/Discontinuities/Saturation',[sys '/Limit Factor 0 to 1'], ...
    'Position',[450 280 500 320],'LowerLimit','0','UpperLimit','1');
wire(sys,'Current Headroom/1','Limit Factor 0 to 1/1','');
add_block('simulink/Math Operations/Product',[sys '/Amplitude times Unit abc'], ...
    'Position',[410 100 470 150],'Inputs','2','Multiplication','Element-wise(.*)');
wire(sys,'Normalize by Vdc/1','Amplitude times Unit abc/1','');wire(sys,'Unit abc/1','Amplitude times Unit abc/2','');
add_block('simulink/Math Operations/Product',[sys '/Apply Current Limit'], ...
    'Position',[545 120 605 170],'Inputs','2','Multiplication','Element-wise(.*)');
wire(sys,'Amplitude times Unit abc/1','Apply Current Limit/1','');wire(sys,'Limit Factor 0 to 1/1','Apply Current Limit/2','');
add_block('simulink/Discontinuities/Saturation',[sys '/Modulation Limits'], ...
    'Position',[655 120 720 170],'LowerLimit','-GFM.modulation_max_pu','UpperLimit','GFM.modulation_max_pu');
wire(sys,'Apply Current Limit/1','Modulation Limits/1','');wire(sys,'Modulation Limits/1','mabc_limited/1','mabc_limited');
end

function buildPWM(sys)
inport(sys,'mabc',1,[20 105 50 125]);outport(sys,'GatePulses',1,[525 155 555 175]);
add_block('simulink/Sources/Repeating Sequence',[sys '/Triangular Carrier'], ...
    'Position',[40 260 180 305],'rep_seq_t','[0 Control.PWM.CarrierPeriod/2 Control.PWM.CarrierPeriod]', ...
    'rep_seq_y','[-1 1 -1]');
add_block('simulink/Signal Routing/Demux',[sys '/abc References'], ...
    'Position',[100 70 105 220],'Outputs','3');wire(sys,'mabc/1','abc References/1','');
add_block('simulink/Signal Routing/Mux',[sys '/Six Gates'], ...
    'Position',[440 70 445 285],'Inputs','6');
for k=1:3
    y=55+80*(k-1);ph=char('A'+k-1);
    add_block('simulink/Logic and Bit Operations/Relational Operator',[sys '/Compare ' ph], ...
        'Position',[170 y 220 y+30],'Operator','>=');
    add_block('simulink/Logic and Bit Operations/Logical Operator',[sys '/NOT ' ph], ...
        'Position',[250 y+30 290 y+60],'Operator','NOT','Inputs','1');
    add_block('simulink/Signal Attributes/Data Type Conversion',[sys '/High ' ph], ...
        'Position',[320 y-5 385 y+20],'OutDataTypeStr','double');
    add_block('simulink/Signal Attributes/Data Type Conversion',[sys '/Low ' ph], ...
        'Position',[320 y+35 385 y+60],'OutDataTypeStr','double');
    wire(sys,sprintf('abc References/%d',k),['Compare ' ph '/1'],'');wire(sys,'Triangular Carrier/1',['Compare ' ph '/2'],'');
    wire(sys,['Compare ' ph '/1'],['High ' ph '/1'],'');wire(sys,['Compare ' ph '/1'],['NOT ' ph '/1'],'');
    wire(sys,['NOT ' ph '/1'],['Low ' ph '/1'],'');wire(sys,['High ' ph '/1'],sprintf('Six Gates/%d',2*k-1),'');
    wire(sys,['Low ' ph '/1'],sprintf('Six Gates/%d',2*k),'');
end
wire(sys,'Six Gates/1','GatePulses/1','GatePulses');
end

function replaceTerminatorWithOutport(sys,termName,outName,port)
t=[sys '/' termName];existing=[sys '/' outName];
if getSimulinkBlockHandle(existing)>0,return;end
assert(getSimulinkBlockHandle(t)>0,'Neither open measurement port nor %s exists.',t);
p=get_param(t,'PortHandles');line=get_param(p.Inport,'Line');
src=get_param(line,'SrcPortHandle');pos=get_param(t,'Position');delete_block(t);
pos=[pos(1) pos(2) pos(1)+30 pos(2)+20];outport(sys,outName,port,pos);
op=get_param([sys '/' outName],'PortHandles');
if get_param(op.Inport,'Line')<0,add_line(sys,src,op.Inport,'autorouting','on');end
end
function subsys(p,n,pos,c),add_block('built-in/Subsystem',[p '/' n],'Position',pos,'BackgroundColor',rgb(c),'FontWeight','bold','ContentPreviewEnabled','off');end
function inport(s,n,p,pos),add_block('simulink/Ports & Subsystems/In1',[s '/' n],'Port',num2str(p),'Position',pos);end
function outport(s,n,p,pos),add_block('simulink/Ports & Subsystems/Out1',[s '/' n],'Port',num2str(p),'Position',pos);end
function constant(s,n,v,pos),add_block('simulink/Sources/Constant',[s '/' n],'Value',v,'Position',pos);end
function wire(s,a,b,n),h=add_line(s,a,b,'autorouting','on');if ~isempty(n),set_param(h,'Name',n);end;end
function namedLine(h,n)
set_param(h,'Name',n);src=get_param(h,'SrcPortHandle');
set_param(src,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',n);
end
function enableNamedSignalLogging(model,name)
lines=find_system(model,'FindAll','on','Type','line');
for k=1:numel(lines)
    if strcmp(get_param(lines(k),'Name'),name)
        src=get_param(lines(k),'SrcPortHandle');
        set_param(src,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',name);
        return
    end
end
error('Named signal not found: %s',name);
end
function disableSubsystemPreviews(model)
b=find_system(model,'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem');
for k=1:numel(b),try,set_param(b{k},'ContentPreviewEnabled','off');catch,end;end
end
function note(s,pos,t),a=Simulink.Annotation(s,t);a.Position=pos;a.FontSize=10;end
function s=rgb(c),s=sprintf('[%.3f,%.3f,%.3f]',c(1),c(2),c(3));end
