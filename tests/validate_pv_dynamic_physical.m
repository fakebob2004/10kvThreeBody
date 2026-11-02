function R=validate_pv_dynamic_physical()
%VALIDATE_PV_DYNAMIC_PHYSICAL Strong-machine dispatch and DC charge balance.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
m='pv_resource_dynamic_standalone';f=fullfile(root,'models','resources',[m '.slx']);
assert(isfile(f),'Build the dynamic PV standalone model before validation.');
load_system(f);in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','1.0');
in=in.setBlockParameter([m '/PV Command/P Increment'],'Time','0.6');
out=sim(in);x=out.pv_dynamic; t=x.Time(:); a=x.Data;
assignin('base','pv_validation_output',out);
assert(all(isfinite(a(:))),'Non-finite physical signals');
k1=t>=0.50 & t<=0.58;k2=t>=0.90 & t<=1.00;
R.P_before_W=mean(a(k1,22));R.P_after_W=mean(a(k2,22));
R.Q_after_var=mean(a(k2,23));R.Vdc_after_V=mean(a(k2,3));
R.Ipeak_A=max(hypot(a(:,9),a(:,10)));R.Vdc_max_V=max(a(:,3));
fprintf('PV dispatch before=%.3f MW after=%.3f MW Q=%.3f Mvar Vdc=%.1f V peak current=%.0f A\n', ...
 R.P_before_W/1e6,R.P_after_W/1e6,R.Q_after_var/1e6,R.Vdc_after_V,R.Ipeak_A);
assert(abs(R.P_before_W-2e6)<0.16e6,'2 MW dispatch tracking failed');
assert(abs(R.P_after_W-3e6)<0.24e6,'3 MW dispatch tracking failed');
assert(abs(R.Q_after_var)<0.15e6,'PCC reactive-power tracking failed');
assert(abs(R.Vdc_after_V-1500)<75,'DC-link voltage regulation failed');
assert(R.Ipeak_A<=1.03*evalin('base','V2.PV.control.Ilimit_peak_A'),'Current limit exceeded');
boost=out.pv_boost_current;vsc=out.pv_vsc_dc_current;
ib=interp1(boost.Time,squeeze(boost.Data),t);iv=interp1(vsc.Time,squeeze(vsc.Data),t);
C=evalin('base','V2.PV.dynamic.Cdc_F');
balance=C*(a(:,3)-a(1,3))-cumtrapz(t,ib-iv);
R.charge_residual_C=max(abs(balance));
assert(R.charge_residual_C<max(5,0.05*C*max(a(:,3))), ...
 'DC-link capacitor charge balance failed');
fprintf('PV_DYNAMIC_PHYSICAL_DISPATCH_PASS=1 P_before=%.3f MW P_after=%.3f MW Q=%.3f Mvar Vdc=%.1f V Ipeak=%.0f A charge_error=%.2f C\n', ...
 R.P_before_W/1e6,R.P_after_W/1e6,R.Q_after_var/1e6,R.Vdc_after_V,R.Ipeak_A,R.charge_residual_C);
end
