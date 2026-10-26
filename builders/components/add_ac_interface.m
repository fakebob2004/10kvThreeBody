function path=add_ac_interface(parent,name,cfg,pos)
%ADD_AC_INTERFACE Instantiate one independent filter/transformer/PCC chain.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[1.00,0.88,0.72]','ContentPreviewEnabled','off', ...
    'AttributesFormatString','independent filter + 0.69/10 kV transformer + PCC sensing');
v2_add_pmio(path,'PCS AC Terminal',1,'Left','foundation.electrical.three_phase',[20 90 50 120]);
v2_add_pmio(path,'PCC_10kV',2,'Right','foundation.electrical.three_phase',[1120 90 1150 120]);
rlc='ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)';
gnd=sprintf('ee_lib/Connectors &\nReferences/Grounded Neutral\n(Three-Phase)');
xf=sprintf('ee_lib/Passive/Transformers/Two-Winding\nTransformer\n(Three-Phase)');
cfgData=evalin('base',cfg);isLCL=isfield(cfgData.filter,'topology')&& ...
    strcmpi(cfgData.filter.topology,'LCL');
localSense=isfield(cfgData.control,'strategy')&&strcmpi(cfgData.control.strategy,'dvoc');
if isLCL
    add_block(rlc,[path '/Inverter-side R1 + L1'],'Position',[130 55 260 125], ...
        'component_structure','ee.enum.rlc.structure.SeriesRL', ...
        'R',[cfg '.filter.R1_ohm'],'L',[cfg '.filter.L1_H']);
    add_block(rlc,[path '/Grid-side R2 + L2'],'Position',[430 55 560 125], ...
        'component_structure','ee.enum.rlc.structure.SeriesRL', ...
        'R',[cfg '.filter.R2_ohm'],'L',[cfg '.filter.L2_H']);
    shuntNode=v2_port([path '/Inverter-side R1 + L1'],'RConn',1);
    transformerInput=v2_port([path '/Grid-side R2 + L2'],'RConn',1);
else
    add_block(rlc,[path '/Equivalent Filter Series R'],'Position',[275 65 405 125], ...
        'component_structure','ee.enum.rlc.structure.R', ...
        'R',[cfg '.filter.R1_ohm+' cfg '.filter.R2_ohm']);
    shuntNode=v2_physical_port([path '/PCS AC Terminal']);
    transformerInput=v2_port([path '/Equivalent Filter Series R'],'RConn',1);
end
add_block(rlc,[path '/Damped Shunt C'],'Position',[300 165 395 225], ...
    'component_structure','ee.enum.rlc.structure.SeriesRC', ...
    'R',[cfg '.filter.Rd_ohm'],'C',[cfg '.filter.C_F']);
add_block(gnd,[path '/Filter Ground'],'Position',[455 180 485 210]);
add_block(xf,[path '/Step-up Transformer'],'Position',[610 45 740 145], ...
    'SRated',[cfg '.transformer.S_VA'],'FRated',[cfg '.rating.f_Hz'], ...
    'VRated1',[cfg '.transformer.V1_V'],'VRated2',[cfg '.transformer.V2_V'], ...
    'Winding1Connection','ee.enum.windingconnection.Yg','Winding2Connection','ee.enum.windingconnection.Yg', ...
    'pu_Rw1',[cfg '.transformer.R_pu/2'],'pu_Rw2',[cfg '.transformer.R_pu/2'], ...
    'leakage_reactance_option','ee.enum.transformer_leakage.exclude');
meas=add_pcc_measurement(path,'PCC Measurement',cfg,[800 35 1000 155]);
if isLCL
    add_line(path,v2_physical_port([path '/PCS AC Terminal']), ...
        v2_port([path '/Inverter-side R1 + L1'],'LConn',1));
    if localSense
        add_local_filter_sensor(path,shuntNode,v2_port([path '/Grid-side R2 + L2'],'LConn',1));
    else
        add_line(path,shuntNode,v2_port([path '/Grid-side R2 + L2'],'LConn',1));
    end
else
    add_line(path,v2_physical_port([path '/PCS AC Terminal']), ...
        v2_port([path '/Equivalent Filter Series R'],'LConn',1));
end

function add_local_filter_sensor(path,left,right)
sensor=[path '/Local Filter VI'];
add_block(sprintf('ee_lib/Sensors &\nTransducers/Current and Voltage\nSensor (Three-Phase)'), ...
    sensor,'Position',[335 45 395 120],'vMeasurementType','ee.enum.vmeasurement.ll');
add_line(path,left,v2_port(sensor,'LConn',1));
add_line(path,v2_port(sensor,'RConn',3),right);
pss=sprintf('nesl_utility/PS-Simulink\nConverter');
names={'Filter Voltage LL','External Terminal Current'};units={'V','A'};
for k=1:2
    y=300+65*(k-1);
    add_block(pss,[path '/' names{k}],'Position',[460 y 590 y+35],'Unit',units{k});
    add_line(path,v2_port(sensor,'RConn',k),v2_port([path '/' names{k}],'LConn',1),'autorouting','on');
end
add_block('simulink/Signal Routing/Mux',[path '/Local Measurements'], ...
    'Position',[700 300 705 405],'Inputs','2');
for k=1:2,add_line(path,[names{k} '/1'],sprintf('Local Measurements/%d',k));end
add_block('simulink/Ports & Subsystems/Out1',[path '/FilterMeasurements'], ...
    'Position',[1120 350 1150 364],'Port','2');
add_line(path,'Local Measurements/1','FilterMeasurements/1');
end
add_line(path,shuntNode,v2_port([path '/Damped Shunt C'],'LConn',1));
add_line(path,v2_port([path '/Damped Shunt C'],'RConn',1),v2_port([path '/Filter Ground'],'LConn',1));
add_line(path,transformerInput,v2_port([path '/Step-up Transformer'],'LConn',1));
mph=get_param(meas,'PortHandles');physical=[mph.LConn mph.RConn];assert(numel(physical)==2);
% Port ordering is resolved by side, not by generated Conn names.
left=mph.LConn;right=mph.RConn;assert(numel(left)==1&&numel(right)==1);
add_line(path,v2_port([path '/Step-up Transformer'],'RConn',1),left);
add_line(path,right,v2_physical_port([path '/PCC_10kV']));
add_block('simulink/Ports & Subsystems/Out1',[path '/PCCMeasurementBus'], ...
    'Position',[1120 245 1150 259],'Port','1','OutDataTypeStr','Bus: PCCMeasurementBus');
add_line(path,'PCC Measurement/1','PCCMeasurementBus/1','autorouting','on');
v2_route_level(path);
end
