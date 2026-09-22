% Full Phase-A acceptance for readable PV-GFL R2.1.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
if exist('PV_GFL_MODEL_OVERRIDE','var')&&strlength(string(PV_GFL_MODEL_OVERRIDE))>0
    model=char(PV_GFL_MODEL_OVERRIDE);
else
    model='PV_GFL_864_SystemLevel_SM_R2_1_Readable';
end
load_system(fullfile(root,'build',[model '.slx']));run(fullfile(scriptDir,'init_pv_gfl_r2_1.m'));
profile=[model '/02 Commissioning Command Profile/'];

% Architecture gate: exactly CommandBus, StatusBus, PCC_10kV externally.
if exist('PV_GFL_BRANCH_OVERRIDE','var')&&strlength(string(PV_GFL_BRANCH_OVERRIDE))>0
    pv=[model '/' char(PV_GFL_BRANCH_OVERRIDE)];
else
    pv=[model '/01 PV-GFL Branch R2.1'];
end
ph=get_param(pv,'PortHandles');
assert(numel(ph.Inport)==1&&numel(ph.Outport)==1&&numel([ph.LConn ph.RConn])==1, ...
    'PV branch must expose exactly CommandBus, StatusBus, and PCC_10kV.');
assert(getSimulinkBlockHandle([pv '/01 GFL PCS/01 Secondary Control/02 Local SRF-PLL'])>0);
assert(getSimulinkBlockHandle([pv '/02 Step-up and PCC/PCC 10kV VI Sensor'])>0);
assert(getSimulinkBlockHandle([pv '/01 GFL PCS/01 Secondary Control/Current Circle Factor'])>0);

Qpf=5e6*tan(acos(0.90));
R=struct();
R.A=run_case(model,profile,'A_ZERO',0,0,0,0,10,11,0,.50,.30);
assert(abs(R.A.ss.P)<.12e6&&abs(R.A.ss.Q)<.12e6,'Case A zero P/Q failed.');

R.B=run_case(model,profile,'B_0_TO_2MW',2e6,0,0,0,10,11,0,.75,.30);
assert_track(R.B,2e6,0,.08,.15e6);
assert(R.B.dynamic.settling_P_s<.40,'Case B P settling time failed.');

R.C=run_case(model,profile,'C_2_TO_3MW',2e6,1e6,0,0,10,11,0,.90,.30);
assert_track(R.C,3e6,0,.08,.15e6);
assert(R.C.dynamic.settling_P_s<.40,'Case C P settling time failed.');

R.D=run_case(model,profile,'D_Q_STEP',2e6,0,0,1e6,10,11,0,.90,.30);
assert_track(R.D,2e6,1e6,.08,.10e6);
assert(R.D.dynamic.settling_Q_s<.40,'Case D Q settling time failed.');

% Here enable is converter_enable, not a PCC breaker command.  The current
% command becomes zero while the still-connected shunt filter retains its
% physically expected reactive power (Qpassive = omega*C*Vll_low^2).
R.E=run_case(model,profile,'E_ENABLE_1_0_1',2e6,0,0,0,.30,.55,1,.95,.55);
x=R.E.x;t=x(:,1);off=t>.40&t<.52;rec=t>.80;
fprintf('Case E windows: off P/Q/enable=%g/%g/%g, recovery P/Q/enable=%g/%g/%g\n', ...
    mean(x(off,2)),mean(x(off,3)),mean(x(off,16)), ...
    mean(x(rec,2)),mean(x(rec,3)),mean(x(rec,16)));
VllLow=mean(x(off,15))*S1.pv.Vll_low_V/S1.pv.Vll_high_V;
Qpassive=2*pi*S1.base.f_Hz*S1.filter.C_F*VllLow^2;
IrefOff=max(hypot(x(off,8),x(off,9)));
IactualOff=mean(x(off,12));phaseOff=rms(x(off,11));fOff=mean(x(off,7));
fprintf('Case E converter-off: Qmeas/Qpassive=%g/%g var, Iref max=%g A, Iactual mean=%g A, phase rms=%g rad, f=%g Hz\n', ...
    mean(x(off,3)),Qpassive,IrefOff,IactualOff,phaseOff,fOff);
