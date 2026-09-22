% System-level GFL commissioning model: controlled-current average converter.
% The outer interfaces and control hierarchy come from the teammate 864
% model; switching and the stiff inner voltage loop are deliberately reduced.
scriptDir=fileparts(mfilename('fullpath')); root=fileparts(scriptDir);
shell=fullfile(root,'build','PV_GFL_Strong_SM_Commissioning.slx');
model='PV_GFL_864_SystemLevel_SM_R2';
modelFile=fullfile(root,'build',[model '.slx']); pngFile=fullfile(root,'build',[model '.png']);
copyfile(shell,modelFile,'f');
load_system(modelFile); load_system(shell); load_system('ee_lib'); load_system('fl_lib'); load_system('nesl_utility');
run(fullfile(scriptDir,'init_pv_gfl_864_average_sm.m'));
for n={'01 PV Two-Level VSC','02 GFL Controller - PLL Commissioning','03 PV Filter Transformer and PCC'}
    p=[model '/' n{1}]; if getSimulinkBlockHandle(p)>0,delete_block(p);end
end

pv=[model '/01 PV-GFL System-Level Branch'];
add_block('built-in/Subsystem',pv,'Position',[180 190 690 520], ...
    'BackgroundColor','[0.82,0.94,0.80]','ShowPortLabels','FromPortIcon', ...
    'AttributesFormatString',sprintf([ ...
    '5 MW / 6.25 MVA | 690 V / 10 kV\n' ...
    'Local SRF-PLL + P/Q-to-dq current command\n' ...
    'System-level controlled-current average converter']));
add_pmio(pv,'PCC_10kV',1,'Right','foundation.electrical.three_phase',[1240 200 1270 230]);
add_block('simulink/Ports & Subsystems/In1',[pv '/CommandBus'], ...
    'Position',[25 500 55 514],'Port','1');
add_block('simulink/Signal Routing/Demux',[pv '/CommandBus Selector'], ...
    'Position',[90 455 95 565],'Outputs','3');
add_line(pv,'CommandBus/1','CommandBus Selector/1');

ccs=sprintf('ee_lib/Sources/Controlled Current\nSource\n(Three-Phase)');
iv3=sprintf('ee_lib/Sensors &\nTransducers/Current and Voltage\nSensor (Three-Phase)');
pq3=sprintf('ee_lib/Sensors &\nTransducers/Power Sensor\n(Three-Phase)');
rlc3='ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)';
xf3=sprintf('ee_lib/Passive/Transformers/Two-Winding\nTransformer\n(Three-Phase)');
gnd3=sprintf('ee_lib/Connectors &\nReferences/Grounded Neutral\n(Three-Phase)');
sps=sprintf('nesl_utility/Simulink-PS\nConverter');
pss=sprintf('nesl_utility/PS-Simulink\nConverter');
add_block(ccs,[pv '/Average GFL Current Injection'],'Position',[315 145 420 225], ...
    'input_option','ee.enum.inputType.instantaneous','FRated','S1.base.f_Hz');
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    [pv '/Converter Neutral'],'Position',[245 245 275 275]);
add_block(iv3,[pv '/Converter-Side VI Sensor'],'Position',[470 145 565 225]);
add_block(rlc3,[pv '/Interface RL'],'Position',[610 160 695 210], ...
    'component_structure','ee.enum.rlc.structure.R', ...
    'R','S1.filter.R1_ohm+S1.filter.R2_ohm');
add_block(rlc3,[pv '/Damped Shunt C'],'Position',[585 245 670 295], ...
    'component_structure','ee.enum.rlc.structure.SeriesRC', ...
    'R','S1.filter.Rd_ohm','C','S1.filter.C_F');
add_block(gnd3,[pv '/Filter Ground'],'Position',[705 250 735 280]);
add_block(xf3,[pv '/T_PV_0p69_10kV'],'Position',[745 140 860 230], ...
    'SRated','S1.transformer.S_VA','FRated','S1.base.f_Hz', ...
    'VRated1','S1.pv.Vll_low_V','VRated2','S1.pv.Vll_high_V', ...
    'Winding1Connection','ee.enum.windingconnection.Yg', ...
    'Winding2Connection','ee.enum.windingconnection.Yg', ...
    'pu_Rw1','S1.transformer.R_pu/2','pu_Rw2','S1.transformer.R_pu/2', ...
    'leakage_reactance_option','ee.enum.transformer_leakage.exclude');
