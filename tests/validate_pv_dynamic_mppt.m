function R=validate_pv_dynamic_mppt()
%VALIDATE_PV_DYNAMIC_MPPT Check array tracking under irradiance-limited power.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
m='pv_resource_dynamic_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','0.8');
in=in.setBlockParameter([m '/PV Command/P Base'],'Value','5e6');
in=in.setBlockParameter([m '/PV Command/P Increment'],'After','0');
in=in.setBlockParameter([m '/PV Resource/01 PV Source and DC Side/Irradiance'],'Value','800');
out=sim(in);assignin('base','pv_mppt_output',out);x=out.pv_dynamic;t=x.Time(:);a=x.Data;
p=evalin('base','V2.PV.dynamic');k=t>=0.70;
% Independent one-diode I-V curve for the Solar Cell's default ideality
% factor 1.5, series resistance 0 and open shunt resistance at 25 C.
vt=1.380649e-23*(p.temperature_degC+273.15)/1.602176634e-19;
isc=p.Isc_cell_A;isat=isc/(exp(p.Voc_cell_V/(1.5*vt))-1);
f=@(v) -p.Nseries*p.Nparallel*v.*max(0,0.8*isc-isat.*(exp(v/(1.5*vt))-1));
[~,negmax]=fminbnd(f,0,p.Voc_cell_V);R.available_W=-negmax;
R.array_W=mean(a(k,1).*a(k,2));R.pcc_W=mean(a(k,22));
R.capture=R.array_W/R.available_W;R.Vdc_V=mean(a(k,3));
fprintf('MPPT array=%.3f MW theoretical=%.3f MW capture=%.4f PCC=%.3f MW Vdc=%.1f V\n', ...
 R.array_W/1e6,R.available_W/1e6,R.capture,R.pcc_W/1e6,R.Vdc_V);
assert(all(isfinite(a(:))),'Non-finite MPPT response');
assert(R.capture>0.95&&R.capture<1.05,'MPPT did not approach the array maximum');
assert(abs(R.Vdc_V-p.Vdc_ref_V)<75,'DC-link regulation failed');
assert(abs(R.array_W-R.pcc_W)<0.2e6,'PV to AC power transfer mismatch');
fprintf('PV_DYNAMIC_MPPT_PASS=1\n');
end
