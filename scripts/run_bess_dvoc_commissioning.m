function run_bess_dvoc_commissioning()
%RUN_BESS_DVOC_COMMISSIONING Independent physical-model commissioning.
root=setup_v2_paths();out=fullfile(root,'artifacts','bess_dvoc');
f=fullfile(root,'models','resources','bess_resource_dvoc.slx');load_system(f);
o=sim('bess_resource_dvoc','StopTime','0.8');r=o.get('bess_v2_result');
assert(all(isfinite(r),'all'),'Nonfinite physical-model result');
names={'time_s','P_W','Q_var','Vpcc_V','frequency_Hz','available_power_W', ...
    'power_headroom_W','current_limit_factor','SOC','Vdc_V','control_mode','healthy'};
save(fullfile(out,'commissioning.mat'),'r','names');
writetable(array2table(r,'VariableNames',names),fullfile(out,'commissioning.csv'));
before=r(:,1)>.24&r(:,1)<.29;after=r(:,1)>.7;
fprintf('DVOC_PHYSICAL preP=%.5fMW postP=%.5fMW tailV=%.2fV tailF=%.5fHz minLimit=%.5f\n', ...
    mean(r(before,2))/1e6,mean(r(after,2))/1e6,mean(r(after,4)),mean(r(after,5)),min(r(:,8)));
fig=figure('Visible','off','Position',[20 20 1200 780]);tiledlayout(3,2);
nexttile;plot(r(:,1),r(:,2:3)/1e6);legend('P MW','Q Mvar');grid on;
nexttile;plot(r(:,1),r(:,4)/1e3);ylabel('PCC kV');grid on;
nexttile;plot(r(:,1),r(:,5));ylabel('Oscillator Hz');grid on;
nexttile;plot(r(:,1),r(:,8));ylabel('Common protection factor');grid on;
nexttile;plot(r(:,1),r(:,9)*100);ylabel('Equivalent SOC %');grid on;
nexttile;plot(r(:,1),r(:,10));ylabel('Idealized DC V');grid on;
sgtitle('BESS dVOC physical commissioning | retained engineering protection | not frozen N2');
exportgraphics(fig,fullfile(out,'commissioning.png'),'Resolution',150);close(fig);
% Initial engineering gate; this is not complete fault/limit certification.
assert(abs(mean(r(before,2))-4e6)<.08*4e6,'Pre-step active power failed');
assert(abs(mean(r(after,2))-5e6)<.08*5e6,'Post-step active power failed');
assert(all(r(after,4)>9000 & r(after,4)<11000),'Tail voltage outside 10%%');
assert(all(abs(r(after,5)-50)<1),'Tail frequency outside 1 Hz');
close_system('bess_resource_dvoc',0);
fprintf('BESS_DVOC_INITIAL_COMMISSIONING_PASS=1\n');
end
