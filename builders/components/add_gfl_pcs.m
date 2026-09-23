function path=add_gfl_pcs(parent,name,cfg,pos)
%ADD_GFL_PCS Build one GFL PCS from reusable control components.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[0.78,0.90,1.00]','ContentPreviewEnabled','off', ...
    'AttributesFormatString','local PLL | P/Q-to-dq | circle limit | average PCS');
add_block('simulink/Ports & Subsystems/In1',[path '/CommandBus'], ...
    'Position',[20 60 50 74],'OutDataTypeStr','Bus: ResourceCommandBus');
add_block('simulink/Ports & Subsystems/In1',[path '/PCCMeasurementBus'], ...
    'Position',[20 205 50 219],'Port','2','OutDataTypeStr','Bus: PCCMeasurementBus');
add_block('simulink/Signal Routing/Bus Selector',[path '/Command Selector'], ...
    'Position',[75 35 80 155],'OutputSignals','P_ref_W,Q_ref_var,enable,mode');
add_block('simulink/Signal Routing/Bus Selector',[path '/PCC Selector'], ...
    'Position',[75 175 80 310],'OutputSignals','vabc_V,iabc_A,Vll_rms_V');
add_gfl_control(path,cfg);
converter=add_average_current_converter(path,'05 Average Converter',cfg,[875 250 1080 355]);
v2_add_pmio(path,'AC_690V',1,'Right','foundation.electrical.three_phase',[1185 290 1215 320]);
add_line(path,'CommandBus/1','Command Selector/1');add_line(path,'PCCMeasurementBus/1','PCC Selector/1');
add_line(path,'PCC Selector/1','01 Local PLL/1','autorouting','on');
add_block('simulink/User-Defined Functions/Fcn',[path '/Converter Voltage Peak'], ...
    'Position',[245 175 405 210], ...
    'Expr','sqrt((2/3)*(u(1)^2+u(2)^2+u(3)^2))');
add_line(path,'05 Average Converter/2','Converter Voltage Peak/1','autorouting','on');
add_line(path,'Command Selector/1','02 P-Q to dq Reference/1','autorouting','on');
add_line(path,'Command Selector/2','02 P-Q to dq Reference/2','autorouting','on');
add_line(path,'Converter Voltage Peak/1','02 P-Q to dq Reference/3','autorouting','on');
add_line(path,'02 P-Q to dq Reference/1','03 Current Limiter/1');
add_line(path,'02 P-Q to dq Reference/2','03 Current Limiter/2');
add_line(path,'Command Selector/3','03 Current Limiter/3','autorouting','on');
add_line(path,'03 Current Limiter/1','04 Current Controller/1');
add_line(path,'03 Current Limiter/2','04 Current Controller/2');
add_line(path,'01 Local PLL/1','04 Current Controller/3','autorouting','on');
add_line(path,'04 Current Controller/1','05 Average Converter/1','autorouting','on');
add_line(path,v2_physical_port(converter),v2_physical_port([path '/AC_690V']));

add_block('simulink/Math Operations/Gain',[path '/omega to Hz'], ...
    'Position',[365 180 445 210],'Gain','1/(2*pi)');
add_line(path,'01 Local PLL/2','omega to Hz/1','autorouting','on');
add_block('simulink/User-Defined Functions/Fcn',[path '/Actual Current Magnitude'], ...
    'Position',[250 245 410 275],'Expr','sqrt((2/3)*(u(1)^2+u(2)^2+u(3)^2))');
add_line(path,'05 Average Converter/1','Actual Current Magnitude/1','autorouting','on');
add_block('simulink/Sources/Constant',[path '/Healthy'], ...
    'Position',[520 350 585 380],'Value','1');
add_block('simulink/Math Operations/Gain',[path '/Control Mode Pass'], ...
    'Position',[520 305 585 335],'Gain','1');
add_line(path,'Command Selector/4','Control Mode Pass/1','autorouting','on');
add_block('simulink/Signal Routing/Bus Creator',[path '/PCS Status'], ...
    'Position',[1115 380 1120 615],'Inputs','10','OutDataTypeStr','Bus: PCSStatusBus');
signals={'01 Local PLL/1','omega to Hz/1','01 Local PLL/3', ...
    '03 Current Limiter/1','03 Current Limiter/2','Actual Current Magnitude/1', ...
    '03 Current Limiter/3','03 Current Limiter/4','Control Mode Pass/1','Healthy/1'};
fields={'theta_rad','frequency_Hz','phase_error_rad','Id_ref_Apk','Iq_ref_Apk', ...
    'Iactual_Apk','current_limit_factor','limit_active','control_mode','healthy'};
for k=1:numel(signals),v2_named_line(path,signals{k},sprintf('PCS Status/%d',k),fields{k});end
add_block('simulink/Ports & Subsystems/Out1',[path '/PCSStatusBus'], ...
    'Position',[1185 485 1215 499],'Port','1','OutDataTypeStr','Bus: PCSStatusBus');
add_line(path,'PCS Status/1','PCSStatusBus/1');
v2_route_level(path);
end
