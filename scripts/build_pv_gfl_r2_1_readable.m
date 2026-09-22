% Derive R2.1 from the accepted R2 artifact without modifying R2.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
source=fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2.slx');
model='PV_GFL_864_SystemLevel_SM_R2_1_Readable';
modelFile=fullfile(root,'build',[model '.slx']);pngFile=fullfile(root,'build',[model '.png']);
assert(isfile(source),'Accepted R2 source model is missing.');
copyfile(source,modelFile,'f');load_system(modelFile);
run(fullfile(scriptDir,'init_pv_gfl_r2_1.m'));
load_system('ee_lib');load_system('nesl_utility');
pv=[model '/01 PV-GFL System-Level Branch'];
cmd=[model '/02 Commissioning Command Profile'];

% The copied reference synchronous-machine field circuit retained its
% original 60 Hz base while the machine, transformer and project use 50 Hz.
% Keep every electromechanical/field element on the same per-unit base.
fieldCircuit=[model '/Strong Synchronous Machine (Governor + AVR)/AVR and Exciter/' ...
    sprintf('Synchronous Machine\nField Circuit (pu)')];
assert(getSimulinkBlockHandle(fieldCircuit)>0,'Synchronous-machine field circuit is missing.');
set_param(fieldCircuit,'FRated','Grid.frequency');
% The reference AC1C tuning (K_A=600, T_A=0.01 s) drove the resized
% 10 kV/50 Hz commissioning machine into field-voltage limiting and a
% sustained terminal-voltage oscillation.  The reduced regulator bandwidth
% was verified for 3 s at 5 MW, Q=0 before being made part of R2.1.
avr=[model '/Strong Synchronous Machine (Governor + AVR)/AVR and Exciter/SM AC1C'];
set_param(avr,'K_A','50','T_A','0.05');

% 1) PCC-local measurement and PLL source.  PLL sees only this PV branch's
% own 10 kV terminal; converter-side voltage remains local magnitude input.
iv3=sprintf('ee_lib/Sensors &\nTransducers/Current and Voltage\nSensor (Three-Phase)');
pss=sprintf('nesl_utility/PS-Simulink\nConverter');
add_block(iv3,[pv '/PCC 10kV VI Sensor'],'Position',[875 135 950 225]);
add_block(pss,[pv '/PCC vabc to Simulink'],'Position',[875 260 990 300],'Unit','V');
add_block(pss,[pv '/PCC iabc to Simulink'],'Position',[875 305 990 345],'Unit','A');
add_block('simulink/Sinks/Terminator',[pv '/PCC Current Local Terminator'], ...
    'Position',[1020 315 1040 335]);
xfPH=get_param([pv '/T_PV_0p69_10kV'],'PortHandles');
pqPH=get_param([pv '/PV PCC Power Sensor'],'PortHandles');
oldLine=get_param(xfPH.RConn(1),'Line');if oldLine>0,delete_line(oldLine);end
pccPH=get_param([pv '/PCC 10kV VI Sensor'],'PortHandles');
add_line(pv,xfPH.RConn(1),pccPH.LConn(1),'autorouting','on');
add_line(pv,pccPH.RConn(3),pqPH.LConn(1),'autorouting','on');
vpsPH=get_param([pv '/PCC vabc to Simulink'],'PortHandles');
add_line(pv,pccPH.RConn(1),vpsPH.LConn(1),'autorouting','on');
ipsPH=get_param([pv '/PCC iabc to Simulink'],'PortHandles');
add_line(pv,pccPH.RConn(2),ipsPH.LConn(1),'autorouting','on');
add_line(pv,'PCC iabc to Simulink/1','PCC Current Local Terminator/1');
pllPH=get_param([pv '/02 Local SRF-PLL'],'PortHandles');
pllLine=get_param(pllPH.Inport(1),'Line');if pllLine>0,delete_line(pllLine);end
add_line(pv,'PCC vabc to Simulink/1','02 Local SRF-PLL/1','autorouting','on');

