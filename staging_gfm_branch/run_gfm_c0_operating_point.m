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
vabc=firstTS(logs,'Vabc_PCC_Meas');vcmd=firstTS(logs,'Vll_cmd_V');
tailStart=GFM.StopTime-GFM.ValidationTail_s;
Pmean=tailMean(p,tailStart);Qmean=tailMean(q,tailStart);
fmean=tailMean(f,tailStart);VdcMean=tailMean(vdc,tailStart);
Mpeak=max(abs(m.Data),[],'all');Mtail=tailPeak(m,tailStart);
Ipeak=max(i.Data,[],'all');ThetaEnd=squeeze(theta.Data(end));
VllPCCrms=tailLineRMS(vabc,tailStart);
VcmdMean=tailMean(vcmd,tailStart);
md=squeeze(m.Data);if size(md,1)~=numel(m.Time)&&size(md,2)==numel(m.Time),md=md.';end
MabcEnd=md(end,:);
assert(all(isfinite([Pmean Qmean fmean VdcMean Mpeak Ipeak])),'Non-finite operating point.');
assert(fmean>=49&&fmean<=51,'GFM frequency outside declared limiter.');
assert(Mpeak<=GFM.modulation_max_pu+1e-9,'Modulation limit failed.');
assert(VdcMean>0.9*Converter.Vdc_nom&&VdcMean<1.1*Converter.Vdc_nom,'DC link left nominal band.');
Perror_pu=abs(Pmean-GFM.Pref_W)/GFM.BESS_P_W;
powerOK=Perror_pu<=GFM.P_validation_tolerance_pu;
currentOK=Ipeak<=1.05*GFM.Ipeak_limit_A;
voltageOK=abs(VllPCCrms-Base.Vll_hv)<=GFM.PCC_voltage_tolerance_pu*Base.Vll_hv;
Smean=hypot(Pmean,Qmean);apparentPowerOK=Smean<=GFM.apparent_power_test_margin_pu*GFM.BESS_S_VA;
VdroopExpected=min(max(GFM.Vll_ref_V+GFM.nq_V_per_var*(GFM.Qref_var-Qmean), ...
    GFM.Vll_min_V),GFM.Vll_max_V);
QdroopResidual_V=VcmdMean-VdroopExpected;
qDroopOK=abs(QdroopResidual_V)<1e-3;
results=struct('Model',model,'Simulation','passed','Pmean_MW',Pmean/1e6, ...
    'Qmean_Mvar',Qmean/1e6,'FrequencyMean_Hz',fmean,'VdcMean_V',VdcMean, ...
    'PCCLineVoltageRMS_V',VllPCCrms,'ApparentPower_MVA',Smean/1e6, ...
    'VoltageCommandMean_V',VcmdMean,'QDroopResidual_V',QdroopResidual_V, ...
    'ModulationPeak_pu',Mpeak,'ModulationTailPeak_pu',Mtail, ...
    'ThetaEnd_rad',ThetaEnd,'MabcEnd',MabcEnd,'PCCCurrentPeak_A',Ipeak, ...
    'Perror_pu',Perror_pu,'PowerTransferValidated',powerOK, ...
    'QDroopLawValidated',qDroopOK,'PCCVoltageValidated',voltageOK, ...
    'ApparentPowerValidated',apparentPowerOK,'CurrentLimitValidated',currentOK);
disp(results)
assert(powerOK,'GFM active power error %.3f pu exceeds %.3f pu.', ...
    Perror_pu,GFM.P_validation_tolerance_pu);
assert(currentOK,'GFM peak current %.3f A exceeds allowed test margin.',Ipeak);
assert(voltageOK,'PCC line voltage %.3f V is outside the declared band.',VllPCCrms);
assert(apparentPowerOK,'PCS apparent power %.3f MVA exceeds the test margin.',Smean/1e6);
assert(qDroopOK,'Q-V droop law residual %.6g V is too large.',QdroopResidual_V);
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

function v=tailLineRMS(ts,t0)
t=ts.Time(:);d=squeeze(ts.Data);
if size(d,1)~=numel(t)&&size(d,2)==numel(t),d=d.';end
d=d(t>=t0,:);
vll=[d(:,1)-d(:,2),d(:,2)-d(:,3),d(:,3)-d(:,1)];
v=mean(sqrt(mean(vll.^2,1)));
end
