function path=add_gfm_dvoc_strategy(parent,name,cfg,pos)
%ADD_GFM_DVOC_STRATEGY Local measurement -> dVOC/current law -> voltage bus.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'ContentPreviewEnabled','off','AttributesFormatString', ...
    'limited dVOC + virtual admittance + current tracking; local filter sensing');
names={'CommandBus','PCCMeasurementBus','BridgeCurrent','FilterMeasurements'};
for k=1:4
    add_block('simulink/Ports & Subsystems/In1',[path '/' names{k}], ...
        'Port',num2str(k),'Position',[20 40+70*k 50 54+70*k]);
end
add_block('simulink/Sinks/Terminator',[path '/PCC not used by local law'],'Position',[80 175 100 195]);
set_param([path '/PCC not used by local law'],'ShowName','off');
add_line(path,'PCCMeasurementBus/1','PCC not used by local law/1');
add_block('simulink/Signal Routing/Bus Selector',[path '/Resource Commands'], ...
    'Position',[100 60 105 145],'OutputSignals','P_ref_W,Q_ref_var,V_ref_V,f_ref_Hz,enable,mode');
add_line(path,'CommandBus/1','Resource Commands/1');
add_block('simulink/Sources/Clock',[path '/Nominal Frame Time'],'Position',[180 20 210 40]);
add_block('simulink/Continuous/Integrator',[path '/Oscillator State dq'], ...
    'Position',[550 250 630 290],'InitialCondition','[1;0]');
add_block('simulink/Signal Routing/Mux',[path '/Local State and Commands'], ...
    'Position',[300 30 305 320],'Inputs','10');
add_block('simulink/Math Operations/Reshape',[path '/State Vector Shape'], ...
    'Position',[450 315 530 345],'OutputDimensionality','Row vector (2-D)');
add_line(path,'Oscillator State dq/1','State Vector Shape/1','autorouting','on');
sources={'Nominal Frame Time/1','State Vector Shape/1','BridgeCurrent/1','FilterMeasurements/1', ...
    'Resource Commands/1','Resource Commands/2','Resource Commands/3','Resource Commands/4','Resource Commands/5','Resource Commands/6'};
for k=1:10,add_line(path,sources{k},sprintf('Local State and Commands/%d',k),'autorouting','on');end
f=[path '/Limited dVOC and Current Tracking'];
add_block('simulink/User-Defined Functions/MATLAB Function',f,'Position',[410 60 650 170]);
sf=sfroot;ch=sf.find('-isa','Stateflow.EMChart','Path',f);
ch.Script=fileread(which('dvoc_bess_kernel'));
add_block('simulink/Sources/Constant',[path '/Physical Bases and Filter'], ...
    'Position',[150 380 330 420],'Value',['[' cfg '.rating.S_VA;' cfg '.rating.V_ac_low_V;' cfg '.rating.f_Hz;' cfg '.filter.R1_ohm;' cfg '.filter.L1_H]']);
add_line(path,'Local State and Commands/1','Limited dVOC and Current Tracking/1');
add_line(path,'Physical Bases and Filter/1','Limited dVOC and Current Tracking/2','autorouting','on');
add_line(path,'Limited dVOC and Current Tracking/1','Oscillator State dq/1','autorouting','on');
add_block('simulink/Signal Routing/Demux',[path '/Voltage Command Fields'], ...
    'Position',[720 60 725 200],'Outputs','[3 1 1 1 1]');
add_block('simulink/Math Operations/Reshape',[path '/Command Vector Shape'], ...
    'Position',[660 210 740 240],'OutputDimensionality','1-D array');
add_line(path,'Limited dVOC and Current Tracking/2','Command Vector Shape/1','autorouting','on');
add_line(path,'Command Vector Shape/1','Voltage Command Fields/1','autorouting','on');
add_block('simulink/Signal Routing/Bus Creator',[path '/Voltage Command Bus'], ...
    'Position',[820 60 825 200],'Inputs','5','OutDataTypeStr','Bus: GFMVoltageCommandBus');
fields={'vabc_V','theta_rad','omega_rad_s','Vll_ref_V','enabled'};
for k=1:5,v2_named_line(path,sprintf('Voltage Command Fields/%d',k),sprintf('Voltage Command Bus/%d',k),fields{k});end
add_block('simulink/Ports & Subsystems/Out1',[path '/GFMVoltageCommandBus'], ...
    'Position',[900 125 930 139],'OutDataTypeStr','Bus: GFMVoltageCommandBus');
add_line(path,'Voltage Command Bus/1','GFMVoltageCommandBus/1');v2_route_level(path);
end
