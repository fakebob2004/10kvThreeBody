function path=add_ac_interface(parent,name,cfg,pos)
%ADD_AC_INTERFACE Instantiate one independent filter/transformer/PCC chain.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[1.00,0.88,0.72]','ContentPreviewEnabled','off', ...
    'AttributesFormatString','independent filter + 0.69/10 kV transformer + PCC sensing');
v2_add_pmio(path,'PCS AC Terminal',1,'Left','foundation.electrical.three_phase',[20 90 50 120]);
v2_add_pmio(path,'PCC_10kV',2,'Right','foundation.electrical.three_phase',[920 90 950 120]);
rlc='ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)';
gnd=sprintf('ee_lib/Connectors &\nReferences/Grounded Neutral\n(Three-Phase)');
xf=sprintf('ee_lib/Passive/Transformers/Two-Winding\nTransformer\n(Three-Phase)');
add_block(rlc,[path '/Equivalent Filter Series R'],'Position',[275 65 405 125], ...
    'component_structure','ee.enum.rlc.structure.R', ...
    'R',[cfg '.filter.R1_ohm+' cfg '.filter.R2_ohm']);
add_block(rlc,[path '/Damped Shunt C'],'Position',[115 165 210 225], ...
    'component_structure','ee.enum.rlc.structure.SeriesRC','R',[cfg '.filter.Rd_ohm'],'C',[cfg '.filter.C_F']);
add_block(gnd,[path '/Filter Ground'],'Position',[330 180 360 210]);
add_block(xf,[path '/Step-up Transformer'],'Position',[455 45 585 145], ...
    'SRated',[cfg '.transformer.S_VA'],'FRated',[cfg '.rating.f_Hz'], ...
    'VRated1',[cfg '.transformer.V1_V'],'VRated2',[cfg '.transformer.V2_V'], ...
    'Winding1Connection','ee.enum.windingconnection.Yg','Winding2Connection','ee.enum.windingconnection.Yg', ...
    'pu_Rw1',[cfg '.transformer.R_pu/2'],'pu_Rw2',[cfg '.transformer.R_pu/2'], ...
    'leakage_reactance_option','ee.enum.transformer_leakage.exclude');
meas=add_pcc_measurement(path,'PCC Measurement',cfg,[650 35 850 155]);
add_line(path,v2_physical_port([path '/PCS AC Terminal']),v2_port([path '/Equivalent Filter Series R'],'LConn',1));
add_line(path,v2_physical_port([path '/PCS AC Terminal']),v2_port([path '/Damped Shunt C'],'LConn',1));
add_line(path,v2_port([path '/Damped Shunt C'],'RConn',1),v2_port([path '/Filter Ground'],'LConn',1));
add_line(path,v2_port([path '/Equivalent Filter Series R'],'RConn',1),v2_port([path '/Step-up Transformer'],'LConn',1));
mph=get_param(meas,'PortHandles');physical=[mph.LConn mph.RConn];assert(numel(physical)==2);
% Port ordering is resolved by side, not by generated Conn names.
left=mph.LConn;right=mph.RConn;assert(numel(left)==1&&numel(right)==1);
add_line(path,v2_port([path '/Step-up Transformer'],'RConn',1),left);
add_line(path,right,v2_physical_port([path '/PCC_10kV']));
add_block('simulink/Ports & Subsystems/Out1',[path '/PCCMeasurementBus'], ...
    'Position',[920 245 950 259],'Port','1','OutDataTypeStr','Bus: PCCMeasurementBus');
add_line(path,'PCC Measurement/1','PCCMeasurementBus/1','autorouting','on');
v2_route_level(path);
end
