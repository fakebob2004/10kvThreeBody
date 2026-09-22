% Build Stage 1 from the frozen R8 artifact.  R8 is copied, never rebuilt.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
sourceFile=fullfile(projectRoot,'build','BESS_GFM_10kV_Readable_R8.slx');
modelName='BESS_GFM_PV_GFL_10kV_Stage1';
modelFile=fullfile(projectRoot,'build',[modelName '.slx']);
pngFile=fullfile(projectRoot,'build',[modelName '.png']);
assert(isfile(sourceFile),'Frozen R8 model is missing.');
copyfile(sourceFile,modelFile,'f');
load_system(modelFile); open_system(modelName);
run(fullfile(scriptDir,'init_bess_pv_stage1.m'));
load_system('ee_lib'); load_system('fl_lib'); load_system('nesl_utility');
referenceController=fullfile(projectRoot,'references', ...
    'Renewable-Energy-Integration-Simscape-master','Models','PVPlant','PVcontroller.slx');
assert(isfile(referenceController),'Reference PV controller containing the verified PLL is missing.');
load_system(referenceController);

% Make room for the second source without changing R8 internals.
set_param([modelName '/03 Island Load Scenario'],'Name','04 Island Load Scenario');
set_param([modelName '/04 Supervision and Results'],'Name','05 Supervision and Results');
loadSys=[modelName '/04 Island Load Scenario'];
set_param([loadSys '/Adjusted_Island_Load'],'active_power','S1.load.P_W', ...
    'reactive_power','S1.load.Q_var');
set_param([loadSys '/One_MW_Step_Load'],'active_power','0','reactive_power','0');

pv=[modelName '/03 PV-GFL Branch'];
add_block('built-in/Subsystem',pv,'Position',[500 485 800 685], ...
    'BackgroundColor','[0.82,0.94,0.80]','ForegroundColor','black', ...
    'ShowPortLabels','FromPortIcon','AttributesFormatString',sprintf([ ...
    'PV DC equivalent + local SRF-PLL / dq current control\n' ...
    '5 MW, 6.25 MVA, 1295.8 Vdc, 0.69 / 10 kV']));
add_pmio(pv,'PCC_10kV',1,'Right','foundation.electrical.three_phase',[1240 250 1270 280]);

% Library blocks.
vsc3=sprintf(['ee_lib/Semiconductors &\nConverters/Converters/' ...
    'Average-Value\nVoltage Source\nConverter\n(Three-Phase)']);
iv3=sprintf('ee_lib/Sensors &\nTransducers/Current and Voltage\nSensor (Three-Phase)');
pq3=sprintf('ee_lib/Sensors &\nTransducers/Power Sensor\n(Three-Phase)');
rlc3='ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)';
xfmr3=sprintf('ee_lib/Passive/Transformers/Two-Winding\nTransformer\n(Three-Phase)');
gnd3=sprintf('ee_lib/Connectors &\nReferences/Grounded Neutral\n(Three-Phase)');
sps=sprintf('nesl_utility/Simulink-PS\nConverter');
pss=sprintf('nesl_utility/PS-Simulink\nConverter');
eref='fl_lib/Electrical/Electrical Elements/Electrical Reference';

% Independent PV-side DC equivalent and DC link.  This source is replaced
% by array + MPPT after the AC GFL baseline is stable.
add_block('fl_lib/Electrical/Electrical Sources/DC Voltage Source',[pv '/PV_DC_Equivalent'], ...
    'Position',[40 155 90 225],'v0','S1.pv.Vdc_ref_V');
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[pv '/PV_DC_Current'], ...
    'Position',[125 135 185 185]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[pv '/PV_DC_Source_R'], ...
    'Position',[220 135 285 185],'R','S1.pv.dc_source_R_ohm');
add_block('fl_lib/Electrical/Electrical Elements/Capacitor',[pv '/PV_DC_Link_C'], ...
    'Position',[315 225 375 285],'c','S1.pv.Cdc_F','vc_specify','on', ...
    'vc','S1.pv.Vdc_ref_V');
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[pv '/PV_DC_Voltage'], ...
    'Position',[405 225 465 285]);
