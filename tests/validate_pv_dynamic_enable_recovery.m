function R=validate_pv_dynamic_enable_recovery()
%VALIDATE_PV_DYNAMIC_ENABLE_RECOVERY Check off interval and reconnection.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
m='pv_resource_dynamic_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','1.2');
in=in.setBlockParameter([m '/PV Command/P Base'],'Value','2e6');
in=in.setBlockParameter([m '/PV Command/P Increment'],'After','0');
in=in.setBlockParameter([m '/PV Command/Enable Off'],'Time','0.45');
in=in.setBlockParameter([m '/PV Command/Enable On'],'Time','0.70');
out=sim(in);assignin('base','pv_enable_output',out);x=out.pv_dynamic;t=x.Time(:);a=x.Data;
off=t>.57&t<.68;rec=t>1.10;
R.off_P_W=mean(a(off,22));R.recovered_P_W=mean(a(rec,22));
R.off_Idref_A=max(abs(a(off,7)));R.off_Iqref_A=max(abs(a(off,8)));
R.Ipeak_A=max(hypot(a(:,9),a(:,10)));R.Vdc_max_V=max(a(:,3));
fprintf('enable off P=%.3f MW recovered P=%.3f MW Ipeak=%.0f A Vdc max=%.0f V\n', ...
 R.off_P_W/1e6,R.recovered_P_W/1e6,R.Ipeak_A,R.Vdc_max_V);
assert(all(isfinite(a(:))),'Non-finite enable response');
assert(abs(R.off_P_W)<.15e6,'Enable-off injection failed');
assert(R.off_Idref_A<1&&R.off_Iqref_A<1,'Disabled current references not zero');
assert(abs(R.recovered_P_W-2e6)<.16e6,'Enable recovery failed');
assert(R.Ipeak_A<=1.03*evalin('base','V2.PV.control.Ilimit_peak_A'),'Enable current limit exceeded');
assert(R.Vdc_max_V<1.1*evalin('base','V2.PV.dynamic.dc_overvoltage_V'),'Enable DC voltage exceeded tolerance');
fprintf('PV_DYNAMIC_ENABLE_RECOVERY_PASS=1\n');
end
