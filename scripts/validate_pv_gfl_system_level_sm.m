% Regression acceptance for the standalone system-level PV-GFL model.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
model='PV_GFL_864_SystemLevel_SM_R2';
load_system(fullfile(root,'build',[model '.slx']));
run(fullfile(scriptDir,'init_pv_gfl_864_average_sm.m'));
b=[model '/02 Commissioning Command Profile/'];

R=struct();
R.zero=run_case(model,b,0,0,0,0.35,[0.25 0.35]);
assert(abs(R.zero.P_MW)<0.12,'Zero-power active-power leakage is too large.');
assert(abs(R.zero.Q_Mvar)<0.12,'Zero-power reactive-power compensation is too large.');

R.p02=run_case(model,b,2e6,0,0,0.65,[0.55 0.65]);
assert(abs(R.p02.P_MW-2)<0.16,'0-to-2 MW tracking error exceeds 8%%.');
assert(abs(R.p02.Q_Mvar)<0.15,'Q coupling during 2 MW export is too large.');

R.p23=run_case(model,b,2e6,1e6,0,0.85,[0.75 0.85]);
assert(abs(R.p23.P_MW-3)<0.24,'2-to-3 MW tracking error exceeds 8%%.');
assert(abs(R.p23.Q_Mvar)<0.15,'Q coupling after 3 MW step is too large.');

R.q01=run_case(model,b,2e6,0,1e6,0.85,[0.75 0.85]);
assert(abs(R.q01.P_MW-2)<0.16,'P coupling during Q step exceeds 8%%.');
assert(abs(R.q01.Q_Mvar-1)<0.10,'0-to-1 Mvar tracking error exceeds 0.10 Mvar.');

cases=fieldnames(R);
for k=1:numel(cases)
    r=R.(cases{k});
    assert(r.f_Hz>48.5&&r.f_Hz<50.5,'Strong-machine frequency left commissioning band.');
    assert(r.Iref_A<=1.001*S1.control.Ilimit_A,'Current reference exceeded PCS limit.');
    fprintf('%-5s P=%7.4f MW Q=%7.4f Mvar f=%7.4f Hz phaseErr=%7.4f rad Iref=%7.1f A\n', ...
        upper(cases{k}),r.P_MW,r.Q_Mvar,r.f_Hz,r.phase_error_rad,r.Iref_A);
end
fprintf('PV_GFL_SYSTEM_LEVEL_ACCEPTANCE_PASS=1\n');
close_system(model,0);

function r=run_case(model,b,pBase,pStep,qStep,tStop,window)
set_param([b 'P Base Limit'],'UpperLimit',num2str(pBase,16));
set_param([b 'P Increment'],'After',num2str(pStep,16),'Time','0.30');
set_param([b 'Q Increment'],'After',num2str(qStep,16),'Time','0.30');
set_param(model,'StopTime',num2str(tStop,16));
o=sim(model);x=o.get('gfl_r2_status');t=x(:,1);k=t>=window(1)&t<=window(2);
r.P_MW=mean(x(k,2))/1e6;r.Q_Mvar=mean(x(k,3))/1e6;
r.f_Hz=mean(x(k,7));r.phase_error_rad=rms(x(k,11));
r.Iref_A=max(hypot(x(k,8),x(k,9)));
end
