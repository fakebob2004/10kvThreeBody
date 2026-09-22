% Full standalone acceptance: Wind-GFL against a strong synchronous machine.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
model='Wind_GFL_5MW_SystemLevel_SM_R1';
load_system(fullfile(root,'build',[model '.slx']));
run(fullfile(scriptDir,'init_wind_gfl_system_level_sm_r1.m'));
branch=[model '/01 Wind-GFL System-Level Branch'];
profile=[model '/02 Wind Commissioning Command Profile/'];

% Structure and interface gate.
ph=get_param(branch,'PortHandles');
assert(numel(ph.Inport)==1&&numel(ph.Outport)==1&&numel([ph.LConn ph.RConn])==1, ...
    'Wind branch must expose only WindCommandBus, StatusBus and PCC_10kV.');
required={'01 Aerodynamic and MPPT Available Power', ...
    '02 DC Energy Buffer and MSC Equivalent','03 GFL PCS','04 Step-up and PCC'};
for k=1:numel(required),assert(getSimulinkBlockHandle([branch '/' required{k}])>0);end
assert(getSimulinkBlockHandle([branch '/03 GFL PCS/01 Secondary Control/02 Local SRF-PLL'])>0, ...
    'Wind GFL requires its own PCC-local PLL.');
assert(getSimulinkBlockHandle([branch '/03 GFL PCS/01 Secondary Control/Current Circle Factor'])>0);
assert(getSimulinkBlockHandle([branch '/02 DC Energy Buffer and MSC Equivalent/DC Energy Delta'])>0);

R=struct();
R.A=run_case(model,profile,'A_ZERO',0,0,0,0,0,0,10,11,0,.60,.30);
assert(abs(R.A.ss.P)<.12e6&&abs(R.A.ss.Q)<.15e6);

R.B=run_case(model,profile,'B_0_TO_2MW',5e6,0,2e6,0,0,0,10,11,0,2.00,.30);
assert_track(R.B,2e6,0,.08,.15e6);

% Wind-resource increase with dispatch ceiling held above availability.
R.C=run_case(model,profile,'C_WIND_2_TO_3MW',2e6,1e6,5e6,0,0,0,10,11,0,2.00,.30);
assert_track(R.C,3e6,0,.08,.15e6);
assert(abs(R.C.ss.Pavailable-3e6)<.03e6&&abs(R.C.ss.Peffective-3e6)<.03e6);

R.D=run_case(model,profile,'D_DISPATCH_2_TO_3MW',5e6,0,2e6,1e6,0,0,10,11,0,2.00,.30);
assert_track(R.D,3e6,0,.08,.15e6);

R.E=run_case(model,profile,'E_Q_STEP',5e6,0,2e6,0,0,1e6,10,11,0,2.00,.30);
assert_track(R.E,2e6,1e6,.08,.12e6);

% converter_enable does not open the PCC breaker; passive filter Q remains.
R.F=run_case(model,profile,'F_ENABLE_1_0_1',5e6,0,2e6,0,0,0,.30,.58,1,2.00,.30);
x=R.F.x;t=x(:,1);off=t>.43&t<.55;rec=t>.88;
Qpassive=2*pi*W1.base.f_Hz*S1.filter.C_F*(mean(x(off,15))*690/1e4)^2;
assert(abs(mean(x(off,2)))<.15e6&&max(hypot(x(off,8),x(off,9)))<1);
assert(abs(mean(x(off,3))-Qpassive)<max(.15*abs(Qpassive),.05e6));
assert(abs(mean(x(rec,2))-2e6)<.16e6&&mean(x(rec,16))>.95);

R.G=run_case(model,profile,'G_RATED_5MW',5e6,0,5e6,0,0,0,10,11,0,2.00,.30);
assert_track(R.G,5e6,0,.08,.22e6);
assert(R.G.ss.limit_active<.1,'Rated active power should not spuriously limit.');

R.H=run_case(model,profile,'H_AVAILABLE_CAP',2e6,0,4e6,0,0,0,10,11,0,2.00,.30);
assert_track(R.H,2e6,0,.08,.15e6);
assert(abs(R.H.ss.Peffective-2e6)<.03e6,'Available-power cap failed.');

R.I=run_case(model,profile,'I_CIRCLE_LIMIT',8e6,0,8e6,0,-4e6,0,10,11,0,2.50,.30);
assert(R.I.ss.Pavailable<=5.001e6&&R.I.ss.Pdispatch<=5.001e6,'Source rating clamp failed.');
assert(R.I.ss.limit_factor<.98&&R.I.ss.limit_active>.5,'Circular dq limit did not activate.');

names=fieldnames(R);
for k=1:numel(names)
    r=R.(names{k});print_case(r);
    assert(size(r.x,2)==21,['StatusBus did not flatten to 21 channels in ' names{k}]);
    assert(all(isfinite(r.x),'all'),['Nonfinite telemetry in ' names{k}]);
    assert(r.ss.phase_rms<.15&&r.dynamic.phase_peak<.45,['PLL failed in ' names{k}]);
    assert(r.dynamic.Vtail_min>.85e4&&r.dynamic.Vtail_max<1.10e4,['PCC voltage failed in ' names{k}]);
    assert(r.dynamic.ftail_min>48&&r.dynamic.ftail_max<51,['Frequency failed in ' names{k}]);
    assert(r.dynamic.Iref_peak<=1.001*W1.control.Ilimit_peak_A,['Reference current limit failed in ' names{k}]);
    assert(r.dynamic.Iactual_peak<=1.03*W1.control.Ilimit_peak_A,['Actual current limit failed in ' names{k}]);
    assert(r.ss.Vdc>0.80*W1.dc.nominal_V&&r.ss.Vdc<1.20*W1.dc.nominal_V, ...
        ['DC energy state failed in ' names{k}]);
