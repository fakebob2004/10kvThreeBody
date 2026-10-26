%VALIDATE_WIND_DFIG_REUSED_R2 Reuse, structure, power, and sequence checks.
root=fileparts(fileparts(mfilename('fullpath')));model='Wind_DFIG_Reused_R2';
file=fullfile(root,'build',[model '.slx']);assert(isfile(file),'Missing model: %s',file);
run(fullfile(root,'parameters','init_wind_dfig_reused_r2.m'));
load_system(file);cleanup=onCleanup(@()closeIfLoaded(model));

% Reused accepted hierarchy and explicit new boundaries.
required={ ...
    '01 Wind Turbine Aerodynamics', ...
    '02 DFIG and Average RSC', ...
    '03 DC Link and Average GSC', ...
    '04 GFL Control', ...
    '05 Filter Transformer and PCC', ...
    '06 Grid Equivalent and Source'};
for k=1:numel(required),assert(getSimulinkBlockHandle([model '/' required{k}])>0);end
assert(getSimulinkBlockHandle([model '/02 DFIG and Average RSC/02 Wound-Rotor DFIG dq Plant'])>0);
assert(getSimulinkBlockHandle([model '/02 DFIG and Average RSC/03 Rotor-Side Average Converter Control'])>0);
assert(getSimulinkBlockHandle([model '/05 Filter Transformer and PCC/DFIG Stator Average Current Source'])>0);
assert(getSimulinkBlockHandle([model '/05 Filter Transformer and PCC/AC Filter Rf + Lf'])>0);
assert(getSimulinkBlockHandle([model '/05 Filter Transformer and PCC/0.69 kV to 10 kV Step-Up Transformer'])>0);
assert(getSimulinkBlockHandle([model '/03 DC Link and Average GSC/Averaged-Switch Three-Phase Bridge'])>0);
assert(isempty(find_system([model '/02 DFIG and Average RSC'],'RegExp','on','Name','.*(Carrier|Comparator|PWM).*')));
set_param(model,'SimulationCommand','update');

set_param(model,'StopTime','0.20');out=sim(model);logs=out.logsout;
p=getTs(logs,'P_PCC');q=getTs(logs,'Q_PCC');vdc=getTs(logs,'Vdc_Meas');
pr=getTs(logs,'P_rotor_to_dc_W');omega=getTs(logs,'omega_turbine_rad_s');
te=getTs(logs,'T_e_turbine_Nm');inj=getTs(logs,'Iabc_DFIG_stator_injection');
vabc=getTs(logs,'Vabc_PCC_Meas');ipcc=getTs(logs,'Iabc_PCC_Meas');

t0=0.16;P=meanWindow(p,t0);Q=meanWindow(q,t0);Vdc=meanWindow(vdc,t0);
Pr=meanWindow(pr,t0);Omega=meanWindow(omega,t0);Te=meanWindow(te,t0);
[Ipos,Ineg]=sequenceAudit(inj,t0,Base.f);[vv,ii]=alignedPair(vabc,ipcc,t0);
Pabc=mean(sum(vv.*ii,2));
metrics=[P Q Vdc Pr Omega Te Ipos Ineg Pabc];
assert(all(isfinite(metrics)),'Non-finite reused-DFIG result.');
assert(P>3.0e6&&P<5.2e6,'PCC active power is outside the expected 10 m/s range.');
assert(abs(Q)<0.10*Base.Sn,'PCC reactive power exceeds the acceptance band.');
assert(Vdc>1450&&Vdc<1575,'Reused 1500 V DC link is outside its acceptance band.');
assert(Pr<0,'At subsynchronous speed the rotor should absorb power from the DC link.');
assert(Omega>0.8&&Omega<1.4,'Turbine speed is outside the intended range.');
assert(Te<0,'Generating turbine-side electromagnetic torque must be negative.');
assert(Ineg/max(Ipos,eps)<0.02,'DFIG stator injection is not positive-sequence balanced.');
assert(abs(P-Pabc)<0.03*max(abs(P),1),'PCC dq power and direct abc power disagree.');

fprintf('WIND_DFIG_R2_REUSE_STRUCTURE_OK=1\n');
fprintf('WIND_DFIG_R2_POSITIVE_SEQUENCE_OK=1\n');
fprintf('WIND_DFIG_R2_PHYSICAL_POWER_TRANSFER_OK=1\n');
fprintf(['P_PCC_MW=%.6f P_ABC_MW=%.6f Q_PCC_MVAR=%.6f VDC_V=%.3f ' ...
    'P_ROTOR_TO_DC_KW=%.3f OMEGA_TURBINE=%.6f INEG_IPOS=%.8f\n'], ...
    P/1e6,Pabc/1e6,Q/1e6,Vdc,Pr/1e3,Omega,Ineg/max(Ipos,eps));
clear cleanup

function ts=getTs(logs,name)
ts=[];
for k=1:logs.numElements
    e=logs{k};
    if strcmp(e.Name,name)&&isa(e.Values,'timeseries'),ts=e.Values;return,end
end
assert(~isempty(ts),'Missing logged timeseries: %s',name);
end
function y=meanWindow(ts,t0)
x=squeeze(ts.Data);t=ts.Time(:);if size(x,1)~=numel(t),x=x.';end;y=mean(x(t>=t0,:),'all');
end
function [pos,neg]=sequenceAudit(ts,t0,f)
t=ts.Time(:);x=squeeze(ts.Data);if size(x,1)~=numel(t),x=x.';end
keep=t>=t0;t=t(keep);x=x(keep,:);tu=linspace(t(1),t(end),2001).';
x=interp1(t,x,tu,'linear');X=(2/numel(tu))*sum(x.*exp(-1j*2*pi*f*tu),1);
a=exp(1j*2*pi/3);pos=abs((X(1)+a*X(2)+a^2*X(3))/3);neg=abs((X(1)+a^2*X(2)+a*X(3))/3);
end
function [vv,ii]=alignedPair(v,i,t0)
tv=v.Time(:);vv0=squeeze(v.Data);if size(vv0,1)~=numel(tv),vv0=vv0.';end
ti=i.Time(:);ii0=squeeze(i.Data);if size(ii0,1)~=numel(ti),ii0=ii0.';end
t1=max([t0,tv(1),ti(1)]);t2=min(tv(end),ti(end));t=linspace(t1,t2,2001).';
vv=interp1(tv,vv0,t,'linear');ii=interp1(ti,ii0,t,'linear');
end
function closeIfLoaded(model),if bdIsLoaded(model),close_system(model,0);end,end
