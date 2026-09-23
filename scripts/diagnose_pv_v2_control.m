function diagnose_pv_v2_control()
%DIAGNOSE_PV_V2_CONTROL Log typed internal buses without changing interfaces.
root=fileparts(fileparts(mfilename('fullpath')));setup_v2_paths;
define_resource_buses(true);define_v2_parameters(true);define_strong_machine_fixture(true);
m='pv_resource_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
set_param(m,'SignalLogging','on','SignalLoggingName','logsout','StopTime','0.6');
targets={ ...
    [m '/PV Resource/02 PCS/PCS Status'], 'pcs_status'; ...
    [m '/PV Resource/01 PV Source and DC Side/PCS Command'], 'pcs_command'; ...
    [m '/PV Resource/03 AC Interface/PCC Measurement/PCC Measurement'], 'pcc_bus'};
for k=1:size(targets,1)
    ph=get_param(targets{k,1},'PortHandles');
    set_param(ph.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom', ...
        'DataLoggingName',targets{k,2});
end
o=sim(m);logs=o.logsout;
dump_bus(logs,'pcs_status',{'theta_rad','frequency_Hz','phase_error_rad', ...
    'Id_ref_Apk','Iq_ref_Apk','Iactual_Apk','current_limit_factor'});
dump_bus(logs,'pcs_command',{'P_ref_W','Q_ref_var','enable'});
dump_bus(logs,'pcc_bus',{'vabc_V','iabc_A','P_W','Q_var','Vll_rms_V','frequency_Hz'});
fprintf('PV_V2_CONTROL_DIAGNOSTIC_COMPLETE=1\n');close_system(m,0);
end

function dump_bus(logs,name,fields)
e=logs.get(name);v=e.Values;
fprintf('\nBUS=%s\n',name);
for k=1:numel(fields)
    ts=v.(fields{k});data=squeeze(ts.Data);nt=numel(ts.Time);
    if size(data,1)~=nt && size(data,2)==nt,data=data.';end
    if size(data,1)==nt,data=data(ts.Time>0.5,:);else,data=data(end,:);end
    fprintf('%s mean=%g min=%g max=%g\n',fields{k}, ...
        mean(data,'all'),min(data,[],'all'),max(data,[],'all'));
end
end