end
fprintf('WIND_GFL_R1_STANDALONE_ACCEPTANCE_PASS=1\n');
close_system(model,0);

function r=run_case(model,prefix,name,pa0,paStep,pd0,pdStep,q0,qStep,tOff,tOn,drop,tStop,event)
set_param([prefix 'P Available Base'],'Value',num2str(pa0,16));
set_param([prefix 'P Available Increment'],'After',num2str(paStep,16),'Time','.30');
set_param([prefix 'P Base Limit'],'UpperLimit',num2str(pd0,16));
set_param([prefix 'P Increment'],'After',num2str(pdStep,16),'Time','.30');
set_param([prefix 'Q Base Command'],'Value',num2str(q0,16));
set_param([prefix 'Q Increment'],'After',num2str(qStep,16),'Time','.30');
set_param([prefix 'Enable Off'],'Time',num2str(tOff,16),'After',num2str(-drop,16));
set_param([prefix 'Enable On'],'Time',num2str(tOn,16),'After',num2str(drop,16));
set_param(model,'StopTime',num2str(tStop,16));o=sim(model);x=o.get('wind_gfl_status');
t=x(:,1);ss=t>max(.1,tStop-.12);quality=t>=max(.25,event-.05);
r.name=name;r.x=x;r.ss.P=mean(x(ss,2));r.ss.Q=mean(x(ss,3));
r.ss.f=mean(x(ss,7));r.ss.phase_rms=rms(x(ss,11));
r.ss.limit_factor=mean(x(ss,13));r.ss.limit_active=mean(x(ss,14));
r.ss.Pavailable=mean(x(ss,17));r.ss.Pdispatch=mean(x(ss,18));
r.ss.Peffective=mean(x(ss,19));r.ss.Vdc=mean(x(ss,20));r.ss.mppt=mean(x(ss,21));
r.dynamic.Iactual_peak=max(x(quality,12));r.dynamic.Iref_peak=max(hypot(x(quality,8),x(quality,9)));
r.dynamic.phase_peak=max(abs(x(quality,11)));
[r.dynamic.Vtail_min,r.dynamic.Vtail_max]=tail_cycle(t,x(:,15));
[r.dynamic.ftail_min,r.dynamic.ftail_max]=tail_cycle(t,x(:,7));
r.dynamic.Psettle=settling_cycle(t,x(:,2),x(end,4),event,max(.05*abs(x(end,4)),.10e6));
r.dynamic.Qsettle=settling_cycle(t,x(:,3),x(end,5),event,max(.05*abs(x(end,5)),.08e6));
end

function assert_track(r,p,q,pRel,qAbs)
assert(abs(r.ss.P-p)<pRel*max(abs(p),1e6),[r.name ' P tracking failed.']);
assert(abs(r.ss.Q-q)<qAbs,[r.name ' Q tracking failed.']);
end

function [mn,mx]=tail_cycle(t,y)
dt=5e-4;tu=(t(1):dt:t(end)).';yu=interp1(t,y,tu,'linear');
ya=movmean(yu,round(.02/dt),'Endpoints','shrink');k=tu>=tu(end)-.12;
mn=min(ya(k));mx=max(ya(k));
end

function s=settling_cycle(t,y,target,event,tol)
dt=5e-4;tu=(t(1):dt:t(end)).';yu=interp1(t,y,tu,'linear');
ya=movmean(yu,round(.02/dt),'Endpoints','shrink');bad=abs(ya-target)>tol;
s=inf;n=round(.10/dt);idx=find(tu>=event+.02);
for ii=idx(:).'
    if ii+n-1<=numel(tu)&&~any(bad(ii:ii+n-1)),s=tu(ii)-event;break,end
end
end

function print_case(r)
fprintf(['%-20s P=%6.3fMW Q=%6.3fMvar Pavail/Pdispatch/Peff=%5.2f/%5.2f/%5.2fMW\n' ...
    '  Vpcc tail=%7.1f..%7.1fV f tail=%6.3f..%6.3fHz PLL peak/rms=%5.3f/%5.3frad\n' ...
    '  Iactual/Iref=%7.1f/%7.1fApk limit k/active=%5.3f/%4.2f Vdc=%7.1fV MPPT=%4.2f settle P/Q=%5.3f/%5.3fs\n'], ...
    r.name,r.ss.P/1e6,r.ss.Q/1e6,r.ss.Pavailable/1e6,r.ss.Pdispatch/1e6,r.ss.Peffective/1e6, ...
    r.dynamic.Vtail_min,r.dynamic.Vtail_max,r.dynamic.ftail_min,r.dynamic.ftail_max, ...
    r.dynamic.phase_peak,r.ss.phase_rms,r.dynamic.Iactual_peak,r.dynamic.Iref_peak, ...
    r.ss.limit_factor,r.ss.limit_active,r.ss.Vdc,r.ss.mppt,r.dynamic.Psettle,r.dynamic.Qsettle);
end
