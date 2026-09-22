function trace=debug_gfm_trace
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
model='GFM_Inverter_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
stopTime=0.12;
out=sim(Simulink.SimulationInput(model).setModelParameter('StopTime',num2str(stopTime)));
logs=out.logsout;
vts=ts(logs,'Vabc_PCC_Meas');its=ts(logs,'Iabc_PCC_Meas');
v=rows(vts);i=rows(its);praw=sum(v.*i,2);
K=sqrt(2/3)*[1 -0.5 -0.5;0 sqrt(3)/2 -sqrt(3)/2].';
vab=v*K;iab=i*K;qraw=vab(:,2).*iab(:,1)-vab(:,1).*iab(:,2);
pts=(0.01:0.01:stopTime).';n=numel(pts);
trace=table(pts,zeros(n,1),zeros(n,1),zeros(n,1),zeros(n,1),zeros(n,1),zeros(n,1),zeros(n,1), ...
    'VariableNames',{'Time_s','Praw_MW','Pfiltered_MW','Qraw_Mvar','Qfiltered_Mvar', ...
    'VllCmd_V','Ipeak_A','Frequency_Hz'});
p=ts(logs,'P_PCC_W');q=ts(logs,'Q_PCC_var');vcmd=ts(logs,'Vll_cmd_V');
ip=ts(logs,'Ipeak_PCC_A');f=ts(logs,'frequency_GFM_Hz');
theta=ts(logs,'theta_GFM_rad');
for k=1:n
    t0=max(0,pts(k)-0.001);use=vts.Time>=t0&vts.Time<=pts(k);
    trace.Praw_MW(k)=mean(praw(use))/1e6;
    trace.Pfiltered_MW(k)=sample(p,pts(k))/1e6;
    trace.Qraw_Mvar(k)=mean(qraw(use))/1e6;
    trace.Qfiltered_Mvar(k)=sample(q,pts(k))/1e6;
    trace.VllCmd_V(k)=sample(vcmd,pts(k));
    trace.Ipeak_A(k)=sample(ip,pts(k));
    trace.Frequency_Hz(k)=sample(f,pts(k));
end
disp(trace)
vll=ts(logs,'Vll_inv');
[vscRms,vscPhase]=fundamental(vll,1,Base.omega,stopTime-1/Base.f);
[pccRms,pccPhase]=fundamental(vts,1,Base.omega,stopTime-1/Base.f);
fprintf('TAIL_FUNDAMENTALS VSC_Vab_RMS=%.3f phase=%.3fdeg PCC_Va_RMS=%.3f phase=%.3fdeg theta=%.6f\n', ...
    vscRms,vscPhase,pccRms,pccPhase,sample(theta,stopTime));
end

function out=ts(logs,name)
e=logs.get(name);assert(~isempty(e),'Missing signal %s',name);
if isa(e,'Simulink.SimulationData.Dataset'),e=e.getElement(1);end
out=e.Values;
end
function x=rows(x)
if isa(x,'timeseries'),x=x.Data;end
x=squeeze(x);if isvector(x),x=x(:);return,end
if size(x,1)<=6&&size(x,2)>size(x,1),x=x.';end
end
function y=sample(x,t)
d=rows(x);[~,idx]=min(abs(x.Time-t));y=d(idx,1);
end
function [rmsValue,phaseDeg]=fundamental(x,k,w,t0)
t=x.Time(:);d=rows(x);use=t>=t0;tt=t(use);xx=d(use,k);
A=[sin(w*tt) cos(w*tt) ones(size(tt))];c=A\xx;
rmsValue=hypot(c(1),c(2))/sqrt(2);phaseDeg=rad2deg(atan2(c(2),c(1)));
end
