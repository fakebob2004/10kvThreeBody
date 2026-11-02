function s=add_pv_dynamic_pcs(parent,name,cfg,pos)
%ADD_PV_DYNAMIC_PCS Independent physical DC/AC averaged VSC and local controls.
s=pv_dyn_helpers('sub',parent,name,pos);d=[cfg '.dynamic'];
B=@(n,l,p,varargin)pv_dyn_helpers('block',s,n,l,p,varargin{:});
L=@(a,b)pv_dyn_helpers('line',s,a,b);
W=@(a,as,ai,b,bs,bi)pv_dyn_helpers('wire',s,a,as,ai,b,bs,bi);
pv_dyn_helpers('port',s,'Command',1,'In',[15 310 45 324]);
pv_dyn_helpers('port',s,'DC Telemetry',2,'In',[15 370 45 384]);
pv_dyn_helpers('port',s,'PCCMeasurementBus',3,'In',[15 430 45 444]);
pv_dyn_helpers('port',s,'Telemetry',1,'Out',[1160 430 1190 444]);
v2_add_pmio(s,'DC_Positive',1,'Left','foundation.electrical.electrical',[20 65 50 95]);
v2_add_pmio(s,'DC_Negative',2,'Left','foundation.electrical.electrical',[20 155 50 185]);
v2_add_pmio(s,'AC_690V',3,'Right','foundation.electrical.three_phase',[1160 100 1190 130]);
B('Average VSC',sprintf('ee_lib/Semiconductors &\nConverters/Converters/Average-Value\nVoltage Source\nConverter\n(Three-Phase)'), ...
 [590 65 730 170],'FRated',[cfg '.rating.f_Hz'],'Pfixed','1','Vdc_nom',[d '.Vdc_ref_V']);
B('VSC DC Current','fl_lib/Electrical/Electrical Sensors/Current Sensor',[240 65 280 105]);
W('DC_Positive','LConn',1,'VSC DC Current','LConn',1);
W('VSC DC Current','RConn',2,'Average VSC','RConn',1);W('DC_Negative','LConn',1,'Average VSC','RConn',2);
B('Converter VI',sprintf('ee_lib/Sensors &\nTransducers/Current and Voltage\nSensor (Three-Phase)'), ...
 [830 80 930 160],'vMeasurementType','ee.enum.vmeasurement.lg');
W('Average VSC','LConn',2,'Converter VI','LConn',1);W('Converter VI','RConn',3,'AC_690V','RConn',1);
pv_dyn_helpers('pss',s,'vabc SI','V',[780 220 880 255]);
pv_dyn_helpers('pss',s,'iabc SI','A',[780 280 880 315]);
W('Converter VI','RConn',1,'vabc SI','LConn',1);W('Converter VI','RConn',2,'iabc SI','LConn',1);
add_local_pll(s,'01 Local PLL',cfg,[150 220 330 285]);
B('Grid Selector','simulink/Signal Routing/Bus Selector',[70 430 75 510],'OutputSignals','vabc_V');
L('PCCMeasurementBus/1','Grid Selector/1');
B('Grid Phase Voltage','simulink/Math Operations/Gain',[140 450 340 495], ...
 'Gain',['[1 -1 0;0 1 -1;-1 0 1]*(' cfg '.rating.V_ac_low_V/' cfg '.rating.V_pcc_V)/3'], ...
 'Multiplication','Matrix(u*K)');
L('Grid Selector/1','Grid Phase Voltage/1');L('Grid Phase Voltage/1','01 Local PLL/1');
B('Converter Voltage Record','simulink/Sinks/To Workspace',[940 240 1110 275], ...
 'VariableName','pv_converter_vabc','SaveFormat','Timeseries','MaxDataPoints','inf');
L('vabc SI/1','Converter Voltage Record/1');
B('DC Values','simulink/Signal Routing/Demux',[80 350 85 500],'Outputs','6');L('DC Telemetry/1','DC Values/1');
for k=4:6
 B(sprintf('Unused DC Value %d',k),'simulink/Sinks/Terminator',[130 510+40*k 150 530+40*k]);
 L(sprintf('DC Values/%d',k),sprintf('Unused DC Value %d/1',k));
end
B('PV Power','simulink/Math Operations/Product',[140 350 175 400]);
L('DC Values/1','PV Power/1');L('DC Values/2','PV Power/2');
add_pv_dynamic_current_control(s,'02 DC Voltage and dq Current',cfg,[370 300 690 460]);
L('Grid Phase Voltage/1','02 DC Voltage and dq Current/1');L('iabc SI/1','02 DC Voltage and dq Current/2');
L('01 Local PLL/1','02 DC Voltage and dq Current/3');L('DC Values/3','02 DC Voltage and dq Current/4');
L('PV Power/1','02 DC Voltage and dq Current/5');L('Command/1','02 DC Voltage and dq Current/6');
pv_dyn_helpers('sps',s,'Modulation PS','1',[430 170 540 205]);
B('Modulation Sample Delay','simulink/Discrete/Unit Delay',[350 190 420 220], ...
 'SampleTime',[d '.sample_s'],'InitialCondition','[0;-0.39;0.39]');
L('02 DC Voltage and dq Current/1','Modulation Sample Delay/1');
L('Modulation Sample Delay/1','Modulation PS/1');W('Modulation PS','RConn',1,'Average VSC','LConn',1);
B('PCS Telemetry','simulink/Signal Routing/Mux',[1050 320 1055 550],'Inputs','5');
src={'02 DC Voltage and dq Current/2','01 Local PLL/1','01 Local PLL/2','01 Local PLL/3','02 DC Voltage and dq Current/1'};
for k=1:5,L(src{k},sprintf('PCS Telemetry/%d',k));end
L('PCS Telemetry/1','Telemetry/1');
pv_dyn_helpers('pss',s,'DC Current SI','A',[230 520 340 555]);
W('VSC DC Current','RConn',1,'DC Current SI','LConn',1);
B('DC Current Record','simulink/Sinks/To Workspace',[390 520 540 555], ...
 'VariableName','pv_vsc_dc_current','SaveFormat','Timeseries','MaxDataPoints','inf');L('DC Current SI/1','DC Current Record/1');
end
