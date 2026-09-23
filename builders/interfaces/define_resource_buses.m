function buses=define_resource_buses(assignToBase)
%DEFINE_RESOURCE_BUSES Create the stable typed v2 resource interfaces.
if nargin<1,assignToBase=true;end
buses=struct();
buses.ResourceCommandBus=make_bus({ ...
    'P_ref_W','Q_ref_var','V_ref_V','f_ref_Hz','enable','mode'});
buses.PCCMeasurementBus=make_bus({ ...
    'vabc_V','iabc_A','P_W','Q_var','Vll_rms_V','frequency_Hz'});
buses.PCCMeasurementBus.Elements(1).Dimensions=3;
buses.PCCMeasurementBus.Elements(2).Dimensions=3;
buses.ResourceStatusBus=make_bus({ ...
    'P_W','Q_var','Vpcc_V','frequency_Hz','available_power_W', ...
    'power_headroom_W','current_limit_factor','energy_state_pu', ...
    'Vdc_V','control_mode','healthy'});
buses.PCSStatusBus=make_bus({'theta_rad','frequency_Hz','phase_error_rad', ...
    'Id_ref_Apk','Iq_ref_Apk','Iactual_Apk','current_limit_factor', ...
    'limit_active','control_mode','healthy'});
buses.SourceStatusBus=make_bus({'available_power_W','dispatch_limit_W', ...
    'energy_state_pu','Vdc_V','mppt_capture_pu'});
buses.PVStatusBus=make_bus({'available_power_W','mppt_capture_pu','Vdc_V'});
buses.WindStatusBus=make_bus({'available_power_W','dispatch_limit_W', ...
    'mppt_capture_pu','energy_state_pu','Vdc_V'});
buses.BESSStatusBus=make_bus({'SOC_pu','Vdc_V','battery_current_A', ...
    'charge_headroom_W','discharge_headroom_W'});
if assignToBase
    n=fieldnames(buses);for k=1:numel(n),assignin('base',n{k},buses.(n{k}));end
end
end

function b=make_bus(names)
b=Simulink.Bus;e=repmat(Simulink.BusElement,1,numel(names));
for k=1:numel(names),e(k).Name=names{k};e(k).DataType='double';e(k).Dimensions=1;end
b.Elements=e;
end
