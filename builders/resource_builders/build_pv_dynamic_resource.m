function s=build_pv_dynamic_resource(parent,name,cfg,pos)
%BUILD_PV_DYNAMIC_RESOURCE Optional PV-only physical implementation.
s=pv_dyn_helpers('sub',parent,name,pos);
pv_dyn_helpers('port',s,'ResourceCommandBus',1,'In',[15 340 45 354]);
pv_dyn_helpers('port',s,'ResourceStatusBus',1,'Out',[1190 430 1220 444]);
set_param([s '/ResourceStatusBus'],'OutDataTypeStr','Bus: ResourceStatusBus');
v2_add_pmio(s,'PCC_10kV',1,'Right','foundation.electrical.three_phase',[1190 140 1220 170]);
add_pv_physical_dc(s,'01 PV Source and DC Side',cfg,[110 90 350 270]);
add_pv_dynamic_pcs(s,'02 PCS',cfg,[455 90 705 270]);
add_ac_interface(s,'03 AC Interface',cfg,[810 90 1090 270]);
L=@(a,b)pv_dyn_helpers('line',s,a,b);
W=@(a,as,ai,b,bs,bi)pv_dyn_helpers('wire',s,a,as,ai,b,bs,bi);
L('ResourceCommandBus/1','01 PV Source and DC Side/1');L('ResourceCommandBus/1','02 PCS/1');
L('01 PV Source and DC Side/1','02 PCS/2');
L('03 AC Interface/1','02 PCS/3');
W('01 PV Source and DC Side','RConn',1,'02 PCS','LConn',1);
W('01 PV Source and DC Side','RConn',2,'02 PCS','LConn',2);
W('02 PCS','RConn',1,'03 AC Interface','LConn',1);
W('03 AC Interface','RConn',1,'PCC_10kV','RConn',1);
resource=s;s=pv_dyn_helpers('sub',resource,'Status Interface',[810 360 1090 490]);
pv_dyn_helpers('port',s,'Source',1,'In',[15 80 45 94]);
pv_dyn_helpers('port',s,'PCS',2,'In',[15 140 45 154]);
pv_dyn_helpers('port',s,'PCC',3,'In',[15 200 45 214]);
pv_dyn_helpers('port',s,'ResourceCommandBus',4,'In',[15 260 45 274]);
pv_dyn_helpers('port',s,'ResourceStatusBus',1,'Out',[1450 650 1480 664]);
set_param([s '/ResourceCommandBus'],'OutDataTypeStr','Bus: ResourceCommandBus');
set_param([s '/PCC'],'OutDataTypeStr','Bus: PCCMeasurementBus');
set_param([s '/ResourceStatusBus'],'OutDataTypeStr','Bus: ResourceStatusBus');
L=@(a,b)pv_dyn_helpers('line',s,a,b);
pv_dyn_helpers('block',s,'Telemetry Mux','simulink/Signal Routing/Mux',[1115 350 1120 510],'Inputs','3');
L('Source/1','Telemetry Mux/1');L('PCS/1','Telemetry Mux/2');
% The public resource bus remains unchanged; waveform recorder uses local data.
pv_dyn_helpers('block',s,'PCC Selector','simulink/Signal Routing/Bus Selector',[840 350 845 500], ...
 'OutputSignals','P_W,Q_var,Vll_rms_V');
L('PCC/1','PCC Selector/1');
pv_dyn_helpers('block',s,'PCC Vector','simulink/Signal Routing/Mux',[990 360 995 480],'Inputs','3');
for k=1:3,L(sprintf('PCC Selector/%d',k),sprintf('PCC Vector/%d',k));end
L('PCC Vector/1','Telemetry Mux/3');
B=@(n,l,p,varargin)pv_dyn_helpers('block',s,n,l,p,varargin{:});
B('Local Dynamic Record','simulink/Sinks/To Workspace',[1180 550 1350 590], ...
 'VariableName','pv_dynamic','SaveFormat','Timeseries','MaxDataPoints','inf');
