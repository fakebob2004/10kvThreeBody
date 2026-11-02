function residual=validate_wind_step_energy()
% First-law check after precharge release, including mechanical and dq storage.
root=setup_v2_paths;model='Wind_PMSG_Transient_R4';
run(fullfile(root,'parameters','init_wind_pmsg_transient_r4.m'));
load_system(fullfile(root,'build',[model '.slx']));
out=sim(model,'StopTime','0.22');logs=out.logsout;
t=linspace(0,.22,22001)';
wt=sample(logs,'omega_turbine_rad_s',t);wg=sample(logs,'omega_generator_rad_s',t);
id=sample(logs,'PMSG_id_A',t);iq=sample(logs,'PMSG_iq_A',t);
pa=sample(logs,'P_aero_W',t);pm=sample(logs,'P_msc_W',t);
vdc=sample(logs,'Vdc_Meas',t);pcc=sample(logs,'P_PCC',t);
twist=PMSG.Init.shaft_angle_rad+cumtrapz(t,wt-wg);
energy=.5*(Drive.J_turbine_kg_m2*wt.^2+Drive.J_generator_kg_m2*wg.^2+Drive.K_shaft_Nm_per_rad*twist.^2) ...
      +.75*(PMSG.Ld_H*id.^2+PMSG.Lq_H*iq.^2);
heat=Drive.B_turbine_Nms_per_rad*wt.^2+Drive.B_generator_Nms_per_rad*wg.^2 ...
    +Drive.D_shaft_Nms_per_rad*(wt-wg).^2+1.5*PMSG.Rs_ohm*(id.^2+iq.^2);
k=t>=.11;tt=t(k);stored=energy(k);dcStored=.5*Converter.Cdc*vdc(k).^2;
flow=cumtrapz(tt,pa(k)-heat(k)-(pm(k)+PMSG.loss_constant_W)/PMSG.msc_efficiency);
inputEnergy=trapz(tt,pa(k));residual=max(abs(flow-(stored-stored(1))))/inputEnergy;
% PCC observer is filtered and bus voltage includes ESR. This second check
% bounds the combined converter/network losses and observer/storage mismatch.
acGap=(trapz(tt,pm(k)-pcc(k))-(dcStored(end)-dcStored(1)))/trapz(tt,pm(k));
fprintf('Wind energy residual %.5f%%; DC-to-PCC unallocated fraction %.5f%%\n',100*residual,100*acGap);
assert(residual<.01,'Wind mechanical-to-MSC energy balance failed');
assert(acGap>-.02&&acGap<.10,'DC-to-PCC energy gap out of range');
end
function v=sample(logs,name,t)
for k=1:logs.numElements
 e=logs{k};
 if strcmp(e.Name,name)
  x=e.Values;[tx,ix]=unique(x.Time(:),'last');v=interp1(tx,double(x.Data(ix)),t,'linear');return
 end
end
error('Missing logged signal %s',name);
end