assert(abs(mean(x(off,2)))<.15e6,'Case E converter disable did not suppress active injection.');
assert(IrefOff<1,'Case E converter disable did not zero the dq current command.');
assert(abs(mean(x(off,3))-Qpassive)<max(.15*abs(Qpassive),.05e6), ...
    'Case E disabled Q is inconsistent with the connected passive filter.');
assert(phaseOff<.15&&fOff>48&&fOff<51,'Case E PLL did not remain locked while converter was disabled.');
assert(abs(mean(x(rec,2))-2e6)<.16e6&&abs(mean(x(rec,3)))<.15e6,'Case E recovery failed.');
assert(mean(x(off,16))<.05&&mean(x(rec,16))>.95,'Case E enable telemetry failed.');

R.F=run_case(model,profile,'F_RATED_P',5e6,0,0,0,10,11,0,1.05,.30);
assert_track(R.F,5e6,0,.08,.20e6);

R.G=run_case(model,profile,'G_PF_0P9',5e6,0,Qpf,0,10,11,0,1.10,.30);
assert_track(R.G,5e6,Qpf,.08,.20e6);
assert(hypot(R.G.ss.P,R.G.ss.Q)<6.25e6,'Case G exceeded PCS apparent-power rating.');

R.H=run_case(model,profile,'H_CIRCLE_LIMIT',8e6,0,6e6,0,10,11,0,1.00,.30);
assert(R.H.ss.limit_factor<.98&&R.H.ss.limit_active>.5,'Case H did not activate circle limit.');
assert(R.H.dynamic.Iref_peak<=1.001*S21.control.Ilimit_peak_A,'Case H dq command exceeded circle limit.');
assert(R.H.dynamic.Iactual_peak<=1.03*S21.control.Ilimit_peak_A,'Case H actual current exceeded limit.');

% Common dynamic/PLL/current assertions.  Do not loosen original P/Q bands.
names=fieldnames(R);
for k=1:numel(names),print_case(R.(names{k}));end
for k=1:numel(names)
    r=R.(names{k});
    assert(all(isfinite(r.x),'all'),['Non-finite telemetry in case ' names{k}]);
    assert(r.ss.phase_rms<.15,['Steady PLL phase error failed in case ' names{k}]);
    assert(r.dynamic.phase_peak<.45,['Transient PLL phase error failed in case ' names{k}]);
    assert(r.dynamic.Iactual_peak<=1.03*S21.control.Ilimit_peak_A, ...
        ['Actual current limit failed in case ' names{k}]);
    assert(r.dynamic.Iref_peak<=1.001*S21.control.Ilimit_peak_A, ...
        ['Reference current limit failed in case ' names{k}]);
    assert(r.dynamic.Vband_settling_s<.35&&r.dynamic.Vtail_min>.85*10e3&&r.dynamic.Vtail_max<1.10*10e3, ...
        ['PCC voltage dwell/tail band failed in case ' names{k}]);
    assert(r.dynamic.fband_settling_s<.35&&r.dynamic.ftail_min>48&&r.dynamic.ftail_max<51, ...
        ['Frequency dwell/tail band failed in case ' names{k}]);
end
fprintf('PV_GFL_R2_1_STANDALONE_ACCEPTANCE_PASS=1\n');
close_system(model,0);

