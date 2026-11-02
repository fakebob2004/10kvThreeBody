function s=add_pv_physical_dc(parent,name,cfg,pos)
%ADD_PV_PHYSICAL_DC Solar-cell array, P&O/curtailment, averaged Boost and Cdc.
s=pv_dyn_helpers('sub',parent,name,pos); d=[cfg '.dynamic'];
B=@(n,l,p,varargin)pv_dyn_helpers('block',s,n,l,p,varargin{:});
L=@(a,b)pv_dyn_helpers('line',s,a,b);
W=@(a,as,ai,b,bs,bi)pv_dyn_helpers('wire',s,a,as,ai,b,bs,bi);
pv_dyn_helpers('port',s,'Command',1,'In',[20 360 50 374]);
pv_dyn_helpers('port',s,'Telemetry',1,'Out',[1220 530 1250 544]);
v2_add_pmio(s,'DC_Positive',1,'Right','foundation.electrical.electrical',[1220 80 1250 110]);
v2_add_pmio(s,'DC_Negative',2,'Right','foundation.electrical.electrical',[1220 180 1250 210]);
B('PV Array','ee_lib/Sources/Solar Cell',[150 65 250 155], ...
 'N_series',[d '.Nseries'],'N_parallel',[d '.Nparallel'],'Isc',[d '.Isc_cell_A'], ...
 'Voc',[d '.Voc_cell_V'],'TFIXED',[d '.temperature_degC']);
B('PV Input Capacitor','fl_lib/Electrical/Electrical Elements/Capacitor',[330 160 365 220], ...
 'c',[d '.Cpv_F'],'vc_specify','on','vc_priority','High','vc',[d '.Vmp_initial_V']);
B('PV Current','fl_lib/Electrical/Electrical Sensors/Current Sensor',[290 65 330 100]);
B('Boost Output Current','fl_lib/Electrical/Electrical Sensors/Current Sensor',[715 65 755 100]);
B('PV Voltage','fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[270 170 305 225]);
B('Average Boost',sprintf('ee_lib/Semiconductors &\nConverters/Converters/Boost Converter'), ...
 [550 65 685 175],'device_type','ee.enum.converters.switchingdevice.averaged', ...
 'Lf',[d '.Lboost_H'],'Rl',[d '.Rboost_ohm'],'Cf','1e-6','Rf','0.001', ...
 'vc_specify','on','vc_priority','High','vc',[d '.Vdc_ref_V'], ...
 'iL_specify','off');
B('DC Link Capacitor','fl_lib/Electrical/Electrical Elements/Capacitor',[800 100 840 165], ...
 'c',[d '.Cdc_F'],'vc_specify','on','vc_priority','High','vc',[d '.Vdc_ref_V']);
B('DC Link Voltage','fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[910 105 950 165]);
B('DC Ground','fl_lib/Electrical/Electrical Elements/Electrical Reference',[770 235 805 265]);
B('Irradiance','simulink/Sources/Constant',[20 30 100 60],'Value',[d '.irradiance_Wpm2']);
pv_dyn_helpers('sps',s,'Irradiance PS','W/m^2',[20 90 115 125]); L('Irradiance/1','Irradiance PS/1');
W('Irradiance PS','RConn',1,'PV Array','LConn',1);
W('PV Array','LConn',2,'PV Current','LConn',1);
W('PV Current','RConn',2,'Average Boost','LConn',2);
W('PV Current','RConn',2,'PV Input Capacitor','LConn',1);
W('PV Current','RConn',2,'PV Voltage','LConn',1);
W('PV Array','RConn',1,'Average Boost','LConn',3);
W('PV Array','RConn',1,'PV Voltage','RConn',2);
W('PV Array','RConn',1,'PV Input Capacitor','RConn',1);
W('Average Boost','RConn',1,'Boost Output Current','LConn',1);
W('Boost Output Current','RConn',2,'DC Link Capacitor','LConn',1);
W('Average Boost','RConn',2,'DC Link Capacitor','RConn',1);
W('Average Boost','RConn',2,'DC Ground','LConn',1);
W('DC Link Capacitor','LConn',1,'DC Link Voltage','LConn',1);
W('DC Link Capacitor','RConn',1,'DC Link Voltage','RConn',2);
W('DC Link Capacitor','LConn',1,'DC_Positive','RConn',1);
W('DC Link Capacitor','RConn',1,'DC_Negative','RConn',1);
sn={'PV Voltage','PV Current','DC Link Voltage'}; units={'V','A','V'};
for k=1:3
 pv_dyn_helpers('pss',s,[sn{k} ' SI'],units{k},[1000 270+55*k 1100 305+55*k]);
 side='RConn';idx=1;
 W(sn{k},side,idx,[sn{k} ' SI'],'LConn',1);
end
add_pv_mppt_boost_control(s,'MPPT and Curtailment',cfg,[450 350 850 520]);
L('PV Voltage SI/1','MPPT and Curtailment/1');L('PV Current SI/1','MPPT and Curtailment/2');
L('DC Link Voltage SI/1','MPPT and Curtailment/3');L('Command/1','MPPT and Curtailment/4');
pv_dyn_helpers('sps',s,'Duty PS','1',[410 220 505 255]);
B('Duty Sample Delay','simulink/Discrete/Unit Delay',[360 250 430 280], ...
 'SampleTime',[d '.sample_s'],'InitialCondition','0');
L('MPPT and Curtailment/1','Duty Sample Delay/1');L('Duty Sample Delay/1','Duty PS/1');W('Duty PS','RConn',1,'Average Boost','LConn',1);
B('Telemetry Mux','simulink/Signal Routing/Mux',[1150 335 1155 585],'Inputs','6');
src={'PV Voltage SI/1','PV Current SI/1','DC Link Voltage SI/1', ...
 'MPPT and Curtailment/1','MPPT and Curtailment/2','MPPT and Curtailment/3'};
for k=1:6,L(src{k},sprintf('Telemetry Mux/%d',k));end
L('Telemetry Mux/1','Telemetry/1');
pv_dyn_helpers('pss',s,'Boost Current SI','A',[790 590 900 625]);
W('Boost Output Current','RConn',1,'Boost Current SI','LConn',1);
B('Boost Current Record','simulink/Sinks/To Workspace',[950 590 1100 625], ...
 'VariableName','pv_boost_current','SaveFormat','Timeseries','MaxDataPoints','inf');
L('Boost Current SI/1','Boost Current Record/1');
end
