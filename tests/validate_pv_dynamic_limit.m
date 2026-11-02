function R=validate_pv_dynamic_limit()
%VALIDATE_PV_DYNAMIC_LIMIT Check current-reference limiting under P/Q overload.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
m='pv_resource_dynamic_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','0.7');
in=in.setBlockParameter([m '/PV Command/P Base'],'Value','5e6');
in=in.setBlockParameter([m '/PV Command/P Increment'],'After','0');
in=in.setBlockParameter([m '/PV Command/Q Base'],'Value','6e6');
out=sim(in);assignin('base','pv_limit_output',out);x=out.pv_dynamic;t=x.Time(:);a=x.Data;
ilim=evalin('base','V2.PV.control.Ilimit_peak_A');k=t>=0.55;
R.factor=min(a(k,15));R.Iref_max=max(hypot(a(:,7),a(:,8)));
R.Iactual_max=max(hypot(a(:,9),a(:,10)));R.Vdc_max=max(a(:,3));
fprintf('overload factor=%.3f Iref=%.0f A Iactual=%.0f A Vdc_max=%.0f V\n', ...
 R.factor,R.Iref_max,R.Iactual_max,R.Vdc_max);
assert(all(isfinite(a(:))),'Non-finite overload response');
assert(R.factor<0.98,'Current reference limiter did not activate');
assert(R.Iref_max<=1.001*ilim,'Current reference limit exceeded');
assert(R.Iactual_max<=1.03*ilim,'Physical converter current exceeded limit');
assert(R.Vdc_max<evalin('base','V2.PV.dynamic.dc_overvoltage_V')*1.10, ...
 'DC link voltage exceeded overload tolerance');
fprintf('PV_DYNAMIC_OVERLOAD_PASS=1\n');
end