% 2) Functional enable schedule in the external commissioning profile.
oldEnable=[cmd '/Enable'];if getSimulinkBlockHandle(oldEnable)>0,delete_block(oldEnable);end
cmdBusPH=get_param([cmd '/CommandBus'],'PortHandles');
oldEnableLine=get_param(cmdBusPH.Inport(3),'Line');if oldEnableLine>0,delete_line(oldEnableLine);end
add_block('simulink/Sources/Constant',[cmd '/Enable Base'],'Position',[205 220 270 250],'Value','1');
add_block('simulink/Sources/Step',[cmd '/Enable Off'],'Position',[205 265 270 295], ...
    'Time','S21.command.enable_off_time_s','Before','0','After','-S21.command.enable_drop');
add_block('simulink/Sources/Step',[cmd '/Enable On'],'Position',[205 310 270 340], ...
    'Time','S21.command.enable_on_time_s','Before','0','After','S21.command.enable_drop');
add_block('simulink/Math Operations/Sum',[cmd '/Enable'],'Position',[300 245 330 325],'Inputs','+++');
add_line(cmd,'Enable Base/1','Enable/1');add_line(cmd,'Enable Off/1','Enable/2');
add_line(cmd,'Enable On/1','Enable/3');add_line(cmd,'Enable/1','CommandBus/3');

% 3) Replace independent axis clipping by one enable gate and circular dq
% limiter.  P/Q signs and current tracking remain identical to accepted R2.
for n={'Id Limit','Iq Limit'}
    p=[pv '/' n{1}];if getSimulinkBlockHandle(p)>0,delete_block(p);end
end
for n={'Id Tracking','Iq Tracking'}
    p=get_param([pv '/' n{1}],'PortHandles');ln=get_param(p.Inport(1),'Line');
    if ln>0,delete_line(ln);end
end
add_block('simulink/Signal Routing/Mux',[pv '/Raw dq Command'],'Position',[445 440 450 550],'Inputs','2');
add_block('simulink/Discontinuities/Saturation',[pv '/Enable Clamp'],'Position',[130 575 210 605], ...
    'UpperLimit','1','LowerLimit','0');
add_block('simulink/Math Operations/Product',[pv '/Enable Gate'],'Position',[485 455 525 535],'Inputs','**');
add_block('simulink/Signal Routing/Demux',[pv '/Gated dq Command'],'Position',[555 450 560 540],'Outputs','2');
add_block('simulink/Signal Routing/Mux',[pv '/dq Magnitude Input'],'Position',[590 405 595 470],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[pv '/dq Command Magnitude'],'Position',[625 415 735 450], ...
    'Expr','sqrt(u(1)^2+u(2)^2)');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Raw Limit Ratio'],'Position',[760 415 880 450], ...
    'Expr','S21.control.Ilimit_peak_A/sqrt(u^2+1e-12)');
add_block('simulink/Discontinuities/Saturation',[pv '/Current Circle Factor'],'Position',[905 410 985 455], ...
    'UpperLimit','1','LowerLimit','0');
add_block('simulink/Math Operations/Product',[pv '/Id Limit'],'Position',[610 485 660 520],'Inputs','**');
add_block('simulink/Math Operations/Product',[pv '/Iq Limit'],'Position',[610 535 660 570],'Inputs','**');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Current Limit Active'],'Position',[1010 415 1115 450], ...
    'Expr','u<0.999999');
add_line(pv,'P to Id/1','Raw dq Command/1');add_line(pv,'Q to Iq/1','Raw dq Command/2');
add_line(pv,'CommandBus Selector/3','Enable Clamp/1');
add_line(pv,'Raw dq Command/1','Enable Gate/1');add_line(pv,'Enable Clamp/1','Enable Gate/2');
add_line(pv,'Enable Gate/1','Gated dq Command/1');
add_line(pv,'Gated dq Command/1','dq Magnitude Input/1');
add_line(pv,'Gated dq Command/2','dq Magnitude Input/2');
add_line(pv,'dq Magnitude Input/1','dq Command Magnitude/1');
add_line(pv,'dq Command Magnitude/1','Raw Limit Ratio/1');
add_line(pv,'Raw Limit Ratio/1','Current Circle Factor/1');
add_line(pv,'Gated dq Command/1','Id Limit/1');add_line(pv,'Current Circle Factor/1','Id Limit/2');
add_line(pv,'Gated dq Command/2','Iq Limit/1');add_line(pv,'Current Circle Factor/1','Iq Limit/2');
add_line(pv,'Id Limit/1','Id Tracking/1');add_line(pv,'Iq Limit/1','Iq Tracking/1');
add_line(pv,'Current Circle Factor/1','Current Limit Active/1');

