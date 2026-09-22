% Typed Stage-2 resource API shared by Simulink and external coordinators.
cmdNames={'P_ref_W','Q_ref_var','enable','mode'};
statusNames={'P_W','Q_var','Vpcc_V','frequency_Hz','available_power_W', ...
    'power_headroom_W','current_limit_factor','health','energy_state_pu', ...
    'Vdc_V','mppt_capture_pu','dispatch_limit_W'};

S2_ResourceCommand=Simulink.Bus;
for k=1:numel(cmdNames)
    e(k)=Simulink.BusElement;e(k).Name=cmdNames{k};e(k).DataType='double'; %#ok<SAGROW>
end
S2_ResourceCommand.Elements=e;clear e;
S2_ResourceStatus=Simulink.Bus;
for k=1:numel(statusNames)
    e(k)=Simulink.BusElement;e(k).Name=statusNames{k};e(k).DataType='double'; %#ok<SAGROW>
end
S2_ResourceStatus.Elements=e;clear e;

S2_API=struct();
S2_API.sample_time_s=.005;
S2_API.resource_order={'BESS','PV','Wind'};
S2_API.command_fields=cmdNames;
S2_API.status_fields=statusNames;
S2_API.mode.AUTONOMOUS=0;
S2_API.mode.COORDINATED=1;
S2_API.mode.BLOCKED=2;
S2_API.rating.P_W=[5e6 5e6 5e6];
S2_API.rating.S_VA=[6.25e6 6.25e6 6.25e6];
S2_API.soc.min=.20;S2_API.soc.max=.90;
S2_API.health.good=1;S2_API.health.bad=0;
S2_API.runtime.coordinator_enable=0;
S2_API.runtime.mode=[0 0 0];
S2_API.runtime.bess_command=[0 0 1];
% Flat numeric contract for MATLAB Function/code generation and future
% Python/C++ bindings.  Keep cells/strings/nested metadata out of the
% real-time function boundary.
S2_API.coordinator_config=[S2_API.mode.AUTONOMOUS ...
    S2_API.mode.COORDINATED S2_API.mode.BLOCKED ...
    S2_API.soc.min S2_API.soc.max ...
    S2_API.rating.P_W S2_API.rating.S_VA];
assignin('base','S2_ResourceCommand',S2_ResourceCommand);
assignin('base','S2_ResourceStatus',S2_ResourceStatus);
assignin('base','S2_API',S2_API);
fprintf('Stage2 Resource API: Ts=%.1f ms, 4 command + 12 status fields per resource.\n', ...
    1e3*S2_API.sample_time_s);
