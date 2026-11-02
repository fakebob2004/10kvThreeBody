function R=validate_pv_dynamic_operating_modes()
%VALIDATE_PV_DYNAMIC_OPERATING_MODES Zero, rated PF=0.9 and enable-off.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
m='pv_resource_dynamic_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
cases={'zero',0,0,1;'rated_pf09',5e6,5e6*tan(acos(.9)),1;'disabled',2e6,0,0};R=struct();
for j=1:size(cases,1)
 name=cases{j,1};p=cases{j,2};q=cases{j,3};en=cases{j,4};
 in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','0.8');
 in=in.setBlockParameter([m '/PV Command/P Base'],'Value',num2str(p,17));
 in=in.setBlockParameter([m '/PV Command/P Increment'],'After','0');
 in=in.setBlockParameter([m '/PV Command/Q Base'],'Value',num2str(q,17));
 in=in.setBlockParameter([m '/PV Command/Enable'],'Value',num2str(en));
 out=sim(in);assignin('base',['pv_mode_' name],out);x=out.pv_dynamic;t=x.Time(:);a=x.Data;k=t>.70;
 r=struct('P_W',mean(a(k,22)),'Q_var',mean(a(k,23)), ...
 'Vdc_V',mean(a(k,3)),'Ipeak_A',max(hypot(a(:,9),a(:,10))));
 fprintf('%s P=%.3f MW Q=%.3f Mvar Vdc=%.1f V Ipeak=%.0f A\n', ...
 name,r.P_W/1e6,r.Q_var/1e6,r.Vdc_V,r.Ipeak_A);
 assert(all(isfinite(a(:))),[name ' nonfinite']);
 assert(abs(r.P_W-p*en)<max(.15e6,.08*p),[name ' active power']);
 if en,assert(abs(r.Q_var-q)<.2e6,[name ' reactive power']);end
 assert(r.Vdc_V>900&&r.Vdc_V<1650,[name ' DC voltage']);
 R.(name)=r;
end
fprintf('PV_DYNAMIC_OPERATING_MODES_PASS=1\n');
end