% 4) Actual current, PCC voltage, limiter state, and enable telemetry.
add_block('simulink/User-Defined Functions/Fcn',[pv '/Actual Current Magnitude'],'Position',[610 330 760 365], ...
    'Expr','sqrt((2/3)*(u(1)^2+u(2)^2+u(3)^2))');
add_line(pv,'iabc to Simulink/1','Actual Current Magnitude/1','autorouting','on');
add_block('simulink/User-Defined Functions/Fcn',[pv '/PCC Voltage LL RMS'],'Position',[1010 260 1140 300], ...
    'Expr','sqrt((u(1)^2+u(2)^2+u(3)^2)/3)');
add_line(pv,'PCC vabc to Simulink/1','PCC Voltage LL RMS/1');
set_param([pv '/StatusBus Elements'],'Inputs','16');
extra={'Actual Current Magnitude/1','Current Circle Factor/1','Current Limit Active/1', ...
    'PCC Voltage LL RMS/1','Enable Clamp/1'};
for k=1:numel(extra),add_line(pv,extra{k},sprintf('StatusBus Elements/%d',11+k),'autorouting','on');end
set_param([pv '/Current Limit Status'],'Value','S21.control.Ilimit_peak_A');

% 5) Human-readable hierarchy without multiplying boundary ports.  Three
% scoped, PV-local named routes carry the two measurement buses and the
% current-command bus; no tag crosses the PV branch boundary.
package_readable_hierarchy(pv);

% R2.1 identity, init, and readable top-level contract.
set_param(pv,'Name','01 PV-GFL Branch R2.1');pv=[model '/01 PV-GFL Branch R2.1'];
set_param(model,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_pv_gfl_r2_1.m'));" );
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'PV-GFL R2.1 standalone commissioning — minimal external interface\n' ...
    'CommandBus [P*,Q*,enable] | PCC_10kV physical port | StatusBus telemetry\n' ...
    'PLL uses this PV branch''s own 10 kV PCC voltage. Circular dq current limit is explicit.\n' ...
    'enable means converter enable, not PCC breaker trip: passive filter Q remains connected when enable=0.']));
a.Position=[55 25 1360 115];a.FontSize=14;a.FontWeight='bold';
set_param(model,'StopTime','0.9','MaxStep','1e-5','Location',[50 50 1500 900]);
save_system(model,modelFile);set_param(model,'SimulationCommand','update');save_system(model,modelFile);
try,print(['-s' model],'-dpng',pngFile);catch ME,fprintf('PNG_WARNING=%s\n',ME.message);end
close_system(model,0);fprintf('PV_GFL_R2_1_BUILD_OK=1\nMODEL=%s\n',modelFile);

function package_readable_hierarchy(pv)
% Scoped route declarations at the PV-branch owner level.
tags={'R21_PrimaryMeasurementBus','R21_PCCMeasurementBus','R21_CurrentCommandBus'};
for k=1:numel(tags)
    add_block('simulink/Signal Routing/Goto Tag Visibility',[pv '/scope_' tags{k}], ...
        'GotoTag',tags{k},'Position',[20 30+35*k 150 50+35*k]);
end

% Primary measurement bus = [vll_abc, iabc, |i|peak, |vll|peak].
add_block('simulink/Signal Routing/Mux',[pv '/Primary MeasurementBus'], ...
    'Position',[790 300 795 390],'Inputs','4');
add_block('simulink/Signal Routing/Goto',[pv '/Primary MeasurementBus Goto'], ...
    'Position',[820 330 955 360],'GotoTag',tags{1},'TagVisibility','scoped');