add_block(eref,[pv '/PV_DC_Reference'],'Position',[245 305 275 335]);
add_block(vsc3,[pv '/PV_Average_VSC'],'Position',[510 125 620 215], ...
    'input_option','ee.enum.converters.inputOption.ModWave', ...
    'frequency_option','ee.enum.converters.frequency.variable', ...
    'FRated','S1.base.f_Hz','krec','0.001');
add_block(iv3,[pv '/PV_AC_IV_Sensor'],'Position',[665 130 755 210]);
add_block(rlc3,[pv '/PV_LCL_L1'],'Position',[790 145 870 195], ...
    'component_structure','ee.enum.rlc.structure.SeriesRL','R','S1.filter.R1_ohm','L','S1.filter.L1_H');
add_block(rlc3,[pv '/PV_LCL_L2'],'Position',[900 145 980 195], ...
    'component_structure','ee.enum.rlc.structure.SeriesRL','R','S1.filter.R2_ohm','L','S1.filter.L2_H');
add_block(rlc3,[pv '/PV_LCL_Damped_C'],'Position',[855 235 935 285], ...
    'component_structure','ee.enum.rlc.structure.SeriesRC','R','S1.filter.Rd_ohm','C','S1.filter.C_F');
add_block(gnd3,[pv '/PV_Filter_Ground'],'Position',[965 245 995 275]);
add_block(xfmr3,[pv '/T_PV_0p69_10kV'],'Position',[1020 125 1130 215], ...
    'SRated','S1.transformer.S_VA','FRated','S1.base.f_Hz', ...
    'VRated1','S1.pv.Vll_low_V','VRated2','S1.pv.Vll_high_V', ...
    'Winding1Connection','ee.enum.windingconnection.delta1', ...
    'Winding2Connection','ee.enum.windingconnection.Yg', ...
    'pu_Rw1','S1.transformer.R_pu/2','pu_Rw2','S1.transformer.R_pu/2', ...
    'leakage_reactance_option','ee.enum.transformer_leakage.include', ...
    'pu_Xl1','S1.transformer.X_pu/2','pu_Xl2','S1.transformer.X_pu/2');
add_block(pq3,[pv '/PV_PQ_Sensor'],'Position',[1160 140 1230 200]);

% Physical network.
connectp(pv,'PV_DC_Equivalent','LConn',1,'PV_DC_Current','LConn',1);
connectp(pv,'PV_DC_Current','RConn',2,'PV_DC_Source_R','LConn',1);
connectp(pv,'PV_DC_Source_R','RConn',1,'PV_Average_VSC','RConn',1);
connectp(pv,'PV_DC_Equivalent','RConn',1,'PV_Average_VSC','RConn',2);
branchp(pv,porth([pv '/PV_DC_Source_R'],'RConn',1),porth([pv '/PV_DC_Link_C'],'LConn',1));
branchp(pv,porth([pv '/PV_DC_Source_R'],'RConn',1),porth([pv '/PV_DC_Voltage'],'LConn',1));
branchp(pv,porth([pv '/PV_DC_Equivalent'],'RConn',1),porth([pv '/PV_DC_Link_C'],'RConn',1));
branchp(pv,porth([pv '/PV_DC_Equivalent'],'RConn',1),porth([pv '/PV_DC_Voltage'],'RConn',2));
branchp(pv,porth([pv '/PV_DC_Equivalent'],'RConn',1),porth([pv '/PV_DC_Reference'],'LConn',1));
connectp(pv,'PV_Average_VSC','LConn',2,'PV_AC_IV_Sensor','LConn',1);
connectp(pv,'PV_AC_IV_Sensor','RConn',3,'PV_LCL_L1','LConn',1);
connectp(pv,'PV_LCL_L1','RConn',1,'PV_LCL_L2','LConn',1);
branchp(pv,porth([pv '/PV_LCL_L1'],'RConn',1),porth([pv '/PV_LCL_Damped_C'],'LConn',1));
connectp(pv,'PV_LCL_Damped_C','RConn',1,'PV_Filter_Ground','LConn',1);
connectp(pv,'PV_LCL_L2','RConn',1,'T_PV_0p69_10kV','LConn',1);
connectp(pv,'T_PV_0p69_10kV','RConn',1,'PV_PQ_Sensor','LConn',1);
connect_handle(pv,porth([pv '/PV_PQ_Sensor'],'RConn',1),pmio_handle([pv '/PCC_10kV']));

