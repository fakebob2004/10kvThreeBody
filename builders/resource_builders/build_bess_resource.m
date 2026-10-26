function path=build_bess_resource(parent,name,cfg,pos)
%BUILD_BESS_RESOURCE Generate an independent replaceable-strategy BESS-GFM.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[1.00,0.93,0.74]','ContentPreviewEnabled','off', ...
    'AttributesFormatString','BESS Source/DC -> replaceable GFM PCS -> independent AC Interface');
add_block('simulink/Ports & Subsystems/In1',[path '/ResourceCommandBus'], ...
    'Position',[20 125 50 139],'OutDataTypeStr','Bus: ResourceCommandBus');
add_block('simulink/Ports & Subsystems/Out1',[path '/ResourceStatusBus'], ...
    'Position',[1370 410 1400 424],'OutDataTypeStr','Bus: ResourceStatusBus');
v2_add_pmio(path,'PCC_10kV',1,'Right','foundation.electrical.three_phase',[1370 135 1400 165]);
add_bess_source_dc(path,'01 BESS Source and DC Side',cfg,[100 70 365 220]);
pcs=add_gfm_pcs(path,'02 PCS',cfg,[460 55 830 235]);
ac=add_ac_interface(path,'03 AC Interface',cfg,[925 55 1235 235]);
add_bess_resource_status_assembly(path,'Status Interface',[925 350 1235 470]);
add_line(path,'ResourceCommandBus/1','02 PCS/1','autorouting','on');
add_line(path,'03 AC Interface/1','01 BESS Source and DC Side/1','autorouting','on');
add_line(path,'03 AC Interface/1','02 PCS/2','autorouting','on');
add_line(path,'01 BESS Source and DC Side/1','02 PCS/3','autorouting','on');
if strcmpi(evalin('base',[cfg '.control.strategy']),'dvoc')
    add_line(path,'03 AC Interface/2','02 PCS/4','autorouting','on');
end
add_line(path,'01 BESS Source and DC Side/2','Status Interface/1','autorouting','on');
add_line(path,'02 PCS/1','Status Interface/2','autorouting','on');
add_line(path,'03 AC Interface/1','Status Interface/3','autorouting','on');
add_line(path,'Status Interface/1','ResourceStatusBus/1','autorouting','on');
add_line(path,v2_physical_port(pcs),v2_port(ac,'LConn',1));
add_line(path,v2_port(ac,'RConn',1),v2_physical_port([path '/PCC_10kV']));
v2_disable_previews(path);v2_route_level(path);
end
