% Validate the R7 4 MW -> 5 MW physical load-step response.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
run(fullfile(scriptDir,'init_bess_gfm_dynamic_r7.m'));
modelName='BESS_GFM_10kV_Dynamic_R7';
modelFile=fullfile(projectRoot,'build',[modelName '.slx']);
resultPng=fullfile(projectRoot,'build',[modelName '_results.png']);
load_system(modelFile);
out=sim(modelName);
r=squeeze(out.get('gfm_r7_result'));
if size(r,2)~=15,r=r.';end
assert(size(r,2)==15 && all(isfinite(r),'all'),'Invalid R7 result array.');

t=r(:,1); P=r(:,2); Q=r(:,3); f=r(:,4); Vcmd=r(:,5); SOC=r(:,6);
Vdc=r(:,7); Ibat=r(:,8); modulation=r(:,9); Pbat=r(:,10);
duty=r(:,11); Iref=r(:,12); Iac=r(:,13); acFactor=r(:,14);
pre=t>0.22&t<0.28; post=t>0.70; event=t>G.load.step_time_s-0.02;
preMean=mean(r(pre,:),1); postMean=mean(r(post,:),1);

assert(preMean(2)>3.90e6 && preMean(2)<4.10e6,'Pre-step power is not 4 MW.');
assert(postMean(2)>4.90e6 && postMean(2)<5.15e6,'Post-step power is not 5 MW.');
assert(min(Vdc(event))>0.95*G.dc.Vdc_ref_V && ...
    max(Vdc(event))<1.05*G.dc.Vdc_ref_V,'DC-link step excursion exceeds +/-5%.');
assert(max(abs(Ibat(event)))<G.dcdc.Imax_A,'Physical battery current exceeds 1.10 pu.');
assert(max(abs(Iref(event)))<=G.dcdc.Iref_limit_A+1,'Current reference limiter failed.');
assert(min(duty(event))>G.dcdc.duty_min && max(duty(event))<G.dcdc.duty_max, ...
    'Duty-cycle saturation reached.');
assert(max(Iac(event))<G.control.Iac_limit_A,'AC current exceeds 1.20 pu.');
assert(min(acFactor(event))>0.999,'AC limiter operated below rated load.');
assert(SOC(end)<SOC(1) && mean(Pbat(post))>0,'SOC/power direction is invalid.');

fPreExpected=G.f0_Hz-G.control.mp_Hz_per_W*preMean(2);
fPostExpected=G.f0_Hz-G.control.mp_Hz_per_W*postMean(2);
assert(abs(preMean(4)-fPreExpected)<3e-3 && ...
    abs(postMean(4)-fPostExpected)<3e-3,'P-f droop equation mismatch.');
vPostExpected=G.ac.Vll_low_V-G.control.nq_V_per_var*postMean(3)+ ...
    (-G.control.Rvirt_ohm*postMean(2)+G.control.Xvirt_ohm*postMean(3))/G.ac.Vll_low_V;
assert(abs(postMean(5)-vPostExpected)<0.5,'Virtual-impedance voltage equation mismatch.');

outside=find(t>=G.load.step_time_s & abs(Vdc-G.dc.Vdc_ref_V)>0.01*G.dc.Vdc_ref_V);
if isempty(outside),settling=0;else,settling=max(t(outside))-G.load.step_time_s;end
assert(settling<0.25,'DC-link does not settle to 1% within 250 ms.');

fig=figure('Visible','off','Color','w','Position',[100 80 1200 800]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
nexttile;plot(t,P/1e6,'LineWidth',1.2);xline(G.load.step_time_s,'k--');grid on;
xlabel('Time (s)');ylabel('P (MW)');title('4 MW to 5 MW load step');
nexttile;plot(t,f,'LineWidth',1.2);xline(G.load.step_time_s,'k--');grid on;
xlabel('Time (s)');ylabel('Frequency (Hz)');title('GFM P-f response');
nexttile;plot(t,Vcmd,'LineWidth',1.2);xline(G.load.step_time_s,'k--');grid on;
xlabel('Time (s)');ylabel('V command (V)');title('Q-V + virtual impedance');
nexttile;plot(t,Vdc,'LineWidth',1.2);hold on;yline(1500,'k:');
yline(0.95*1500,'r--');yline(1.05*1500,'r--');xline(G.load.step_time_s,'k--');grid on;
xlabel('Time (s)');ylabel('V_{dc} (V)');title('Finite-bandwidth DC-link control');
nexttile;plot(t,Ibat,'LineWidth',1.2);hold on;plot(t,Iref,'--','LineWidth',1.1);
yline(G.dcdc.Imax_A,'r--');xline(G.load.step_time_s,'k--');grid on;
xlim([0.05 t(end)]); ylim([0 1.12*G.dcdc.Imax_A]);
xlabel('Time (s)');ylabel('Current (A)');title('Battery current inner loop');
legend('Measured','Reference','1.10 pu','Location','best');
nexttile;yyaxis left;plot(t,duty,'LineWidth',1.2);ylabel('Duty ratio');
yyaxis right;plot(t,Iac,'LineWidth',1.2);hold on;yline(G.control.Iac_limit_A,'r--');
ylabel('Estimated AC current (A)');xline(G.load.step_time_s,'k--');grid on;
xlabel('Time (s)');title('Duty and AC current margin');
exportgraphics(fig,resultPng,'Resolution',160);close(fig);

fprintf(['BESS_GFM_DYNAMIC_R7_VALIDATION_PASS=1\n' ...
    'PRE P=%.4f MW Q=%.4f Mvar f=%.5f Hz Vdc=%.2f V Ibat=%.1f A\n' ...
    'POST P=%.4f MW Q=%.4f Mvar f=%.5f Hz Vdc=%.2f V Ibat=%.1f A\n' ...
    'EVENT Vdc=[%.2f %.2f] V Ibat_peak=%.1f A Iac_peak=%.1f A ' ...
    'duty=[%.4f %.4f] settling_1pct=%.4f s\nRESULT_PNG=%s\n'], ...
    preMean(2)/1e6,preMean(3)/1e6,preMean(4),preMean(7),preMean(8), ...
    postMean(2)/1e6,postMean(3)/1e6,postMean(4),postMean(7),postMean(8), ...
    min(Vdc(event)),max(Vdc(event)),max(abs(Ibat(event))),max(Iac(event)), ...
    min(duty(event)),max(duty(event)),settling,resultPng);
close_system(modelName,0);