% Convert local measurements.
add_block(pss,[pv '/iabc_to_Simulink'],'Position',[660 330 760 365],'Unit','A');
add_block(pss,[pv '/vabc_to_Simulink'],'Position',[660 380 760 415],'Unit','V');
add_block(pss,[pv '/Ppv_to_Simulink'],'Position',[1110 330 1210 365],'Unit','W');
add_block(pss,[pv '/Qpv_to_Simulink'],'Position',[1110 380 1210 415],'Unit','W');
add_block(pss,[pv '/Vdc_to_Simulink'],'Position',[405 345 505 380],'Unit','V');
% Sensor physical-signal order is voltage, current, then three-phase pass-through.
connect_handle(pv,porth([pv '/PV_AC_IV_Sensor'],'RConn',2),porth([pv '/iabc_to_Simulink'],'LConn',1));
connect_handle(pv,porth([pv '/PV_AC_IV_Sensor'],'RConn',1),porth([pv '/vabc_to_Simulink'],'LConn',1));
connect_handle(pv,porth([pv '/PV_PQ_Sensor'],'LConn',2),porth([pv '/Ppv_to_Simulink'],'LConn',1));
connect_handle(pv,porth([pv '/PV_PQ_Sensor'],'LConn',3),porth([pv '/Qpv_to_Simulink'],'LConn',1));
connect_handle(pv,porth([pv '/PV_DC_Voltage'],'RConn',1),porth([pv '/Vdc_to_Simulink'],'LConn',1));
add_block('simulink/Continuous/State-Space',[pv '/iabc_Sensor_Filter'], ...
    'Position',[770 330 850 365], ...
    'A','-eye(3)/S1.control.sensor_filter_s','B','eye(3)/S1.control.sensor_filter_s', ...
    'C','eye(3)','D','zeros(3)','InitialCondition','zeros(3,1)');
add_block('simulink/Continuous/State-Space',[pv '/vabc_Sensor_Filter'], ...
    'Position',[770 380 850 415], ...
    'A','-eye(3)/S1.control.sensor_filter_s','B','eye(3)/S1.control.sensor_filter_s', ...
    'C','eye(3)','D','zeros(3)', ...
    'InitialCondition',['sqrt(2/3)*S1.pv.Vll_low_V*' ...
    '[sin(pi/6);sin(pi/6-2*pi/3);sin(pi/6+2*pi/3)]']);
add_block('simulink/Math Operations/Reshape',[pv '/iabc_Vector'], ...
    'Position',[720 330 750 365],'OutputDimensionality','1-D array');
add_block('simulink/Math Operations/Reshape',[pv '/vabc_Vector'], ...
    'Position',[720 380 750 415],'OutputDimensionality','1-D array');
add_line(pv,'iabc_to_Simulink/1','iabc_Vector/1');
add_line(pv,'vabc_to_Simulink/1','vabc_Vector/1');
add_line(pv,'iabc_Vector/1','iabc_Sensor_Filter/1');
add_line(pv,'vabc_Vector/1','vabc_Sensor_Filter/1');

% Verified reference-project PLL.  It is copied into this model so the
% generated Stage 1 artifact does not depend on PVcontroller.slx at run time.
add_block('PVcontroller/PLL & Measurements',[pv '/Reference_Project_PLL'], ...
    'Position',[880 345 1035 440]);
pllCore=sprintf('%s/Reference_Project_PLL/Subsystem/Sinusoidal Measurement\n(PLL, Three-Phase)',pv);
set_param(pllCore,'Kp_LF','S1.control.pll_Kp','Ki_LF','S1.control.pll_Ki', ...
    'F0','S1.base.f_Hz','Theta0','S1.control.pll_initial_phase_rad', ...
    'Ts','S1.control.pll_sample_s');
