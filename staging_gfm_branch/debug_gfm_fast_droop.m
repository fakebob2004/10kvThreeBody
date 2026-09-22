function results=debug_gfm_fast_droop
% Temporary commissioning diagnostic: accelerate angle sweep without saving.
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
model='GFM_Inverter_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
set_param(model,'InitFcn','');
base=[model '/GFM Controller/02 P-f Droop and Angle/'];
set_param([base 'P-f Droop'],'Gain','2*pi*5/GFM.BESS_P_W');
set_param([base 'Omega Limits'],'LowerLimit','2*pi*45','UpperLimit','2*pi*55');
simIn=Simulink.SimulationInput(model);
simIn=setModelParameter(simIn,'StopTime','0.012');
out=sim(simIn);logs=out.logsout;
vts=ts(logs,'Vabc_PCC_Meas');its=ts(logs,'Iabc_PCC_Meas');
v=rows(vts);i=rows(its);praw=sum(v.*i,2);use=vts.Time>=0.009;
p=rows(ts(logs,'P_PCC_W'));q=rows(ts(logs,'Q_PCC_var'));
f=rows(ts(logs,'frequency_GFM_Hz'));ip=rows(ts(logs,'Ipeak_PCC_A'));
m=rows(ts(logs,'mabc_limited'));theta=rows(ts(logs,'theta_GFM_rad'));
results=struct('PrawTail_MW',mean(praw(use))/1e6, ...
    'PrawPeak_MW',max(abs(praw))/1e6,'PfilteredEnd_MW',p(end)/1e6, ...
    'QfilteredEnd_Mvar',q(end)/1e6,'FrequencyEnd_Hz',f(end), ...
    'PCCCurrentPeak_A',max(ip),'ModulationPeak_pu',max(abs(m),[],'all'), ...
    'ThetaEnd_rad',theta(end));
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
