% S0 acceptance: strong synchronous-machine source plus GFL sensing/PLL.
% Active/reactive power are deliberately NOT acceptance criteria until the
% derived S1 model closes the dq current loop.
scriptDir=fileparts(mfilename('fullpath')); root=fileparts(scriptDir);
run(fullfile(scriptDir,'init_pv_gfl_sm_commissioning.m'));
model='PV_GFL_Strong_SM_Commissioning';
load_system(fullfile(root,'build',[model '.slx']));
assert(getSimulinkBlockHandle([model '/Strong Synchronous Machine (Governor + AVR)'])>0);
assert(isempty(find_system(model,'SearchDepth',1,'Regexp','on','Name','.*BESS.*')), ...
    'S0 commissioning model must not contain BESS-GFM.');
out=sim(model,'StopTime','0.12'); logs=out.logsout;
omega=tail(logs,'omega_PLL',0.10); vd=tail(logs,'Vd_PLL',0.10);
vq=tail(logs,'Vq_PLL',0.10); p=tail(logs,'P_PCC',0.10); q=tail(logs,'Q_PCC',0.10);
f=mean(omega)/(2*pi); vdMean=mean(vd); vqMean=mean(vq);
assert(f>45&&f<55,'PLL frequency left its explicit operating limits.');
assert(abs(vqMean)<0.06*abs(vdMean),'PLL q-axis error exceeds 6%% of d axis.');
assert(all(isfinite([f vdMean vqMean mean(p) mean(q)])),'S0 telemetry is non-finite.');
fprintf(['PV_GFL_SM_S0_PLL_PASS=1 f=%.4f Hz Vd=%.2f V Vq=%.2f V ' ...
    'P_openloop=%.3f MW Q_openloop=%.3f Mvar\n'], ...
    f,vdMean,vqMean,mean(p)/1e6,mean(q)/1e6);
fprintf('CURRENT_LOOP_ACCEPTANCE_PENDING=1\n');
close_system(model,0);

function d=tail(logs,name,t0)
e=logs.get(name); ts=e.Values; t=ts.Time(:); d=squeeze(ts.Data);
if size(d,1)~=numel(t),d=d.';end
d=d(t>=t0,:); d=d(:);
end
