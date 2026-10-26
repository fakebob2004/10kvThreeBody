function diagnose_bess_dvoc()
%DIAGNOSE_BESS_DVOC Read internal energy/control signals without tuning.
root=setup_v2_paths();m='bess_resource_dvoc';load_system(fullfile(root,'models','resources',[m '.slx']));
s=[m '/BESS Resource/02 PCS/01 GFM Strategy'];
add_block('simulink/Sinks/To Workspace',[s '/Diagnostic Local Input'], ...
    'VariableName','dvoc_local','SaveFormat','Timeseries','Position',[1000 300 1140 340]);
add_line(s,'Local State and Commands/1','Diagnostic Local Input/1','autorouting','on');
o=sim(m,'StopTime','0.8');ts=o.get('dvoc_local');r=o.get('bess_v2_result');
data=squeeze(ts.Data);if size(data,1)==18,data=data';end
out=fullfile(root,'artifacts','bess_dvoc');save(fullfile(out,'diagnostic.mat'),'data','r');
cfg=evalin('base','V2.BESS');S=cfg.rating.S_VA;V=cfg.rating.V_ac_low_V;
Vpk=sqrt(2/3)*V;Ipk=sqrt(2/3)*S/V;C=(2/3)*[1 -.5 -.5;0 sqrt(3)/2 -sqrt(3)/2];
tail=data(data(:,1)>.7,:);h=tail(:,2:3);i=tail(:,4:6);ll=tail(:,7:9);io=tail(:,10:12);
phase=[ll(:,1)-ll(:,3),ll(:,2)-ll(:,1),ll(:,3)-ll(:,2)]/3;
ab=phase*C'/Vpk;ia=io*C'/Ipk;
angle=2*pi*50*tail(:,1);cs=cos(angle);sn=sin(angle);
vdq=[cs.*ab(:,1)+sn.*ab(:,2),-sn.*ab(:,1)+cs.*ab(:,2)];
idq=[cs.*ia(:,1)+sn.*ia(:,2),-sn.*ia(:,1)+cs.*ia(:,2)];
Iref=(h-vdq)/.2;Ibridge=i*C'/Ipk;
tracking=vecnorm(Ibridge,2,2)-vecnorm(Iref,2,2);
stats=table(mean(vecnorm(h,2,2)),mean(vecnorm(vdq,2,2)), ...
    mean(vecnorm(idq,2,2)),mean(vecnorm(h-vdq,2,2)), ...
    mean(sum(vdq.*idq,2)),mean(vdq(:,2).*idq(:,1)-vdq(:,1).*idq(:,2)), ...
    mean(abs(tracking)), ...
    'VariableNames',{'Eosc_pu','Vfilter_pu','Iexternal_pu','VirtualDrop_pu', ...
    'Pfilter_pu','Qfilter_pu','CurrentMagnitudeTrackingError_pu'});
writetable(stats,fullfile(out,'diagnostic_summary.csv'));disp(stats);
close_system(m,0); % Diagnostic additions are not persisted to the model.
end