L('Telemetry Mux/1','Local Dynamic Record/1');
B('Source Values','simulink/Signal Routing/Demux',[440 550 445 760],'Outputs','6');
L('Source/1','Source Values/1');
B('PCS Values','simulink/Signal Routing/Demux',[740 550 745 850],'Outputs','[9 1 1 1 3]');
L('PCS/1','PCS Values/1');
B('Frequency Hz','simulink/Math Operations/Gain',[810 600 910 635],'Gain','1/(2*pi)');
L('PCS Values/3','Frequency Hz/1');
B('Available Power','simulink/Sources/Constant',[460 820 620 855], ...
 'Value',[cfg '.rating.P_W*' cfg '.dynamic.irradiance_Wpm2/1000']);
B('Headroom Inputs','simulink/Signal Routing/Mux',[950 740 955 820],'Inputs','2');
L('Available Power/1','Headroom Inputs/1');L('PCC Selector/1','Headroom Inputs/2');
B('Headroom','simulink/User-Defined Functions/Fcn',[990 750 1140 790],'Expr','max(0,u(1)-u(2))');
L('Headroom Inputs/1','Headroom/1');
B('Control Values','simulink/Signal Routing/Demux',[810 860 815 1100],'Outputs','9');
L('PCS Values/1','Control Values/1');
for k=1:8
 n=sprintf('Unused Control Value %d',k);B(n,'simulink/Sinks/Terminator',[850 1120+30*k 870 1140+30*k]);L(sprintf('Control Values/%d',k),[n '/1']);
end
B('Energy Inputs','simulink/User-Defined Functions/Fcn',[500 910 650 945], ...
 'Expr',['(u/' cfg '.dynamic.Vdc_ref_V)^2']);L('Source Values/3','Energy Inputs/1');
B('Command Status','simulink/Signal Routing/Bus Selector',[810 920 815 955],'OutputSignals','mode');
L('ResourceCommandBus/1','Command Status/1');
B('Healthy','simulink/User-Defined Functions/Fcn',[1010 860 1150 900], ...
 'Expr',['(u>' cfg '.dynamic.dc_undervoltage_V)*(u<' cfg '.dynamic.dc_overvoltage_V)']);
L('Source Values/3','Healthy/1');
B('Resource Status','simulink/Signal Routing/Bus Creator',[1220 650 1225 1000], ...
 'Inputs','11','OutDataTypeStr','Bus: ResourceStatusBus');
sig={'PCC Selector/1','PCC Selector/2','PCC Selector/3','Frequency Hz/1', ...
 'Available Power/1','Headroom/1','Control Values/9','Energy Inputs/1','Source Values/3','Command Status/1','Healthy/1'};
fields={'P_W','Q_var','Vpcc_V','frequency_Hz','available_power_W', ...
 'power_headroom_W','current_limit_factor','energy_state_pu','Vdc_V','control_mode','healthy'};
for k=1:11
 n=['Status ' fields{k}];B(n,'simulink/Math Operations/Gain',[1080 1030+45*k 1180 1060+45*k],'Gain','1');
 L(sig{k},[n '/1']);v2_named_line(s,[n '/1'],sprintf('Resource Status/%d',k),fields{k});
end
L('Resource Status/1','ResourceStatusBus/1');
% Deliberately terminate local values not exported in the stable public bus.
for k=[1 2 4 5 6]
 n=sprintf('Source Diagnostic %d',k);B(n,'simulink/Sinks/Terminator',[680 980+30*k 700 1000+30*k]);L(sprintf('Source Values/%d',k),[n '/1']);
end
for k=[2 4 5]
 n=sprintf('PCS Diagnostic %d',k);B(n,'simulink/Sinks/Terminator',[740 980+30*k 760 1000+30*k]);L(sprintf('PCS Values/%d',k),[n '/1']);
end
pv_dyn_helpers('line',resource,'01 PV Source and DC Side/1','Status Interface/1');
pv_dyn_helpers('line',resource,'02 PCS/1','Status Interface/2');
pv_dyn_helpers('line',resource,'03 AC Interface/1','Status Interface/3');
pv_dyn_helpers('line',resource,'ResourceCommandBus/1','Status Interface/4');
pv_dyn_helpers('line',resource,'Status Interface/1','ResourceStatusBus/1');
s=resource;
end