clear_output_line([pv '/vabc to Simulink']);
clear_output_line([pv '/iabc to Simulink']);
clear_output_line([pv '/Actual Current Magnitude']);
clear_output_line([pv '/Line Voltage Peak Magnitude']);
add_line(pv,'vabc to Simulink/1','Local Voltage Record/1','autorouting','on');
add_line(pv,'vabc to Simulink/1','Line Voltage Peak Magnitude/1','autorouting','on');
add_line(pv,'iabc to Simulink/1','Actual Current Magnitude/1','autorouting','on');
add_line(pv,'vabc to Simulink/1','Primary MeasurementBus/1','autorouting','on');
add_line(pv,'iabc to Simulink/1','Primary MeasurementBus/2','autorouting','on');
add_line(pv,'Actual Current Magnitude/1','Primary MeasurementBus/3','autorouting','on');
add_line(pv,'Line Voltage Peak Magnitude/1','Primary MeasurementBus/4','autorouting','on');
add_line(pv,'Primary MeasurementBus/1','Primary MeasurementBus Goto/1');
add_block('simulink/Signal Routing/From',[pv '/Primary MeasurementBus From'], ...
    'Position',[200 350 335 380],'GotoTag',tags{1});
add_block('simulink/Signal Routing/Demux',[pv '/Primary Measurement Selector'], ...
    'Position',[365 325 370 415],'Outputs','[3 3 1 1]');
add_line(pv,'Primary MeasurementBus From/1','Primary Measurement Selector/1');
add_line(pv,'Primary Measurement Selector/4','P and Voltage/2','autorouting','on');
add_line(pv,'Primary Measurement Selector/4','Q and Voltage/2','autorouting','on');

% CurrentCommandBus is the single abc vector crossing control -> plant.
clear_output_line([pv '/iabc Command']);
add_block('simulink/Signal Routing/Goto',[pv '/CurrentCommandBus Goto'], ...
    'Position',[1015 520 1145 550],'GotoTag',tags{3},'TagVisibility','scoped');
add_line(pv,'iabc Command/1','CurrentCommandBus Goto/1');
add_block('simulink/Signal Routing/From',[pv '/CurrentCommandBus From'], ...
    'Position',[175 180 305 210],'GotoTag',tags{3});
add_line(pv,'CurrentCommandBus From/1','Current Command to PS/1','autorouting','on');

% PCC measurement bus = [vll_abc_10kV, P, Q, Vll_rms].
add_block('simulink/Signal Routing/Mux',[pv '/PCC MeasurementBus'], ...
    'Position',[1135 195 1140 315],'Inputs','4');
add_block('simulink/Signal Routing/Goto',[pv '/PCC MeasurementBus Goto'], ...
    'Position',[1165 235 1285 265],'GotoTag',tags{2},'TagVisibility','scoped');
clear_output_line([pv '/PCC vabc to Simulink']);
clear_output_line([pv '/P to Simulink']);clear_output_line([pv '/Q to Simulink']);
clear_output_line([pv '/PCC Voltage LL RMS']);
add_line(pv,'PCC vabc to Simulink/1','PCC Voltage LL RMS/1','autorouting','on');
add_line(pv,'PCC vabc to Simulink/1','PCC MeasurementBus/1','autorouting','on');
add_line(pv,'P to Simulink/1','PCC MeasurementBus/2','autorouting','on');
add_line(pv,'Q to Simulink/1','PCC MeasurementBus/3','autorouting','on');
add_line(pv,'PCC Voltage LL RMS/1','PCC MeasurementBus/4','autorouting','on');
add_line(pv,'PCC MeasurementBus/1','PCC MeasurementBus Goto/1');
add_block('simulink/Signal Routing/From',[pv '/PCC MeasurementBus From'], ...
    'Position',[200 245 335 275],'GotoTag',tags{2});
add_block('simulink/Signal Routing/Demux',[pv '/PCC Measurement Selector'], ...
    'Position',[365 225 370 315],'Outputs','[3 1 1 1]');
add_line(pv,'PCC MeasurementBus From/1','PCC Measurement Selector/1');
add_line(pv,'PCC Measurement Selector/1','02 Local SRF-PLL/1','autorouting','on');
add_line(pv,'PCC Measurement Selector/2','StatusBus Elements/2','autorouting','on');
add_line(pv,'PCC Measurement Selector/3','StatusBus Elements/3','autorouting','on');
add_line(pv,'Primary Measurement Selector/3','StatusBus Elements/12','autorouting','on');
add_line(pv,'PCC Measurement Selector/4','StatusBus Elements/15','autorouting','on');