add_block(pq3,[pv '/PV PCC Power Sensor'],'Position',[920 150 1000 215]);
% Port domains: LConn(1)=physical-signal current command, LConn(2)=scalar
% neutral, RConn(1)=composite abc electrical terminal.
connectp(pv,'Average GFL Current Injection','LConn',2,'Converter Neutral','LConn',1);
connectp(pv,'Average GFL Current Injection','RConn',1,'Converter-Side VI Sensor','LConn',1);
connectp(pv,'Converter-Side VI Sensor','RConn',3,'Interface RL','LConn',1);
connectp(pv,'Damped Shunt C','RConn',1,'Filter Ground','LConn',1);
add_line(pv,porth([pv '/Converter-Side VI Sensor'],'RConn',3), ...
    porth([pv '/Damped Shunt C'],'LConn',1),'autorouting','on');
connectp(pv,'Interface RL','RConn',1,'T_PV_0p69_10kV','LConn',1);
connectp(pv,'T_PV_0p69_10kV','RConn',1,'PV PCC Power Sensor','LConn',1);
connect_handle(pv,porth([pv '/PV PCC Power Sensor'],'RConn',1),pmio_handle([pv '/PCC_10kV']));

add_block(pss,[pv '/vabc to Simulink'],'Position',[475 285 575 320],'Unit','V');
add_block(pss,[pv '/iabc to Simulink'],'Position',[475 335 575 370],'Unit','A');
add_block(pss,[pv '/P to Simulink'],'Position',[920 285 1020 320],'Unit','W');
add_block(pss,[pv '/Q to Simulink'],'Position',[920 335 1020 370],'Unit','W');
connect_handle(pv,porth([pv '/Converter-Side VI Sensor'],'RConn',1),porth([pv '/vabc to Simulink'],'LConn',1));
connect_handle(pv,porth([pv '/Converter-Side VI Sensor'],'RConn',2),porth([pv '/iabc to Simulink'],'LConn',1));
connect_handle(pv,porth([pv '/PV PCC Power Sensor'],'LConn',2),porth([pv '/P to Simulink'],'LConn',1));
connect_handle(pv,porth([pv '/PV PCC Power Sensor'],'LConn',3),porth([pv '/Q to Simulink'],'LConn',1));
add_block('simulink/Sinks/To Workspace',[pv '/Local Voltage Record'], ...
    'Position',[585 285 650 315],'VariableName','gfl_r2_vabc','SaveFormat','Array','MaxDataPoints','inf');
add_line(pv,'vabc to Simulink/1','Local Voltage Record/1');

% Transparent local phase PLL.  It estimates the phase from local abc
% voltage, wraps the phase error, applies PI frequency correction, and
% integrates its own angle; no machine angle is shared.
add_local_phase_pll(pv,'02 Local SRF-PLL',[660 300 820 395]);
add_line(pv,'vabc to Simulink/1','02 Local SRF-PLL/1','autorouting','on');

% CommandBus = [P_cmd_W, Q_cmd_var, enable].  Only one logical command
% connection crosses the branch boundary, following the large-system
% controller/plant separation used by both reference projects.
add_block('simulink/User-Defined Functions/Fcn',[pv '/Line Voltage Peak Magnitude'], ...
    'Position',[260 370 430 405],'Expr','sqrt((2/3)*(u(1)^2+u(2)^2+u(3)^2))');
add_block('simulink/Signal Routing/Mux',[pv '/P and Voltage'],'Position',[300 420 305 480],'Inputs','2');
add_block('simulink/Signal Routing/Mux',[pv '/Q and Voltage'],'Position',[300 515 305 575],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[pv '/P to Id'],'Position',[330 440 430 470], ...
    'Expr','2*u(1)/(sqrt(3)*sqrt(u(2)^2+1))');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Q to Iq'],'Position',[330 535 430 565], ...
    'Expr','-2*(u(1)-(2*pi*S1.base.f_Hz*S1.filter.C_F/2)*u(2)^2)/(sqrt(3)*sqrt(u(2)^2+1))');
add_block('simulink/Discontinuities/Saturation',[pv '/Id Limit'],'Position',[470 435 550 475], ...
    'UpperLimit','S1.control.Ilimit_A','LowerLimit','-S1.control.Ilimit_A');
add_block('simulink/Discontinuities/Saturation',[pv '/Iq Limit'],'Position',[470 530 550 570], ...
    'UpperLimit','S1.control.Ilimit_A','LowerLimit','-S1.control.Ilimit_A');
add_block('simulink/Continuous/Transfer Fcn',[pv '/Id Tracking'],'Position',[590 435 680 475], ...
    'Numerator','1','Denominator','[1/(2*pi*S1.control.current_bandwidth_Hz) 1]');
