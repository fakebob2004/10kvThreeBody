function results=debug_gfm_delta_sweep
% Temporary commissioning diagnostic: freeze droop and identify P(delta).
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
model='GFM_Inverter_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
set_param(model,'InitFcn','');
pf=[model '/GFM Controller/02 P-f Droop and Angle/P-f Droop'];
angle=[model '/GFM Controller/02 P-f Droop and Angle/Angle Integrator'];
qv=[model '/GFM Controller/03 Q-V Droop and Magnitude/Q-V Droop'];
set_param(pf,'Gain','0');set_param(qv,'Gain','0');
deltas=[-0.15 0 0.15];
results=table('Size',[numel(deltas) 7], ...
    'VariableTypes',repmat({'double'},1,7), ...
    'VariableNames',{'Delta_rad','Praw_MW','Qraw_Mvar','Pfiltered_MW', ...
    'Ipeak_A','VllPeak_V','ThetaEnd_rad'});
for k=1:numel(deltas)
    set_param(angle,'InitialCondition',num2str(deltas(k),17));
    simIn=Simulink.SimulationInput(model);
    simIn=setModelParameter(simIn,'StopTime','0.006');
    out=sim(simIn);logs=out.logsout;
    v=rows(ts(logs,'Vabc_PCC_Meas'));i=rows(ts(logs,'Iabc_PCC_Meas'));
    t=ts(logs,'Vabc_PCC_Meas').Time(:);
    use=t>=0.004;
    p=sum(v.*i,2);
    [va,ia]=clarke(v,i);
    q=va(:,2).*ia(:,1)-va(:,1).*ia(:,2);
    pfiltTs=ts(logs,'P_PCC_W');pfilt=rows(pfiltTs);
    ip=rows(ts(logs,'Ipeak_PCC_A'));
    vll=rows(ts(logs,'Vll_inv'));
    theta=rows(ts(logs,'theta_GFM_rad'));
    results{k,:}={deltas(k),mean(p(use))/1e6,mean(q(use))/1e6, ...
        mean(pfilt(pfiltTs.Time>=0.004))/1e6,max(ip,[],'all'),max(abs(vll),[],'all'),theta(end)};
end
disp(results)
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

function [vab,iab]=clarke(v,i)
K=sqrt(2/3)*[1 -0.5 -0.5;0 sqrt(3)/2 -sqrt(3)/2].';
vab=v*K;iab=i*K;
end