% The reference controller feeds this PLL in per unit.  Preserve that
% interface explicitly instead of applying its gains to 690 V quantities.
add_block('simulink/Math Operations/Gain',[pv '/PLL_Input_Per_Unit'], ...
    'Position',[855 365 875 405], ...
    'Gain','1/(sqrt(2/3)*S1.pv.Vll_low_V)');
set_param(pllCore,'LinkStatus','none');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Direct_Angle_Monitor'], ...
    'Position',[865 420 1080 450], ...
    'Expr','atan2((2/3)*(u(1)-0.5*u(2)-0.5*u(3)),(sqrt(3)/3)*(u(3)-u(2)))');
add_block('simulink/Signal Routing/Mux',[pv '/PLL_Phase_Inputs'], ...
    'Position',[1100 405 1105 450],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[pv '/PLL_Phase_Error'], ...
    'Position',[1130 405 1290 440], ...
    'Expr','atan2(sin(u(1)-u(2)),cos(u(1)-u(2)))');
add_line(pv,'vabc_Sensor_Filter/1','PLL_Input_Per_Unit/1');
add_line(pv,'PLL_Input_Per_Unit/1','Reference_Project_PLL/1');
add_line(pv,'vabc_Sensor_Filter/1','Direct_Angle_Monitor/1');
add_line(pv,'Direct_Angle_Monitor/1','PLL_Phase_Inputs/1');
add_line(pv,'Reference_Project_PLL/2','PLL_Phase_Inputs/2');
add_line(pv,'PLL_Phase_Inputs/1','PLL_Phase_Error/1');

% abc/dq measurements.
add_block('simulink/Signal Routing/Mux',[pv '/DQ_Inputs'],'Position',[790 465 795 610],'Inputs','3');
exprD='(2/3)*(sin(u(7))*u(1)+sin(u(7)-2*pi/3)*u(2)+sin(u(7)+2*pi/3)*u(3))';
exprQ='(2/3)*(cos(u(7))*u(1)+cos(u(7)-2*pi/3)*u(2)+cos(u(7)+2*pi/3)*u(3))';
add_block('simulink/User-Defined Functions/Fcn',[pv '/Vd'],'Position',[825 455 1010 485],'Expr',exprD);
add_block('simulink/User-Defined Functions/Fcn',[pv '/Vq'],'Position',[825 495 1010 525],'Expr',exprQ);
% Voltage and current sensor outputs are local phase-domain abc quantities;
% use the PLL phase directly.  No line-to-phase 30 degree correction belongs
% in this converter-side reference frame.
add_block('simulink/User-Defined Functions/Fcn',[pv '/Id'],'Position',[825 535 1010 565], ...
    'Expr','(2/3)*(sin(u(7))*u(4)+sin(u(7)-2*pi/3)*u(5)+sin(u(7)+2*pi/3)*u(6))');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Iq'],'Position',[825 575 1010 605], ...
    'Expr','(2/3)*(cos(u(7))*u(4)+cos(u(7)-2*pi/3)*u(5)+cos(u(7)+2*pi/3)*u(6))');
add_line(pv,'vabc_Sensor_Filter/1','DQ_Inputs/1'); add_line(pv,'iabc_Sensor_Filter/1','DQ_Inputs/2');
% Only the local reference PLL drives the GFL transformations.  No angle or
% frequency signal is imported from the BESS-GFM branch.
add_line(pv,'Reference_Project_PLL/2','DQ_Inputs/3');
for b={'Vd','Vq','Id','Iq'},add_line(pv,'DQ_Inputs/1',[b{1} '/1']);end

% P/Q references and dq current PI.
add_block('simulink/Sources/Ramp',[pv '/PV_P_Soft_Start'],'Position',[25 470 95 500], ...
    'slope','S1.pv.P_ramp_W_per_s','start','0','InitialOutput','0');
add_block('simulink/Discontinuities/Saturation',[pv '/PV_P_Base_Limit'], ...
    'Position',[120 470 200 500],'UpperLimit','S1.pv.P_initial_W','LowerLimit','0');