add_block('simulink/Continuous/Transfer Fcn',[pv '/Iq Tracking'],'Position',[590 530 680 570], ...
    'Numerator','1','Denominator','[1/(2*pi*S1.control.current_bandwidth_Hz) 1]');
add_line(pv,'vabc to Simulink/1','Line Voltage Peak Magnitude/1','autorouting','on');
add_line(pv,'CommandBus Selector/1','P and Voltage/1');add_line(pv,'Line Voltage Peak Magnitude/1','P and Voltage/2');
add_line(pv,'CommandBus Selector/2','Q and Voltage/1');add_line(pv,'Line Voltage Peak Magnitude/1','Q and Voltage/2');
add_line(pv,'P and Voltage/1','P to Id/1'); add_line(pv,'P to Id/1','Id Limit/1'); add_line(pv,'Id Limit/1','Id Tracking/1');
add_line(pv,'Q and Voltage/1','Q to Iq/1'); add_line(pv,'Q to Iq/1','Iq Limit/1'); add_line(pv,'Iq Limit/1','Iq Tracking/1');

add_block('simulink/Signal Routing/Mux',[pv '/dq theta'],'Position',[725 430 730 575],'Inputs','3');
add_line(pv,'Id Tracking/1','dq theta/1'); add_line(pv,'Iq Tracking/1','dq theta/2');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Line-to-Phase Angle Compensation'], ...
    'Position',[655 390 780 420],'Expr','u-pi/6');
add_line(pv,'02 Local SRF-PLL/1','Line-to-Phase Angle Compensation/1');
add_line(pv,'Line-to-Phase Angle Compensation/1','dq theta/3');
names={'a','b','c'}; phase={'','-2*pi/3','+2*pi/3'};
for k=1:3
    expr=sprintf('u(1)*sin(u(3)%s)+u(2)*cos(u(3)%s)',phase{k},phase{k});
    add_block('simulink/User-Defined Functions/Fcn',[pv '/i' names{k}], ...
        'Position',[770 430+55*(k-1) 950 460+55*(k-1)],'Expr',expr);
    add_line(pv,'dq theta/1',['i' names{k} '/1']);
end
add_block('simulink/Signal Routing/Mux',[pv '/iabc Command'],'Position',[990 425 995 575],'Inputs','3');
for k=1:3,add_line(pv,['i' names{k} '/1'],sprintf('iabc Command/%d',k));end
add_block(sps,[pv '/Current Command to PS'],'Position',[1040 470 1140 530], ...
    'Unit','A','FilteringAndDerivatives','zero');
add_line(pv,'iabc Command/1','Current Command to PS/1');
connect_handle(pv,porth([pv '/Current Command to PS'],'RConn',1), ...
    porth([pv '/Average GFL Current Injection'],'LConn',1));

% Compact status interface: t, P, Q, P*, Q*, theta, f, Id*, Iq*, |I| limit.
add_block('simulink/Sources/Clock',[pv '/Time'],'Position',[1040 610 1070 640]);
add_block('simulink/Math Operations/Gain',[pv '/omega to Hz'],'Position',[850 380 930 410],'Gain','1/(2*pi)');
add_line(pv,'02 Local SRF-PLL/2','omega to Hz/1');
add_block('simulink/Sources/Constant',[pv '/Current Limit Status'],'Position',[815 610 930 640],'Value','S1.control.Ilimit_A');
add_block('simulink/Signal Routing/Mux',[pv '/StatusBus Elements'],'Position',[1170 280 1175 690],'Inputs','11');
sig={'Time/1','P to Simulink/1','Q to Simulink/1','CommandBus Selector/1','CommandBus Selector/2', ...
    '02 Local SRF-PLL/1','omega to Hz/1','Id Tracking/1','Iq Tracking/1', ...
    'Current Limit Status/1','02 Local SRF-PLL/3'};
for k=1:numel(sig),add_line(pv,sig{k},sprintf('StatusBus Elements/%d',k),'autorouting','on');end
add_block('simulink/Ports & Subsystems/Out1',[pv '/StatusBus'], ...
    'Position',[1240 450 1270 464],'Port','1');
add_line(pv,'StatusBus Elements/1','StatusBus/1');

cmd=[model '/02 Commissioning Command Profile'];
add_command_profile(cmd,[55 235 145 355]);
add_block('simulink/Sinks/To Workspace',[model '/03 StatusBus Recorder'], ...
    'Position',[700 555 825 595],'VariableName','gfl_r2_status','SaveFormat','Array','MaxDataPoints','inf');
