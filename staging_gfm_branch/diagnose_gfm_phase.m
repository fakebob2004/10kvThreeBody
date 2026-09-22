function results=diagnose_gfm_phase
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
model='GFM_Inverter_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
out=sim(Simulink.SimulationInput(model).setModelParameter('StopTime','GFM.StopTime'));
logs=out.logsout;
vll=ts(logs,'Vll_inv');vpcc=ts(logs,'Vabc_PCC_Meas');ipcc=ts(logs,'Iabc_PCC_Meas');
p=ts(logs,'P_PCC_W');theta=ts(logs,'theta_GFM_rad');
[VinvMag,VinvDeg]=phasor(vll,1,Base.omega,GFM.StopTime-1/Base.f);
[VpccMag,VpccDeg]=phasor(vpcc,1,Base.omega,GFM.StopTime-1/Base.f);
[IpccMag,IpccDeg]=phasor(ipcc,1,Base.omega,GFM.StopTime-1/Base.f);
results=struct('VinvVabFundRMS_V',VinvMag,'VinvVabPhase_deg',VinvDeg, ...
    'VpccVaFundRMS_V',VpccMag,'VpccVaPhase_deg',VpccDeg, ...
    'IpccIaFundRMS_A',IpccMag,'IpccIaPhase_deg',IpccDeg, ...
    'PowerMin_MW',min(p.Data,[],'all')/1e6,'PowerMax_MW',max(p.Data,[],'all')/1e6, ...
    'ThetaEnd_rad',theta.Data(end));
disp(results)
end

function out=ts(logs,name)
e=logs.get(name);if isa(e,'Simulink.SimulationData.Dataset'),e=e.getElement(1);end
out=e.Values;
end

function [rmsValue,phaseDeg]=phasor(x,k,w,t0)
t=x.Time(:);d=squeeze(x.Data);if size(d,1)~=numel(t),d=d.';end
use=t>=t0;tt=t(use);xx=d(use,k);
c=2/(tt(end)-tt(1))*trapz(tt,xx.*exp(-1j*w*tt));
rmsValue=abs(c)/sqrt(2);phaseDeg=rad2deg(angle(c));
end