add_block('simulink/Sources/Step',[pv '/PV_P_Increment'],'Position',[25 515 95 545], ...
    'Time','S1.pv.P_step_time_s','Before','0', ...
    'After','S1.pv.P_final_W-S1.pv.P_initial_W');
add_block('simulink/Math Operations/Sum',[pv '/PV_P_Reference'], ...
    'Position',[225 480 255 535],'Inputs','++');
add_block('simulink/Sources/Constant',[pv '/PV_Q_Reference'],'Position',[40 560 110 590],'Value','S1.pv.Q_ref_var');
add_block('simulink/Signal Routing/Mux',[pv '/PQ_to_I_Inputs'],'Position',[150 485 155 595],'Inputs','3');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Id_Reference_Raw'],'Position',[190 500 340 535], ...
    'Expr','u(1)/(1.5*sqrt(2/3)*S1.pv.Vll_low_V)');
add_block('simulink/User-Defined Functions/Fcn',[pv '/Iq_Reference_Raw'],'Position',[190 555 340 590], ...
    'Expr','-u(2)/(1.5*sqrt(2/3)*S1.pv.Vll_low_V)');
add_block('simulink/Discontinuities/Saturation',[pv '/Id_Reference_Limit'],'Position',[370 500 450 535], ...
    'UpperLimit','S1.control.Ilimit_A','LowerLimit','-S1.control.Ilimit_A');
add_block('simulink/Discontinuities/Saturation',[pv '/Iq_Reference_Limit'],'Position',[370 555 450 590], ...
    'UpperLimit','S1.control.Ilimit_A','LowerLimit','-S1.control.Ilimit_A');
add_line(pv,'PV_P_Soft_Start/1','PV_P_Base_Limit/1');
add_line(pv,'PV_P_Base_Limit/1','PV_P_Reference/1');
add_line(pv,'PV_P_Increment/1','PV_P_Reference/2');
add_line(pv,'PV_P_Reference/1','PQ_to_I_Inputs/1'); add_line(pv,'PV_Q_Reference/1','PQ_to_I_Inputs/2');
add_line(pv,'Vd/1','PQ_to_I_Inputs/3'); add_line(pv,'PQ_to_I_Inputs/1','Id_Reference_Raw/1');
add_line(pv,'PQ_to_I_Inputs/1','Iq_Reference_Raw/1'); add_line(pv,'Id_Reference_Raw/1','Id_Reference_Limit/1');
add_line(pv,'Iq_Reference_Raw/1','Iq_Reference_Limit/1');

add_pi_axis(pv,'d',650); add_pi_axis(pv,'q',780);
add_line(pv,'Id_Reference_Limit/1','d_Error/1'); add_line(pv,'Id/1','d_Error/2');
add_line(pv,'Iq_Reference_Limit/1','q_Error/1'); add_line(pv,'Iq/1','q_Error/2');
add_block('simulink/Math Operations/Gain',[pv '/Cross_d'],'Position',[1040 640 1130 675], ...
    'Gain','-2*pi*S1.base.f_Hz*S1.filter.L1_H');
add_block('simulink/Math Operations/Gain',[pv '/Cross_q'],'Position',[1040 770 1130 805], ...
    'Gain','2*pi*S1.base.f_Hz*S1.filter.L1_H');
add_line(pv,'Iq/1','Cross_d/1'); add_line(pv,'Id/1','Cross_q/1');
add_block('simulink/Math Operations/Sum',[pv '/Vd_Command'],'Position',[1170 630 1200 700],'Inputs','++++');
add_block('simulink/Math Operations/Sum',[pv '/Vq_Command'],'Position',[1170 760 1200 830],'Inputs','++++');
add_block('simulink/Math Operations/Gain',[pv '/Vd_Line_to_Phase'], ...
    'Position',[1040 600 1130 630],'Gain','1/sqrt(3)');
add_block('simulink/Math Operations/Gain',[pv '/Vq_Line_to_Phase'], ...
    'Position',[1040 730 1130 760],'Gain','1/sqrt(3)');