sm=[model '/Strong Synchronous Machine (Governor + AVR)']; set_param(sm,'Position',[850 190 1175 520]);
pvPH=get_param(pv,'PortHandles'); smPH=get_param(sm,'PortHandles'); cmdPH=get_param(cmd,'PortHandles');
add_line(model,cmdPH.Outport(1),pvPH.Inport(1),'autorouting','on');
statusPH=get_param([model '/03 StatusBus Recorder'],'PortHandles');
add_line(model,pvPH.Outport(1),statusPH.Inport(1),'autorouting','on');
add_line(model,pvPH.RConn(1),smPH.RConn(1),'autorouting','on');
add_block('nesl_utility/Solver Configuration',[model '/Physical Network Solver'],'Position',[720 425 785 480]);
solPH=get_param([model '/Physical Network Solver'],'PortHandles'); add_line(model,solPH.RConn(1),pvPH.RConn(1),'autorouting','on');
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation'); for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'PV-GFL R2 — system-level controlled-current model, commissioned against a strong synchronous machine\n' ...
    'Retained from 864: local PLL, P/Q commands, dq current orientation, limits and telemetry. Removed: switching PWM and gate-level VSC.\n' ...
    'Electrical boundary: 5 MW / 6.25 MVA, 690 V converter side, 0.69/10 kV 6.3 MVA transformer, 10 kV PCC.']));
a.Position=[65 35 1340 125];a.FontSize=14;a.FontWeight='bold';
set_param(model,'PreLoadFcn','','InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_pv_gfl_864_average_sm.m'));", ...
    'StopTime','0.20','MaxStep','1e-5','SolverType','Variable-step','Solver','ode23t','Location',[60 60 1450 850]);
save_system(model,modelFile); set_param(model,'SimulationCommand','update'); save_system(model,modelFile);
try,print(['-s' model],'-dpng',pngFile);catch ME,fprintf('PNG_WARNING=%s\n',ME.message);end
close_system(model,0);close_system('PV_GFL_Strong_SM_Commissioning',0);
fprintf('PV_GFL_SYSTEM_LEVEL_MODEL=%s\n',modelFile);

function h=porth(block,side,index),p=get_param(block,'PortHandles');h=p.(side)(index);end
function connectp(sys,a,sa,ia,b,sb,ib),add_line(sys,porth([sys '/' a],sa,ia),porth([sys '/' b],sb,ib),'autorouting','on');end
function connect_handle(sys,a,b),add_line(sys,a,b,'autorouting','on');end
function add_pmio(sys,name,port,side,domain,pos),add_block('built-in/PMIOPort',[sys '/' name],'Port',num2str(port),'Side',side,'ConnectionType',['Connection: ' domain],'Position',pos);end
function h=pmio_handle(block),p=get_param(block,'PortHandles');h=[p.LConn p.RConn];assert(numel(h)==1);end
function add_command_profile(s,pos)
add_block('built-in/Subsystem',s,'Position',pos,'BackgroundColor','[1.00,0.94,0.78]', ...
    'AttributesFormatString',sprintf('CommandBus = [P*, Q*, enable]\ncommissioning scenario only'));
add_block('simulink/Sources/Ramp',[s '/P Soft Start'],'Position',[25 35 95 65], ...
    'slope','S1.pv.P_ramp_W_per_s','start','0','InitialOutput','0');
add_block('simulink/Discontinuities/Saturation',[s '/P Base Limit'],'Position',[125 35 210 65], ...
    'UpperLimit','S1.pv.P_initial_W','LowerLimit','0');
add_block('simulink/Sources/Step',[s '/P Increment'],'Position',[25 80 95 110], ...
    'Time','S1.pv.P_step_time_s','Before','0','After','S1.pv.P_final_W-S1.pv.P_initial_W');
add_block('simulink/Math Operations/Sum',[s '/P Command'],'Position',[245 42 275 103],'Inputs','++');
add_block('simulink/Sources/Constant',[s '/Q Base Command'],'Position',[25 135 95 165],'Value','S1.pv.Q_ref_var');
add_block('simulink/Sources/Step',[s '/Q Increment'],'Position',[25 180 95 210], ...
    'Time','S1.pv.Q_step_time_s','Before','0','After','S1.pv.Q_step_var');
