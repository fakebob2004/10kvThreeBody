function results=run_gfm_island_load_test
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
model='GFM_Island_Load_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
out=sim(Simulink.SimulationInput(model).setModelParameter('StopTime','GFM.StopTime'));
logs=out.logsout;tailStart=GFM.StopTime-GFM.ValidationTail_s;
p=firstTS(logs,'P_PCC_W');q=firstTS(logs,'Q_PCC_var');
f=firstTS(logs,'frequency_GFM_Hz');v=firstTS(logs,'Vabc_PCC_Meas');
i=firstTS(logs,'Ipeak_PCC_A');m=firstTS(logs,'mabc_limited');
Pmean=tailMean(p,tailStart);Qmean=tailMean(q,tailStart);
Fmean=tailMean(f,tailStart);VllRMS=tailLineRMS(v,tailStart);
Ipeak=max(i.Data,[],'all');Mpeak=max(abs(m.Data),[],'all');
Smean=hypot(Pmean,Qmean);
Perror=abs(Pmean-GFM.IslandLoad_P_W)/GFM.IslandLoad_P_W;
results=struct('Model',model,'Simulation','passed','Pmean_MW',Pmean/1e6, ...
    'Qmean_Mvar',Qmean/1e6,'FrequencyMean_Hz',Fmean, ...
    'PCCLineVoltageRMS_V',VllRMS,'Perror_pu',Perror, ...
    'ApparentPower_MVA',Smean/1e6,'PCCCurrentPeak_A',Ipeak, ...
    'ModulationPeak_pu',Mpeak);
results.PowerValidated=Perror<=0.10;
results.FrequencyValidated=Fmean>=49&&Fmean<=51;
results.VoltageValidated=abs(VllRMS-Base.Vll_hv)<=0.10*Base.Vll_hv;
results.ApparentPowerValidated=Smean<=GFM.apparent_power_test_margin_pu*GFM.BESS_S_VA;
results.CurrentValidated=Ipeak<=1.05*GFM.Ipeak_limit_A;
disp(results)
assert(results.PowerValidated,'Island load power error %.3f pu.',Perror);
assert(results.FrequencyValidated,'Island frequency %.3f Hz is out of range.',Fmean);
assert(results.VoltageValidated,'Island PCC voltage %.3f V is out of range.',VllRMS);
assert(results.ApparentPowerValidated,'Island apparent power exceeds PCS rating.');
assert(results.CurrentValidated,'Island peak current exceeds the declared limit.');
end

function ts=firstTS(logs,name)
e=logs.get(name);assert(~isempty(e),'Missing signal %s',name);
if isa(e,'Simulink.SimulationData.Dataset'),e=e.getElement(1);end
ts=e.Values;
end
function val=tailMean(ts,t0)
t=ts.Time(:);d=squeeze(ts.Data);if size(d,1)~=numel(t),d=d.';end
val=mean(d(t>=t0,:),'all');
end
function val=tailLineRMS(ts,t0)
t=ts.Time(:);d=squeeze(ts.Data);if size(d,1)~=numel(t),d=d.';end
d=d(t>=t0,:);vll=[d(:,1)-d(:,2),d(:,2)-d(:,3),d(:,3)-d(:,1)];
val=mean(sqrt(mean(vll.^2,1)));
end