add_block('simulink/Sources/Constant',[pv '/Phase_Voltage_FF'], ...
    'Position',[1060 565 1140 595],'Value','sqrt(2/3)*S1.pv.Vll_low_V');
add_block('simulink/Sources/Constant',[pv '/Phase_Q_Voltage_FF'], ...
    'Position',[1060 700 1140 725],'Value','0');
add_line(pv,'Vd/1','Vd_Line_to_Phase/1'); add_line(pv,'Vq/1','Vq_Line_to_Phase/1');
add_line(pv,'Phase_Voltage_FF/1','Vd_Command/1'); add_line(pv,'d_Kp/1','Vd_Command/2');
add_line(pv,'d_I/1','Vd_Command/3'); add_line(pv,'Cross_d/1','Vd_Command/4');
add_line(pv,'Phase_Q_Voltage_FF/1','Vq_Command/1'); add_line(pv,'q_Kp/1','Vq_Command/2');
add_line(pv,'q_I/1','Vq_Command/3'); add_line(pv,'Cross_q/1','Vq_Command/4');

% Inverse Park and modulation.
add_block('simulink/Signal Routing/Mux',[pv '/Inverse_DQ_Inputs'],'Position',[1240 625 1245 835],'Inputs','3');
add_line(pv,'Vd_Command/1','Inverse_DQ_Inputs/1'); add_line(pv,'Vq_Command/1','Inverse_DQ_Inputs/2');
add_block('simulink/Signal Attributes/Signal Specification',[pv '/PLL_Phase_Angle'], ...
    'Position',[1100 560 1190 590]);
add_line(pv,'Reference_Project_PLL/2','PLL_Phase_Angle/1');
add_line(pv,'PLL_Phase_Angle/1','Inverse_DQ_Inputs/3');
phases={'0','-2*pi/3','2*pi/3'}; names={'a','b','c'};
for k=1:3
    expr=sprintf('(2/S1.pv.Vdc_ref_V)*(u(1)*sin(u(3)%s)+u(2)*cos(u(3)%s))', ...
        signed_phase(phases{k}),signed_phase(phases{k}));
    add_block('simulink/User-Defined Functions/Fcn',[pv '/m_' names{k}], ...
        'Position',[1280 620+55*(k-1) 1450 650+55*(k-1)],'Expr',expr);
    add_block('simulink/Discontinuities/Saturation',[pv '/m_' names{k} '_Limit'], ...
        'Position',[1480 620+55*(k-1) 1560 650+55*(k-1)], ...
        'UpperLimit','S1.pv.modulation_max','LowerLimit','-S1.pv.modulation_max');
    add_line(pv,'Inverse_DQ_Inputs/1',['m_' names{k} '/1']);
    add_line(pv,['m_' names{k} '/1'],['m_' names{k} '_Limit/1']);
end
add_block('simulink/Signal Routing/Mux',[pv '/m_abc'],'Position',[1590 610 1595 775],'Inputs','3');
for k=1:3,add_line(pv,['m_' names{k} '_Limit/1'],sprintf('m_abc/%d',k));end
add_block(sps,[pv '/Modulation_to_PS'],'Position',[1630 655 1730 715],'Unit','1','FilteringAndDerivatives','zero');
add_line(pv,'m_abc/1','Modulation_to_PS/1');
connect_handle(pv,porth([pv '/Modulation_to_PS'],'RConn',1),porth([pv '/PV_Average_VSC'],'LConn',1));

% PV-local telemetry.
add_block('simulink/Sources/Clock',[pv '/Time'],'Position',[40 690 70 720]);
add_block('simulink/Signal Routing/Mux',[pv '/PV_Result_Mux'],'Position',[1770 360 1775 780],'Inputs','10');
add_block('simulink/Sinks/To Workspace',[pv '/PV_Results'],'Position',[1810 555 1910 595], ...
    'VariableName','stage1_pv_result','SaveFormat','Array','MaxDataPoints','inf');