function r=run_case(model,prefix,name,pBase,pStep,qBase,qStep,tOff,tOn,drop,tStop,event)
set_param([prefix 'P Base Limit'],'UpperLimit',num2str(pBase,16));
set_param([prefix 'P Increment'],'After',num2str(pStep,16),'Time','.30');
set_param([prefix 'Q Base Command'],'Value',num2str(qBase,16));
set_param([prefix 'Q Increment'],'After',num2str(qStep,16),'Time','.30');
set_param([prefix 'Enable Off'],'Time',num2str(tOff,16),'After',num2str(-drop,16));
set_param([prefix 'Enable On'],'Time',num2str(tOn,16),'After',num2str(drop,16));
set_param(model,'StopTime',num2str(tStop,16));o=sim(model);x=o.get('gfl_r2_status');
t=x(:,1);ss=t>max(.1,tStop-.12);raw=t>.05;
% Voltage/frequency quality is assessed only after the standalone strong
% source and PLL have established synchronization.  Use a one-cycle mean
% so solver samples and fundamental ripple do not masquerade as excursions.
qualityStart=max(.25,event-.05);quality=t>=qualityStart;
r.name=name;r.x=x;r.ss.P=mean(x(ss,2));r.ss.Q=mean(x(ss,3));
r.ss.f=mean(x(ss,7));r.ss.phase_rms=rms(x(ss,11));
r.ss.limit_factor=mean(x(ss,13));r.ss.limit_active=mean(x(ss,14));
r.dynamic.Pmin=min(x(quality,2));r.dynamic.Pmax=max(x(quality,2));
r.dynamic.Qmin=min(x(quality,3));r.dynamic.Qmax=max(x(quality,3));
vb=cycle_band(t,x(:,15),qualityStart,event,.85*10e3,1.10*10e3);
fb=cycle_band(t,x(:,7),qualityStart,event,48,51);
r.dynamic.Vmin=vb.avg_min;r.dynamic.Vmax=vb.avg_max;
r.dynamic.Vraw_min=vb.raw_min;r.dynamic.Vraw_max=vb.raw_max;
r.dynamic.Vtail_min=vb.tail_min;r.dynamic.Vtail_max=vb.tail_max;
r.dynamic.Vband_settling_s=vb.settling_s;
r.dynamic.fmin=fb.avg_min;r.dynamic.fmax=fb.avg_max;
r.dynamic.fraw_min=fb.raw_min;r.dynamic.fraw_max=fb.raw_max;
r.dynamic.ftail_min=fb.tail_min;r.dynamic.ftail_max=fb.tail_max;
r.dynamic.fband_settling_s=fb.settling_s;
r.dynamic.phase_peak=max(abs(x(raw,11)));
r.dynamic.Iactual_peak=max(x(raw,12));
r.dynamic.Iref_peak=max(hypot(x(raw,8),x(raw,9)));
r.dynamic.RoCoF=max_rocof(t(quality),x(quality,7));
r.diagP=cycle_diagnostics(t,x(:,2),x(end,4),event,max(.05*abs(x(end,4)),.10e6));
r.diagQ=cycle_diagnostics(t,x(:,3),x(end,5),event,max(.05*abs(x(end,5)),.08e6));
r.dynamic.settling_P_s=r.diagP.settling_s;
r.dynamic.settling_Q_s=r.diagQ.settling_s;
end

function assert_track(r,p,q,pRel,qAbs)
assert(abs(r.ss.P-p)<pRel*max(abs(p),1e6),[r.name ' P tracking failed.']);
assert(abs(r.ss.Q-q)<qAbs,[r.name ' Q tracking failed.']);
end

function d=cycle_diagnostics(t,y,target,event,tol)
% 50 Hz one-cycle moving average, followed by a five-cycle dwell test.
dt=5e-4;tu=(t(1):dt:t(end)).';yu=interp1(t,y,tu,'linear');
nCycle=round(.02/dt);ya=movmean(yu,nCycle,'Endpoints','shrink');
valid=tu>=event+.02;rawOutside=t>=event&abs(y-target)>tol;
avgOutside=valid&abs(ya-target)>tol;
d.raw_last_outside=last_time(t,rawOutside);
d.avg_last_outside=last_time(tu,avgOutside);
d.settling_s=inf;nDwell=round(.10/dt);idx=find(valid);
bad=abs(ya-target)>tol;
for ii=idx(:).'
    if ii+nDwell-1<=numel(tu)&&~any(bad(ii:ii+nDwell-1))
        d.settling_s=tu(ii)-event;break
    end
end
tail=t>=max(t(end)-.12,t(1));taila=tu>=max(tu(end)-.12,tu(1));
d.tail_mean=mean(y(tail));d.tail_min=min(y(tail));d.tail_max=max(y(tail));
d.tail_pp=d.tail_max-d.tail_min;d.tail_std=std(y(tail));
d.avg_tail_min=min(ya(taila));d.avg_tail_max=max(ya(taila));
early=t>=event&t<=min(event+.10,t(end));late=t>=max(t(end)-.10,event);
d.pp_early=range(y(early));d.pp_late=range(y(late));
end

