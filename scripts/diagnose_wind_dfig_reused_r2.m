%DIAGNOSE_WIND_DFIG_REUSED_R2 Phase, sign, and power audit for reused R2.
root=fileparts(fileparts(mfilename('fullpath')));model='Wind_DFIG_Reused_R2';
run(fullfile(root,'parameters','init_wind_dfig_reused_r2.m'));
load_system(fullfile(root,'build',[model '.slx']));cleanup=onCleanup(@()closeIfLoaded(model));
set_param(model,'StopTime','0.20');out=sim(model);logs=out.logsout;
fprintf('LOG CONTENTS\n');
for k=1:logs.numElements
    e=logs{k};fprintf('%s | %s\n',e.Name,class(e.Values));
end
names={'P_PCC','Q_PCC','Vdc_Meas','P_rotor_to_dc_W', ...
    'omega_turbine_rad_s','T_e_turbine_Nm','Iabc_DFIG_stator_injection', ...
    'Vabc_PCC_Meas','Iabc_PCC_Meas'};
for k=1:numel(names)
    ts=firstTimeseries(logs,names{k});
    if isempty(ts),fprintf('%s MISSING\n',names{k});continue,end
    x=window(ts,0.16);fprintf('%s mean=',names{k});fprintf(' %.9g',mean(x,1));
    fprintf(' rms=');fprintf(' %.9g',sqrt(mean(x.^2,1)));fprintf('\n');
end
v=firstTimeseries(logs,'Vabc_PCC_Meas');i=firstTimeseries(logs,'Iabc_DFIG_stator_injection');
if ~isempty(v)&&~isempty(i)
    [V,I]=fundamentalPair(v,i,0.16,Base.f);
    fprintf('PHASE_A_V_DEG=%.6f PHASE_A_I_DEG=%.6f I_MINUS_V_DEG=%.6f\n', ...
        angle(V(1))*180/pi,angle(I(1))*180/pi,wrapDeg(angle(I(1)/V(1))*180/pi));
end
ipcc=firstTimeseries(logs,'Iabc_PCC_Meas');
if ~isempty(v)&&~isempty(ipcc)
    [V,Ip]=fundamentalPair(v,ipcc,0.16,Base.f);
    fprintf('PCC_I_MINUS_V_DEG=%.6f\n',wrapDeg(angle(Ip(1)/V(1))*180/pi));
    [vv,ii]=alignedPair(v,ipcc,0.16);
    fprintf('DIRECT_ABC_P_W=%.9g\n',mean(sum(vv.*ii,2)));
end
clear cleanup

function ts=firstTimeseries(logs,name)
ts=[];
for k=1:logs.numElements
    e=logs{k};
    if strcmp(e.Name,name)
        if isa(e.Values,'timeseries'),ts=e.Values;return,end
        if isa(e.Values,'Simulink.SimulationData.Dataset')
            for j=1:e.Values.numElements
                q=e.Values{j};if isa(q.Values,'timeseries'),ts=q.Values;return,end
            end
        end
    end
end
end
function x=window(ts,t0)
x=squeeze(ts.Data);t=ts.Time(:);if size(x,1)~=numel(t),x=x.';end;x=x(t>=t0,:);
end
function [V,I]=fundamentalPair(v,i,t0,f)
tv=v.Time(:);vv=squeeze(v.Data);if size(vv,1)~=numel(tv),vv=vv.';end
ti=i.Time(:);ii=squeeze(i.Data);if size(ii,1)~=numel(ti),ii=ii.';end
t1=max([t0,tv(1),ti(1)]);t2=min(tv(end),ti(end));t=linspace(t1,t2,2001).';
vv=interp1(tv,vv,t,'linear');ii=interp1(ti,ii,t,'linear');
V=(2/numel(t))*sum(vv.*exp(-1j*2*pi*f*t),1);
I=(2/numel(t))*sum(ii.*exp(-1j*2*pi*f*t),1);
end
function [vv,ii]=alignedPair(v,i,t0)
tv=v.Time(:);vv0=squeeze(v.Data);if size(vv0,1)~=numel(tv),vv0=vv0.';end
ti=i.Time(:);ii0=squeeze(i.Data);if size(ii0,1)~=numel(ti),ii0=ii0.';end
t1=max([t0,tv(1),ti(1)]);t2=min(tv(end),ti(end));t=linspace(t1,t2,2001).';
vv=interp1(tv,vv0,t,'linear');ii=interp1(ti,ii0,t,'linear');
end
function x=wrapDeg(x),x=mod(x+180,360)-180;end
function closeIfLoaded(model),if bdIsLoaded(model),close_system(model,0);end,end
