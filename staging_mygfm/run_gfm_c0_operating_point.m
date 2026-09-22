function results=run_gfm_c0_operating_point
%RUN_GFM_C0_OPERATING_POINT 40 ms detailed-switching sanity check.
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
model='GFM_Inverter_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
simIn=Simulink.SimulationInput(model);simIn=setModelParameter(simIn,'StopTime','GFM.StopTime');
out=sim(simIn);logs=out.logsout;
p=firstTS(logs,'P_PCC_W');q=firstTS(logs,'Q_PCC_var');f=firstTS(logs,'frequency_GFM_Hz');
vdc=firstTS(logs,'Vdc_Meas');m=firstTS(logs,'mabc_limited');i=firstTS(logs,'Ipeak_PCC_A');
theta=firstTS(logs,'theta_GFM_rad');
Pmean=tailMean(p,GFM.StopTime-0.01);Qmean=tailMean(q,GFM.StopTime-0.01);
fmean=tailMean(f,GFM.StopTime-0.01);VdcMean=tailMean(vdc,GFM.StopTime-0.01);
Mpeak=max(abs(m.Data),[],'all');Mtail=tailPeak(m,GFM.StopTime-0.01);
Ipeak=max(i.Data,[],'all');ThetaEnd=squeeze(theta.Data(end));
md=squeeze(m.Data);if size(md,1)~=numel(m.Time)&&size(md,2)==numel(m.Time),md=md.';end
MabcEnd=md(end,:);
assert(all(isfinite([Pmean Qmean fmean VdcMean Mpeak Ipeak])),'Non-finite operating point.');
assert(fmean>=49&&fmean<=51,'GFM frequency outside declared limiter.');
assert(Mpeak<=GFM.modulation_max_pu+1e-9,'Modulation limit failed.');
assert(VdcMean>0.9*Converter.Vdc_nom&&VdcMean<1.1*Converter.Vdc_nom,'DC link left nominal band.');
results=struct('Model',model,'Simulation','passed','Pmean_MW',Pmean/1e6, ...
    'Qmean_Mvar',Qmean/1e6,'FrequencyMean_Hz',fmean,'VdcMean_V',VdcMean, ...
    'ModulationPeak_pu',Mpeak,'ModulationTailPeak_pu',Mtail, ...
    'ThetaEnd_rad',ThetaEnd,'MabcEnd',MabcEnd,'PCCCurrentPeak_A',Ipeak);
results.PowerTransferValidated=abs(Pmean)>0.1*GFM.Pref_W;
disp(results)
if ~results.PowerTransferValidated
    warning('GFM:C0:NoPowerTransfer', ...
        'Control executes, but the inherited B1 AC plant transfers negligible power.');
end
end

function ts=firstTS(logs,name)
e=logs.get(name);assert(~isempty(e),'Missing logged signal: %s',name);
if isa(e,'Simulink.SimulationData.Dataset'),e=e.getElement(1);end
ts=e.Values;
end

function v=tailMean(ts,t0)
t=ts.Time(:);d=squeeze(ts.Data);
if size(d,1)~=numel(t)&&size(d,2)==numel(t),d=d.';end
assert(size(d,1)==numel(t),'Logged data/time dimensions do not match.');
v=mean(d(t>=t0,:),'all');
end

function v=tailPeak(ts,t0)
t=ts.Time(:);d=squeeze(ts.Data);
if size(d,1)~=numel(t)&&size(d,2)==numel(t),d=d.';end
v=max(abs(d(t>=t0,:)),[],'all');
end