sig={'Time/1','Ppv_to_Simulink/1','Qpv_to_Simulink/1','PV_P_Reference/1', ...
    'PLL_Phase_Error/1','Id/1','Iq/1','Id_Reference_Limit/1','Vdc_to_Simulink/1','Reference_Project_PLL/5'};
for k=1:numel(sig),add_line(pv,sig{k},sprintf('PV_Result_Mux/%d',k),'autorouting','on');end
add_line(pv,'PV_Result_Mux/1','PV_Results/1');

% Connect PV into the existing 10 kV PCC at the top level.
pvPH=get_param(pv,'PortHandles'); loadPH=get_param(loadSys,'PortHandles');
add_line(modelName,pvPH.RConn(1),loadPH.LConn(1),'autorouting','on');
set_param([modelName '/01 BESS DC Source'],'Position',[80 185 330 365]);
set_param([modelName '/02 GFM PCS and Step-up'],'Position',[400 185 670 365]);
set_param([modelName '/04 Island Load Scenario'],'Position',[1020 185 1250 365]);
set_param([modelName '/05 Supervision and Results'],'Position',[835 500 1080 625]);

anns=find_system(modelName,'FindAll','on','Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(modelName,sprintf([ ...
    'Stage 1 — BESS-GFM + PV-GFL natural AC coupling\n' ...
    'PV has an independent DC link, local SRF-PLL and dq current controller; no BESS angle signal is shared.\n' ...
    'Test: fixed 5 MW load, PV 2 -> 3 MW at 0.30 s, expected BESS approximately 3 -> 2 MW.']));
a.Position=[70 35 1250 120]; a.FontSize=15; a.FontWeight='bold';
set_param(modelName,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_bess_pv_stage1.m'));" );
set_param(modelName,'StopTime','0.8','MaxStep','1e-5','Location',[70 70 1450 900]);
set_param(modelName,'ZoomFactor','FitSystem');
save_system(modelName,modelFile);
set_param(modelName,'SimulationCommand','update');
fprintf('STAGE1_MODEL_UPDATE_OK=1\n');
save_system(modelName,modelFile);
try,print(['-s' modelName],'-dpng',pngFile);catch ME,fprintf('%s\n',ME.message);end
close_system(modelName,0);
fprintf('STAGE1_MODEL=%s\n',modelFile);

function add_pi_axis(sys,prefix,y)
add_block('simulink/Math Operations/Sum',[sys '/' prefix '_Error'], ...
    'Position',[480 y 510 y+45],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[sys '/' prefix '_Kp'], ...
    'Position',[550 y-10 630 y+20],'Gain','S1.control.current_Kp');
add_block('simulink/Math Operations/Gain',[sys '/' prefix '_Ki'], ...
    'Position',[550 y+35 630 y+65],'Gain','S1.control.current_Ki');
add_block('simulink/Continuous/Integrator',[sys '/' prefix '_I'], ...
    'Position',[670 y+35 710 y+70],'InitialCondition','0');
add_line(sys,[prefix '_Error/1'],[prefix '_Kp/1']);
add_line(sys,[prefix '_Error/1'],[prefix '_Ki/1']);
add_line(sys,[prefix '_Ki/1'],[prefix '_I/1']);
end
function s=signed_phase(p)
if strcmp(p,'0'),s='';elseif startsWith(p,'-'),s=p;else,s=['+' p];end
end
function h=porth(block,side,index)
p=get_param(block,'PortHandles');h=p.(side)(index);
end
function connectp(sys,a,sa,ia,b,sb,ib)
add_line(sys,porth([sys '/' a],sa,ia),porth([sys '/' b],sb,ib),'autorouting','on');
end
function connect_handle(sys,a,b),add_line(sys,a,b,'autorouting','on');end
function branchp(sys,a,b),add_line(sys,a,b,'autorouting','on');end
function add_pmio(sys,name,port,side,domain,pos)
add_block('built-in/PMIOPort',[sys '/' name],'Port',num2str(port),'Side',side, ...
    'ConnectionType',['Connection: ' domain],'Position',pos);
end
function h=pmio_handle(block)
p=get_param(block,'PortHandles');h=[p.LConn p.RConn];assert(numel(h)==1);
end
