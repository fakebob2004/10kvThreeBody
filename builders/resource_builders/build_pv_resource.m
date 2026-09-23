function path=build_pv_resource(parent,name,cfg,pos)
%BUILD_PV_RESOURCE Generate an independent three-module PV resource.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[0.84,0.94,0.82]','ContentPreviewEnabled','off', ...
    'AttributesFormatString','PV Source/DC -> GFL PCS -> independent AC Interface');
add_block('simulink/Ports & Subsystems/In1',[path '/ResourceCommandBus'], ...
    'Position',[20 150 50 164],'OutDataTypeStr','Bus: ResourceCommandBus');
add_block('simulink/Ports & Subsystems/Out1',[path '/ResourceStatusBus'], ...
    'Position',[1310 400 1340 414],'OutDataTypeStr','Bus: ResourceStatusBus');
v2_add_pmio(path,'PCC_10kV',1,'Right','foundation.electrical.three_phase',[1310 150 1340 180]);
source=add_pv_source_dc(path,'01 PV Source and DC Side',cfg,[100 85 345 210]); %#ok<NASGU>
pcs=add_gfl_pcs(path,'02 PCS',cfg,[440 70 760 225]);
ac=add_ac_interface(path,'03 AC Interface',cfg,[855 70 1175 225]);
add_resource_status_assembly(path,'Status Interface',[850 340 1175 455]);
add_line(path,'ResourceCommandBus/1','01 PV Source and DC Side/1','autorouting','on');
add_line(path,'01 PV Source and DC Side/1','02 PCS/1','autorouting','on');
add_line(path,'03 AC Interface/1','02 PCS/2','autorouting','on');
add_line(path,'01 PV Source and DC Side/2','Status Interface/1','autorouting','on');
add_line(path,'02 PCS/1','Status Interface/2','autorouting','on');
add_line(path,'03 AC Interface/1','Status Interface/3','autorouting','on');
add_line(path,'Status Interface/1','ResourceStatusBus/1','autorouting','on');
add_line(path,v2_physical_port(pcs),v2_port(ac,'LConn',1));
add_line(path,v2_port(ac,'RConn',1),v2_physical_port([path '/PCC_10kV']));
v2_disable_previews(path);v2_route_level(path);
end
