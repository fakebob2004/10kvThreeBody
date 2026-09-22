% Build the final 5 MW / 10 MWh BESS-GFM with 1200/1500 V bidirectional DC/DC.
% This derives only from the standalone R5 BESS test bench; PV/wind stay untouched.
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);

% Generate the known-good AC/VSC test bench, then replace only its DC stage.
run(fullfile(scriptDir,'build_bess_gfm_average_pcs.m'));
sourceFile = fullfile(projectRoot,'build','BESS_GFM_10kV_AveragePCS_R5.slx');
modelName = 'BESS_GFM_10kV_Final_R6';
modelFile = fullfile(projectRoot,'build',[modelName '.slx']);
pngFile = fullfile(projectRoot,'build',[modelName '.png']);
copyfile(sourceFile,modelFile,'f');
load_system(modelFile);
run(fullfile(scriptDir,'init_bess_gfm_final_r6.m'));

% Delete the R5 direct battery/DC-link stage and its monitoring blocks.
oldBlocks = {'Battery_OCV','Battery_Current','Battery_Internal_R','DC_Link_C', ...
    'DC_Link_Voltage','DC_Negative_Reference','Vdc_to_Simulink', ...
    'Idc_to_Simulink','Vdc_Filter','Battery_DC_Power','SOC_Rate','SOC'};
for k=1:numel(oldBlocks)
    p=[modelName '/' oldBlocks{k}];
    if getSimulinkBlockHandle(p)>0, delete_block(p); end
end
% Remove destination-side stubs left by deleting the original source blocks.
clear_input_line([modelName '/Divide_By_Vdc'],2);
for k=[6 7 8 10], clear_input_line([modelName '/Result_Mux'],k); end

dcdc = sprintf(['ee_lib/Semiconductors &\nConverters/Converters/' ...
    'Average-Value DC-DC\nConverter']);
eref = 'fl_lib/Electrical/Electrical Elements/Electrical Reference';
sps = sprintf('nesl_utility/Simulink-PS\nConverter');
pss = sprintf('nesl_utility/PS-Simulink\nConverter');

% 1200 V battery Thevenin equivalent and bidirectional buck-boost converter.
add_block('fl_lib/Electrical/Electrical Sources/DC Voltage Source', ...
    [modelName '/Battery_OCV'],'Position',[40 145 90 215],'v0','G.dc.Vbattery_V');
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
    [modelName '/Battery_Current'],'Position',[120 125 180 175]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor', ...
    [modelName '/Battery_Internal_R'],'Position',[210 125 275 175], ...
    'R','G.dc.Rbattery_ohm');
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
    [modelName '/Battery_Terminal_Voltage'],'Position',[300 225 360 285]);
add_block(dcdc,[modelName '/Bidirectional_1200_1500V_DCDC'], ...
    'Position',[390 115 510 225], ...
    'implementation_option','ee.enum.converters.implementation.behavioral', ...
    'converter_type','ee.enum.converters.dcdctype.buckboost', ...
    'control_option','ee.enum.converters.controlinput.voltage', ...
    'efficiency_option','ee.enum.converters.efficiency.constant', ...
    'efficiency_fixed','G.dc.dcdc_efficiency_pct');
add_block('fl_lib/Electrical/Electrical Elements/Capacitor', ...
    [modelName '/DC_Link_C'],'Position',[520 225 580 285], ...
    'c','G.dc.Cdc_F','vc_specify','on','vc','G.dc.Vdc_ref_V');
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
    [modelName '/DC_Link_Voltage'],'Position',[610 225 670 285]);
add_block(eref,[modelName '/DC_Negative_Reference'],'Position',[450 300 480 330]);
add_block('simulink/Sources/Constant',[modelName '/Vdc_1500V_Reference'], ...
    'Position',[290 40 360 70],'Value','G.dc.Vdc_ref_V');
add_block(sps,[modelName '/DCDC_Vref_to_PS'],'Position',[390 30 490 80], ...
    'Unit','V','FilteringAndDerivatives','zero');

% DC measurements and energy accounting use battery-terminal power.
add_block(pss,[modelName '/Vbat_to_Simulink'],'Position',[270 345 370 375],'Unit','V');
add_block(pss,[modelName '/Vdc_to_Simulink'],'Position',[610 345 710 375],'Unit','V');
add_block(pss,[modelName '/Idc_to_Simulink'],'Position',[120 345 220 375],'Unit','A');
add_block('simulink/Continuous/State-Space',[modelName '/Vdc_Filter'], ...
    'Position',[760 405 850 445], ...
    'A','-1/G.control.Vdc_filter_s','B','1/G.control.Vdc_filter_s', ...
    'C','1','D','0','InitialCondition','G.dc.Vdc_ref_V');
add_block('simulink/Math Operations/Product',[modelName '/Battery_DC_Power'], ...
    'Position',[420 345 460 385]);
add_block('simulink/Math Operations/Gain',[modelName '/SOC_Rate'], ...
    'Position',[500 345 610 385],'Gain','-1/(G.bess.E_Wh*3600)');
add_block('simulink/Continuous/Integrator',[modelName '/SOC'], ...
    'Position',[650 405 690 445],'InitialCondition','G.bess.SOC0', ...
    'LimitOutput','on','UpperSaturationLimit','G.bess.SOC_max', ...
    'LowerSaturationLimit','G.bess.SOC_min');

% Battery side physical network.
connectp(modelName,'Battery_OCV','LConn',1,'Battery_Current','LConn',1);
connectp(modelName,'Battery_Current','RConn',2,'Battery_Internal_R','LConn',1);
connectp(modelName,'Battery_Internal_R','RConn',1, ...
    'Bidirectional_1200_1500V_DCDC','LConn',2);