add_block('simulink/Math Operations/Sum',[s '/Q Command'],'Position',[245 142 275 203],'Inputs','++');
add_block('simulink/Sources/Constant',[s '/Enable'],'Position',[245 230 295 260],'Value','1');
add_block('simulink/Signal Routing/Mux',[s '/CommandBus'],'Position',[330 55 335 255],'Inputs','3');
add_block('simulink/Ports & Subsystems/Out1',[s '/CommandBus Out'],'Position',[380 145 410 159]);
add_line(s,'P Soft Start/1','P Base Limit/1');add_line(s,'P Base Limit/1','P Command/1');
add_line(s,'P Increment/1','P Command/2');add_line(s,'Q Base Command/1','Q Command/1');
add_line(s,'Q Increment/1','Q Command/2');add_line(s,'P Command/1','CommandBus/1');
add_line(s,'Q Command/1','CommandBus/2');add_line(s,'Enable/1','CommandBus/3');
add_line(s,'CommandBus/1','CommandBus Out/1');
end
function add_local_phase_pll(parent,name,pos)
s=[parent '/' name];add_block('built-in/Subsystem',s,'Position',pos, ...
    'BackgroundColor','[0.87,0.92,1.00]','AttributesFormatString', ...
    sprintf('local abc voltage only\nwrapped phase-error PI'));
add_block('simulink/Ports & Subsystems/In1',[s '/Vabc'],'Position',[25 78 55 92]);
add_block('simulink/User-Defined Functions/Fcn',[s '/Measured Phase'], ...
    'Position',[85 65 300 105], ...
    'Expr','atan2((2/3)*(u(1)-0.5*u(2)-0.5*u(3)),(sqrt(3)/3)*(u(3)-u(2)))');
add_block('simulink/Signal Routing/Mux',[s '/Phase Pair'],'Position',[335 60 340 145],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[s '/Wrapped Phase Error'], ...
    'Position',[375 80 535 115],'Expr','atan2(sin(u(1)-u(2)),cos(u(1)-u(2)))');
add_block('simulink/Math Operations/Gain',[s '/PLL Kp'],'Position',[570 45 645 75],'Gain','Control.PLL.Kp');
add_block('simulink/Math Operations/Gain',[s '/PLL Ki'],'Position',[570 120 645 150],'Gain','Control.PLL.Ki');
add_block('simulink/Continuous/Integrator',[s '/Error Integral'],'Position',[680 115 715 155],'InitialCondition','0');
add_block('simulink/Math Operations/Sum',[s '/Delta Omega'],'Position',[755 65 785 130],'Inputs','++');
add_block('simulink/Sources/Constant',[s '/Nominal Omega'],'Position',[755 20 835 50],'Value','Control.PLL.OmegaNominal');
add_block('simulink/Math Operations/Sum',[s '/Omega Command'],'Position',[870 55 900 115],'Inputs','++');
add_block('simulink/Discontinuities/Saturation',[s '/Omega Limits'],'Position',[935 65 1020 105], ...
    'UpperLimit','Control.PLL.OmegaMax','LowerLimit','Control.PLL.OmegaMin');
add_block('simulink/Continuous/Integrator',[s '/Angle Integrator'],'Position',[1060 65 1100 105], ...
    'InitialCondition','Control.PLL.Theta0');
add_block('simulink/Ports & Subsystems/Out1',[s '/theta'],'Position',[1150 65 1180 79],'Port','1');
add_block('simulink/Ports & Subsystems/Out1',[s '/omega'],'Position',[1150 110 1180 124],'Port','2');
add_block('simulink/Ports & Subsystems/Out1',[s '/phase error'],'Position',[1150 155 1180 169],'Port','3');
add_line(s,'Vabc/1','Measured Phase/1');add_line(s,'Measured Phase/1','Phase Pair/1');
add_line(s,'Angle Integrator/1','Phase Pair/2');add_line(s,'Phase Pair/1','Wrapped Phase Error/1');
add_line(s,'Wrapped Phase Error/1','PLL Kp/1');add_line(s,'Wrapped Phase Error/1','PLL Ki/1');
add_line(s,'PLL Ki/1','Error Integral/1');add_line(s,'PLL Kp/1','Delta Omega/1');
add_line(s,'Error Integral/1','Delta Omega/2');add_line(s,'Delta Omega/1','Omega Command/1');
add_line(s,'Nominal Omega/1','Omega Command/2');add_line(s,'Omega Command/1','Omega Limits/1');
add_line(s,'Omega Limits/1','Angle Integrator/1');add_line(s,'Angle Integrator/1','theta/1');
add_line(s,'Omega Limits/1','omega/1');add_line(s,'Wrapped Phase Error/1','phase error/1');
end
