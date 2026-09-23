function path=add_pcc_measurement(parent,name,cfg,pos)
%ADD_PCC_MEASUREMENT Build resource-local PCC V/I/P/Q sensing and typed bus.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[0.93,0.97,1.00]','ContentPreviewEnabled','off');
v2_add_pmio(path,'From Transformer',1,'Left','foundation.electrical.three_phase',[20 80 50 110]);
v2_add_pmio(path,'PCC_10kV',2,'Right','foundation.electrical.three_phase',[530 80 560 110]);
iv=sprintf('ee_lib/Sensors &\nTransducers/Current and Voltage\nSensor (Three-Phase)');
pq=sprintf('ee_lib/Sensors &\nTransducers/Power Sensor\n(Three-Phase)');
pss=sprintf('nesl_utility/PS-Simulink\nConverter');
add_block(iv,[path '/PCC VI Sensor'],'Position',[95 45 180 135], ...
    'vMeasurementType','ee.enum.vmeasurement.ll');
add_block(pq,[path '/PCC Power Sensor'],'Position',[235 55 320 125]);
add_line(path,v2_physical_port([path '/From Transformer']),v2_port([path '/PCC VI Sensor'],'LConn',1));
add_line(path,v2_port([path '/PCC VI Sensor'],'RConn',3),v2_port([path '/PCC Power Sensor'],'LConn',1));
add_line(path,v2_port([path '/PCC Power Sensor'],'RConn',1),v2_physical_port([path '/PCC_10kV']));
conv={'vabc','iabc','P','Q'};units={'V','A','W','W'};ys=[180 240 300 360];
for k=1:4,add_block(pss,[path '/' conv{k} ' to Simulink'], ...
        'Position',[120 ys(k) 225 ys(k)+35],'Unit',units{k});end
add_line(path,v2_port([path '/PCC VI Sensor'],'RConn',1),v2_port([path '/vabc to Simulink'],'LConn',1));
add_line(path,v2_port([path '/PCC VI Sensor'],'RConn',2),v2_port([path '/iabc to Simulink'],'LConn',1));
add_line(path,v2_port([path '/PCC Power Sensor'],'LConn',2),v2_port([path '/P to Simulink'],'LConn',1));
add_line(path,v2_port([path '/PCC Power Sensor'],'LConn',3),v2_port([path '/Q to Simulink'],'LConn',1));
add_block('simulink/User-Defined Functions/Fcn',[path '/Vll RMS'], ...
    'Position',[285 180 410 215],'Expr','sqrt((u(1)^2+u(2)^2+u(3)^2)/3)');
add_line(path,'vabc to Simulink/1','Vll RMS/1');
token=lower(char(extractAfter(string(cfg),'.')));
add_block('simulink/Sinks/To Workspace',[path '/Local PCC Voltage Record'], ...
    'Position',[285 225 420 255],'VariableName',[token '_v2_pcc_vabc'], ...
    'SaveFormat','Array','MaxDataPoints','inf');
add_line(path,'vabc to Simulink/1','Local PCC Voltage Record/1','autorouting','on');
add_block('simulink/Sources/Constant',[path '/Nominal Frequency'], ...
    'Position',[290 420 405 450],'Value',[cfg '.rating.f_Hz']);
add_block('simulink/Signal Routing/Bus Creator',[path '/PCC Measurement'], ...
    'Position',[445 175 450 455],'Inputs','6','OutDataTypeStr','Bus: PCCMeasurementBus');
s={'vabc to Simulink/1','iabc to Simulink/1','P to Simulink/1','Q to Simulink/1','Vll RMS/1','Nominal Frequency/1'};
fields={'vabc_V','iabc_A','P_W','Q_var','Vll_rms_V','frequency_Hz'};
for k=1:6,v2_named_line(path,s{k},sprintf('PCC Measurement/%d',k),fields{k});end
add_block('simulink/Ports & Subsystems/Out1',[path '/PCCMeasurementBus'], ...
    'Position',[530 300 560 314],'Port','1','OutDataTypeStr','Bus: PCCMeasurementBus');
add_line(path,'PCC Measurement/1','PCCMeasurementBus/1');v2_route_level(path);
end