branchp(modelName,porth([modelName '/Battery_Internal_R'],'RConn',1), ...
    porth([modelName '/Battery_Terminal_Voltage'],'LConn',1));
connectp(modelName,'Battery_OCV','RConn',1, ...
    'Bidirectional_1200_1500V_DCDC','LConn',3);
branchp(modelName,porth([modelName '/Battery_OCV'],'RConn',1), ...
    porth([modelName '/Battery_Terminal_Voltage'],'RConn',2));

% Regulated 1500 V DC-link and VSC connection.
connectp(modelName,'Bidirectional_1200_1500V_DCDC','RConn',1, ...
    'Bidirectional_Average_VSC','RConn',1);
branchp(modelName,porth([modelName '/Bidirectional_1200_1500V_DCDC'],'RConn',1), ...
    porth([modelName '/DC_Link_C'],'LConn',1));
branchp(modelName,porth([modelName '/Bidirectional_1200_1500V_DCDC'],'RConn',1), ...
    porth([modelName '/DC_Link_Voltage'],'LConn',1));
connectp(modelName,'Bidirectional_1200_1500V_DCDC','RConn',2, ...
    'Bidirectional_Average_VSC','RConn',2);
branchp(modelName,porth([modelName '/Bidirectional_1200_1500V_DCDC'],'RConn',2), ...
    porth([modelName '/DC_Link_C'],'RConn',1));
branchp(modelName,porth([modelName '/Bidirectional_1200_1500V_DCDC'],'RConn',2), ...
    porth([modelName '/DC_Link_Voltage'],'RConn',2));
branchp(modelName,porth([modelName '/Bidirectional_1200_1500V_DCDC'],'RConn',2), ...
    porth([modelName '/DC_Negative_Reference'],'LConn',1));
add_line(modelName,porth([modelName '/DCDC_Vref_to_PS'],'RConn',1), ...
    porth([modelName '/Bidirectional_1200_1500V_DCDC'],'LConn',1),'autorouting','on');
add_line(modelName,'Vdc_1500V_Reference/1','DCDC_Vref_to_PS/1','autorouting','on');

% Physical-signal measurements.
add_line(modelName,porth([modelName '/Battery_Current'],'RConn',1), ...
    porth([modelName '/Idc_to_Simulink'],'LConn',1),'autorouting','on');
add_line(modelName,porth([modelName '/Battery_Terminal_Voltage'],'RConn',1), ...
    porth([modelName '/Vbat_to_Simulink'],'LConn',1),'autorouting','on');
add_line(modelName,porth([modelName '/DC_Link_Voltage'],'RConn',1), ...
    porth([modelName '/Vdc_to_Simulink'],'LConn',1),'autorouting','on');

% Modulation feedforward, battery power, and SOC.
add_line(modelName,'Vdc_to_Simulink/1','Vdc_Filter/1','autorouting','on');
add_line(modelName,'Vdc_Filter/1','Divide_By_Vdc/2','autorouting','on');
add_line(modelName,'Vbat_to_Simulink/1','Battery_DC_Power/1','autorouting','on');
add_line(modelName,'Idc_to_Simulink/1','Battery_DC_Power/2','autorouting','on');
add_line(modelName,'Battery_DC_Power/1','SOC_Rate/1','autorouting','on');
add_line(modelName,'SOC_Rate/1','SOC/1','autorouting','on');
add_line(modelName,'SOC/1','Result_Mux/6','autorouting','on');
add_line(modelName,'Vdc_to_Simulink/1','Result_Mux/7','autorouting','on');
add_line(modelName,'Idc_to_Simulink/1','Result_Mux/8','autorouting','on');
add_line(modelName,'Battery_DC_Power/1','Result_Mux/10','autorouting','on');

% Final ratings propagate through existing expression-based AC blocks.
set_param([modelName '/Adjusted_Island_Load'], ...
    'active_power','G.load.P_W','reactive_power','G.load.Q_var');
set_param(modelName,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_bess_gfm_final_r6.m'));" );
set_param(modelName,'StopTime','0.7');
anns=find_system(modelName,'FindAll','on','Type','annotation');
for k=1:numel(anns), delete(anns(k)); end
note=Simulink.Annotation(modelName,sprintf([ ...
    'FINAL standalone BESS-GFM baseline (PV/wind untouched)\n' ...
    '5 MW / 10 MWh, 1200 V battery, 1500 V bidirectional DC/DC\n' ...
    '6.25 MVA average PCS; 6.3 MVA 0.69/10 kV transformer\n' ...
    'SOC 20-90%%, initial 55%%; P charge/discharge limits 5 MW']));
note.Position=[80 760 800 850];
save_system(modelName,modelFile);
set_param(modelName,'SimulationCommand','update');
fprintf('BESS_GFM_FINAL_R6_UPDATE_OK=1\n');
try, print(['-s' modelName],'-dpng',pngFile); catch ME, fprintf('%s\n',ME.message); end
save_system(modelName,modelFile); close_system(modelName,0);
fprintf('BESS_GFM_FINAL_R6_MODEL=%s\n',modelFile);

function h=porth(block,side,index)
p=get_param(block,'PortHandles'); h=p.(side)(index);
end
function connectp(model,a,sa,ia,b,sb,ib)
add_line(model,porth([model '/' a],sa,ia),porth([model '/' b],sb,ib),'autorouting','on');
end
function branchp(model,a,b)
add_line(model,a,b,'autorouting','on');
end
function clear_input_line(block,index)
p=get_param(block,'PortHandles'); h=get_param(p.Inport(index),'Line');
if h>0, delete_line(h); end
end
