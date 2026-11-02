function s=add_pv_mppt_boost_control(parent,name,cfg,pos)
%ADD_PV_MPPT_BOOST_CONTROL Sampled P&O plus high-voltage-branch curtailment.
s=pv_dyn_helpers('sub',parent,name,pos);d=[cfg '.dynamic'];
B=@(n,l,p,varargin)pv_dyn_helpers('block',s,n,l,p,varargin{:});
L=@(a,b)pv_dyn_helpers('line',s,a,b);
names={'Vpv','Ipv','Vdc','Command'};
for k=1:4,pv_dyn_helpers('port',s,names{k},k,'In',[15 40+65*k 45 54+65*k]);end
B('Command Selector','simulink/Signal Routing/Bus Selector',[70 320 75 420], ...
 'OutputSignals','P_ref_W,enable');
L('Command/1','Command Selector/1');
B('Dispatch Limit','simulink/Discontinuities/Saturation',[110 320 200 355], ...
 'LowerLimit','0','UpperLimit',[cfg '.rating.P_W']);
B('Enabled Dispatch','simulink/Math Operations/Product',[240 320 275 370]);
L('Command Selector/1','Dispatch Limit/1');L('Dispatch Limit/1','Enabled Dispatch/1');
L('Command Selector/2','Enabled Dispatch/2');
B('PV Power','simulink/Math Operations/Product',[85 100 120 150]);
L('Vpv/1','PV Power/1');L('Ipv/1','PV Power/2');
B('Sample Voltage','simulink/Discrete/Zero-Order Hold',[150 30 235 60],'SampleTime',[d '.mppt_period_s']);
B('Sample Power','simulink/Discrete/Zero-Order Hold',[150 100 235 130],'SampleTime',[d '.mppt_period_s']);
L('Vpv/1','Sample Voltage/1');L('PV Power/1','Sample Power/1');
B('Previous Voltage','simulink/Discrete/Unit Delay',[270 30 345 60], ...
 'SampleTime',[d '.mppt_period_s'],'InitialCondition',[d '.Vmp_initial_V']);
B('Previous Power','simulink/Discrete/Unit Delay',[270 100 345 130], ...
 'SampleTime',[d '.mppt_period_s'],'InitialCondition','0');
L('Sample Voltage/1','Previous Voltage/1');L('Sample Power/1','Previous Power/1');
B('Delta Voltage','simulink/Math Operations/Sum',[380 25 410 70],'Inputs','+-');
B('Delta Power','simulink/Math Operations/Sum',[380 100 410 145],'Inputs','+-');
L('Sample Voltage/1','Delta Voltage/1');L('Previous Voltage/1','Delta Voltage/2');
L('Sample Power/1','Delta Power/1');L('Previous Power/1','Delta Power/2');
B('Gradient Pair','simulink/Signal Routing/Mux',[445 30 450 150],'Inputs','2');
L('Delta Voltage/1','Gradient Pair/1');L('Delta Power/1','Gradient Pair/2');
B('PO Direction','simulink/User-Defined Functions/Fcn',[490 60 620 100], ...
 'Expr','2*(u(1)*u(2)>=0)-1');L('Gradient Pair/1','PO Direction/1');
B('PO Step','simulink/Math Operations/Gain',[660 60 730 100],'Gain',[d '.mppt_step_V']);
L('PO Direction/1','PO Step/1');
B('MPPT Voltage','simulink/Discrete/Discrete-Time Integrator',[770 60 850 100], ...
 'SampleTime',[d '.mppt_period_s'],'gainval','1', ...
 'IntegratorMethod','Accumulation: Forward Euler','InitialCondition',[d '.Vmp_initial_V'], ...
 'LimitOutput','on','LowerSaturationLimit',[d '.Vpv_min_V'], ...
 'UpperSaturationLimit','970');L('PO Step/1','MPPT Voltage/1');
B('Curtailment Error','simulink/Math Operations/Sum',[330 250 360 295],'Inputs','+-');
L('PV Power/1','Curtailment Error/1');L('Enabled Dispatch/1','Curtailment Error/2');
pv_dyn_helpers('pi',s,'Curtailment PI',[d '.curtail_Kp_VpW'],[d '.curtail_Ki_VpWs'],'30', ...
 '0','400',[425 220 640 290],['min(180,' d '.Vpv_max_V-' d '.Vmp_initial_V)']);L('Curtailment Error/1','Curtailment PI/1');
B('Voltage Target','simulink/Math Operations/Sum',[890 160 920 205],'Inputs','++');
L('MPPT Voltage/1','Voltage Target/1');L('Curtailment PI/1','Voltage Target/2');
B('Overvoltage Inputs','simulink/Signal Routing/Mux',[940 160 945 240],'Inputs','2');
L('Voltage Target/1','Overvoltage Inputs/1');L('Vdc/1','Overvoltage Inputs/2');
B('DC Overvoltage Curtailment','simulink/User-Defined Functions/Fcn',[965 165 1190 205], ...
 'Expr',['u(1)+2*max(0,u(2)-' d '.dc_overvoltage_V)']);
L('Overvoltage Inputs/1','DC Overvoltage Curtailment/1');
B('PV Target Limit','simulink/Discontinuities/Saturation',[955 165 1050 200], ...
 'LowerLimit',[d '.Vpv_min_V'],'UpperLimit',[d '.Vpv_max_V']);
L('DC Overvoltage Curtailment/1','PV Target Limit/1');
B('Boost Voltage Error','simulink/Math Operations/Sum',[890 270 920 315],'Inputs','+-');
L('Vpv/1','Boost Voltage Error/1');L('PV Target Limit/1','Boost Voltage Error/2');
pv_dyn_helpers('pi',s,'Boost Voltage PI',[d '.boost_Kp'],[d '.boost_Ki'],[d '.boost_Kaw'], ...
 [d '.duty_min'],[d '.duty_max'],[955 260 1165 330],'0.4');
L('Boost Voltage Error/1','Boost Voltage PI/1');
B('Enable Boost','simulink/Math Operations/Product',[1170 270 1200 310]);
L('Boost Voltage PI/1','Enable Boost/1');L('Command Selector/2','Enable Boost/2');
pv_dyn_helpers('port',s,'Duty',1,'Out',[1250 280 1280 294]);L('Enable Boost/1','Duty/1');
pv_dyn_helpers('port',s,'Vmp',2,'Out',[1210 80 1240 94]);L('MPPT Voltage/1','Vmp/1');
pv_dyn_helpers('port',s,'Vpv_target',3,'Out',[1210 180 1240 194]);L('PV Target Limit/1','Vpv_target/1');
end
