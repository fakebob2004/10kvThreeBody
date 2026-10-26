function path=add_gfm_pcs(parent,name,cfg,pos)
%ADD_GFM_PCS Build a replaceable-strategy GFM PCS with explicit VI boundary.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[0.78,0.90,1.00]','ContentPreviewEnabled','off', ...
    'AttributesFormatString','strategy slot -> VI policy/interface -> common protection -> average voltage source');
add_block('simulink/Ports & Subsystems/In1',[path '/CommandBus'], ...
    'Position',[20 55 50 69],'OutDataTypeStr','Bus: ResourceCommandBus');
add_block('simulink/Ports & Subsystems/In1',[path '/PCCMeasurementBus'], ...
    'Position',[20 175 50 189],'Port','2','OutDataTypeStr','Bus: PCCMeasurementBus');
add_block('simulink/Ports & Subsystems/In1',[path '/BESSStatusBus'], ...
    'Position',[20 295 50 309],'Port','3','OutDataTypeStr','Bus: BESSStatusBus');

strategy=evalin('base',[cfg '.control.strategy']);
assert(any(strcmpi(strategy,{'droop','dvoc'})),'Unsupported GFM strategy: %s',strategy);
if strcmpi(strategy,'dvoc')
    add_gfm_dvoc_strategy(path,'01 GFM Strategy',cfg,[120 30 330 125]);
    add_block('simulink/Ports & Subsystems/In1',[path '/LocalFilterMeasurements'], ...
        'Position',[20 400 50 414],'Port','4');
else
    add_gfm_droop_strategy(path,'01 GFM Strategy',cfg,[120 30 330 125]);
end
add_static_virtual_impedance_policy(path,'02 Virtual Impedance Policy',cfg,[390 30 590 125]);
add_virtual_impedance_interface(path,'03 Virtual Impedance Interface',cfg,[650 30 880 145]);
add_gfm_common_protection(path,'04 Common Protection and Limiter',cfg,[930 30 1160 145]);
converter=add_average_voltage_converter(path,'05 Average Voltage Converter',cfg,[1210 30 1430 145]);
if strcmpi(strategy,'dvoc')
    add_line(path,'05 Average Voltage Converter/1','01 GFM Strategy/3','autorouting','on');
    add_line(path,'LocalFilterMeasurements/1','01 GFM Strategy/4','autorouting','on');
end
v2_add_pmio(path,'AC_690V',1,'Right','foundation.electrical.three_phase',[1500 75 1530 105]);

add_line(path,'CommandBus/1','01 GFM Strategy/1','autorouting','on');
add_line(path,'PCCMeasurementBus/1','01 GFM Strategy/2','autorouting','on');
add_line(path,'PCCMeasurementBus/1','02 Virtual Impedance Policy/1','autorouting','on');
add_line(path,'05 Average Voltage Converter/1','02 Virtual Impedance Policy/2','autorouting','on');
add_line(path,'01 GFM Strategy/1','03 Virtual Impedance Interface/1','autorouting','on');
add_line(path,'05 Average Voltage Converter/1','03 Virtual Impedance Interface/2','autorouting','on');
add_line(path,'02 Virtual Impedance Policy/1','03 Virtual Impedance Interface/3','autorouting','on');
add_line(path,'03 Virtual Impedance Interface/1','04 Common Protection and Limiter/1','autorouting','on');
add_line(path,'05 Average Voltage Converter/1','04 Common Protection and Limiter/2','autorouting','on');
add_line(path,'PCCMeasurementBus/1','04 Common Protection and Limiter/3','autorouting','on');
add_line(path,'BESSStatusBus/1','04 Common Protection and Limiter/4','autorouting','on');
add_line(path,'04 Common Protection and Limiter/1','05 Average Voltage Converter/1','autorouting','on');
add_line(path,v2_physical_port(converter),v2_physical_port([path '/AC_690V']));
add_gfm_pcs_status_assembly(path,'06 Status Interface',[900 250 1220 430]);
add_line(path,'01 GFM Strategy/1','06 Status Interface/1','autorouting','on');
add_line(path,'04 Common Protection and Limiter/2','06 Status Interface/2','autorouting','on');
add_line(path,'02 Virtual Impedance Policy/1','06 Status Interface/3','autorouting','on');
add_line(path,'03 Virtual Impedance Interface/2','06 Status Interface/4','autorouting','on');
add_line(path,'CommandBus/1','06 Status Interface/5','autorouting','on');
add_block('simulink/Ports & Subsystems/Out1',[path '/GFMPCSStatusBus'], ...
    'Position',[1500 350 1530 364],'OutDataTypeStr','Bus: GFMPCSStatusBus');
add_line(path,'06 Status Interface/1','GFMPCSStatusBus/1');v2_disable_previews(path);v2_route_level(path);
end