% Capture handles before moving blocks.  Named routes keep subsystem
% boundaries small after grouping.
primaryNames={'Average GFL Current Injection','Converter Neutral','Converter-Side VI Sensor', ...
    'Interface RL','Damped Shunt C','Filter Ground','vabc to Simulink','iabc to Simulink', ...
    'Actual Current Magnitude','Line Voltage Peak Magnitude','Local Voltage Record', ...
    'Current Command to PS','CurrentCommandBus From','Primary MeasurementBus', ...
    'Primary MeasurementBus Goto'};
stepNames={'T_PV_0p69_10kV','PCC 10kV VI Sensor','PV PCC Power Sensor', ...
    'PCC vabc to Simulink','PCC iabc to Simulink','PCC Current Local Terminator', ...
    'P to Simulink','Q to Simulink','PCC Voltage LL RMS', ...
    'PCC MeasurementBus','PCC MeasurementBus Goto'};
scopeNames=cellfun(@(x)['scope_' x],tags,'UniformOutput',false);
exclude=[primaryNames stepNames {'CommandBus','StatusBus','PCC_10kV'} scopeNames];
all=find_system(pv,'SearchDepth',1,'Type','Block');all=all(2:end);
secondaryNames={};
for k=1:numel(all)
    [~,nm]=fileparts(all{k});
    if ~ismember(nm,exclude),secondaryNames{end+1}=nm;end %#ok<AGROW>
end
primaryH=handles_for(pv,primaryNames);stepH=handles_for(pv,stepNames);secondaryH=handles_for(pv,secondaryNames);
hp=group_blocks(pv,primaryH,'02 Primary Converter and Filter');
hs=group_blocks(pv,stepH,'02 Step-up and PCC');
hc=group_blocks(pv,secondaryH,'01 Secondary Control');
% Secondary and primary are the complete PCS; the transformer/PCC remains
% its own sibling power-domain module.
hpcs=group_blocks(pv,[hc hp],'01 GFL PCS');
cleanup_unconnected_outports([pv '/01 GFL PCS']);
cleanup_unconnected_outports([pv '/01 GFL PCS/01 Secondary Control']);
rename_single([pv '/01 GFL PCS'],'BlockType','Inport','CommandBus');
rename_single([pv '/01 GFL PCS'],'BlockType','Outport','StatusBus');
rename_single([pv '/01 GFL PCS'],'BlockType','PMIOPort','AC_690V');
set_param([pv '/01 GFL PCS'],'BackgroundColor','[0.83,0.91,1.00]');
set_param([pv '/02 Step-up and PCC'],'BackgroundColor','[0.92,0.88,0.78]');
end

function clear_output_line(block)
p=get_param(block,'PortHandles');
for h=p.Outport
    ln=get_param(h,'Line');if ln>0,delete_line(ln);end
end
end

function h=handles_for(parent,names)
h=zeros(1,numel(names));
for k=1:numel(names),h(k)=getSimulinkBlockHandle([parent '/' names{k}]);assert(h(k)>0,names{k});end
end

function h=group_blocks(parent,blocks,name)
before=find_system(parent,'SearchDepth',1,'BlockType','SubSystem');
Simulink.BlockDiagram.createSubsystem(blocks);
after=find_system(parent,'SearchDepth',1,'BlockType','SubSystem');
new=setdiff(after,before,'stable');assert(numel(new)==1,'Expected one newly created subsystem.');
set_param(new{1},'Name',name);h=getSimulinkBlockHandle([parent '/' name]);
end

function cleanup_unconnected_outports(s)
bs=find_system(s,'SearchDepth',1,'BlockType','Outport');
ports=cellfun(@(b)str2double(get_param(b,'Port')),bs);[~,ord]=sort(ports,'descend');
for jj=1:numel(ord),kk=ord(jj);
    n=str2double(get_param(bs{kk},'Port'));ph=get_param(s,'PortHandles');
    if n<=numel(ph.Outport)&&get_param(ph.Outport(n),'Line')<0,delete_block(bs{kk});end
end
end

function rename_single(s,varargin)
newName=varargin{end};query=varargin(1:end-1);
bs=find_system(s,'SearchDepth',1,query{:});
if numel(bs)==1,set_param(bs{1},'Name',newName);end
end