function v=last_time(t,k),i=find(k,1,'last');if isempty(i),v=nan;else,v=t(i);end,end

function r=max_rocof(t,f)
tu=(t(1):1e-3:t(end)).';fu=interp1(t,f,tu,'linear');
fu=smoothdata(fu,'movmean',11);r=max(abs(gradient(fu,tu)));
end

function b=cycle_band(t,y,startTime,event,lower,upper)
dt=5e-4;tu=(t(1):dt:t(end)).';yu=interp1(t,y,tu,'linear');
ya=movmean(yu,round(.02/dt),'Endpoints','shrink');
k=tu>=startTime+.02;kr=t>=startTime;
b.avg_min=min(ya(k));b.avg_max=max(ya(k));
b.raw_min=min(y(kr));b.raw_max=max(y(kr));
tail=tu>=max(tu(end)-.12,startTime+.02);
b.tail_min=min(ya(tail));b.tail_max=max(ya(tail));
valid=find(tu>=max(event+.02,startTime+.02));bad=ya<lower|ya>upper;
b.settling_s=inf;nDwell=round(.10/dt);
for ii=valid(:).'
    if ii+nDwell-1<=numel(tu)&&~any(bad(ii:ii+nDwell-1))
        b.settling_s=tu(ii)-event;break
    end
end
end

function print_case(r)
fprintf(['%-18s P=%7.3f MW Q=%7.3f Mvar | P[min,max]=[%7.3f,%7.3f] MW ' ...
    'Q[min,max]=[%7.3f,%7.3f] Mvar | settle P/Q=%6.3f/%6.3f s\n' ...
    '  Vavg=[%7.1f,%7.1f] V tail=[%7.1f,%7.1f] settle=%5.3f s (raw [%7.1f,%7.1f])\n' ...
    '  favg=[%6.3f,%6.3f] Hz tail=[%6.3f,%6.3f] settle=%5.3f s (raw [%6.3f,%6.3f]) RoCoF=%7.2f Hz/s ' ...
    'phase peak/rms=%6.3f/%6.3f rad Iactual/Iref=%7.1f/%7.1f A k=%6.3f active=%4.2f\n'], ...
    r.name,r.ss.P/1e6,r.ss.Q/1e6,r.dynamic.Pmin/1e6,r.dynamic.Pmax/1e6, ...
    r.dynamic.Qmin/1e6,r.dynamic.Qmax/1e6,r.dynamic.settling_P_s,r.dynamic.settling_Q_s, ...
    r.dynamic.Vmin,r.dynamic.Vmax,r.dynamic.Vtail_min,r.dynamic.Vtail_max,r.dynamic.Vband_settling_s, ...
    r.dynamic.Vraw_min,r.dynamic.Vraw_max,r.dynamic.fmin,r.dynamic.fmax, ...
    r.dynamic.ftail_min,r.dynamic.ftail_max,r.dynamic.fband_settling_s, ...
    r.dynamic.fraw_min,r.dynamic.fraw_max,r.dynamic.RoCoF, ...
    r.dynamic.phase_peak,r.ss.phase_rms,r.dynamic.Iactual_peak,r.dynamic.Iref_peak, ...
    r.ss.limit_factor,r.ss.limit_active);
fprintf(['  Pdiag tail mean/min/max/pp/std=%7.3f/%7.3f/%7.3f/%7.3f/%7.3f MW ' ...
    'avg[min,max]=[%7.3f,%7.3f] MW last raw/avg outside=%7.4f/%7.4f s ' ...
    'pp early/late=%7.3f/%7.3f MW\n'], ...
    r.diagP.tail_mean/1e6,r.diagP.tail_min/1e6,r.diagP.tail_max/1e6, ...
    r.diagP.tail_pp/1e6,r.diagP.tail_std/1e6,r.diagP.avg_tail_min/1e6, ...
    r.diagP.avg_tail_max/1e6,r.diagP.raw_last_outside,r.diagP.avg_last_outside, ...
    r.diagP.pp_early/1e6,r.diagP.pp_late/1e6);
end
