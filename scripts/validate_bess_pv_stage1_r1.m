% Full Stage-1 natural AC coordination acceptance.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
if exist('STAGE1_MODEL_OVERRIDE','var')&&strlength(string(STAGE1_MODEL_OVERRIDE))>0
    model=char(STAGE1_MODEL_OVERRIDE);
else
    model='BESS_GFM_PV_GFL_Stage1_R1';
end
modelFile=fullfile(root,'build',[model '.slx']);
run(fullfile(scriptDir,'init_bess_pv_stage1_r1.m'));load_system(modelFile);

% Architecture gate: accepted PV branch has exactly CommandBus, StatusBus,
% and one three-phase PCC port.  No wind/coordinator or hidden R8 route.
pv=[model '/03 PV-GFL Branch'];ph=get_param(pv,'PortHandles');
assert(numel(ph.Inport)==1&&numel(ph.Outport)==1&&numel([ph.LConn ph.RConn])==1, ...
    'PV branch must expose exactly CommandBus, StatusBus and PCC_10kV.');
pllOld=[pv '/01 GFL PCS/01 Secondary Control/02 Local SRF-PLL'];
pllReadable=[pv '/01 GFL PCS/01 Secondary Control/01 Local SRF-PLL/SRF-PLL Core'];
assert(getSimulinkBlockHandle(pllOld)>0||getSimulinkBlockHandle(pllReadable)>0, ...
    'Accepted PCC-local PLL is missing.');
assert(getSimulinkBlockHandle([pv '/02 Step-up and PCC/PCC 10kV VI Sensor'])>0, ...
    'PV PCC-local voltage sensor is missing.');
for type={'From','Goto'}
    bs=find_system(pv,'LookUnderMasks','all','BlockType',type{1});
    for k=1:numel(bs)
        assert(~startsWith(get_param(bs{k},'GotoTag'),'R8_'), ...
            'PV branch has a hidden cross-source R8 route.');
    end
end
for pattern={'wind','severity','coordinator'}
    assert(isempty(find_system(model,'RegExp','on','Name',['(?i).*' pattern{1} '.*'])), ...
        ['Out-of-scope block found: ' pattern{1}]);
end
assert(strcmp(get_param([model '/04 Island Load/One_MW_Step_Load'],'active_power'),'0'), ...
    'R8 load-step branch was not disabled in Stage 1.');

out=sim(model);x=squeeze(out.get('stage1_result'));
if size(x,2)~=33,x=x.';end
assert(size(x,2)==33&&all(isfinite(x),'all'),'Stage-1 telemetry is invalid.');
t=x(:,1);pre=t>.22&t<.28;post=t>.75;event=t>=.30;quality=t>=.20;
a=mean(x(pre,:),1);b=mean(x(post,:),1);

Pb0=a(2);Pb1=b(2);Qb0=a(3);Qb1=b(3);
Ppv0=a(17);Ppv1=b(17);Qpv0=a(18);Qpv1=b(18);
dPb=Pb1-Pb0;dPpv=Ppv1-Ppv0;
balance0=a(32)-Pb0-Ppv0;balance1=b(32)-Pb1-Ppv1;

assert(abs(Ppv0-2e6)<.16e6,'PV pre-step 2 MW tracking failed.');
assert(abs(Ppv1-3e6)<.24e6,'PV post-step 3 MW tracking failed.');
assert(dPpv>.80e6&&dPpv<1.20e6,'PV did not execute the +1 MW command.');
assert(dPb<-.80e6&&dPb>-1.20e6,'BESS power did not move opposite to PV.');
assert(abs(dPpv+dPb)<.20e6,'PV/BESS power changes do not balance.');
assert(abs(balance0)<.25e6&&abs(balance1)<.25e6, ...
    'Active-power balance residual exceeds engineering loss tolerance.');
assert(abs(Qpv0)<.15e6&&abs(Qpv1)<.15e6,'PV Q=0 tracking failed.');
assert(abs(a(32)-S1.load.P_W)<1&&abs(a(33)-S1.load.Q_var)<1, ...
    'Fixed load telemetry is incorrect.');

V=band_metrics(t,x(:,30),.20,.30,.90e4,1.10e4);
F=band_metrics(t,x(:,4),.20,.30,48,51);
Pset=settling_metric(t,x(:,17),3e6,.30,.05*3e6);
rocof=max_rocof(t(quality),x(quality,4));
phasePeak=max(abs(x(quality,26)));phaseRms=rms(x(post,26));
IpvActual=max(x(quality,27));IpvRef=max(hypot(x(quality,23),x(quality,24)));
IpvLimit=max(x(quality,25));pvLimitMin=min(x(quality,28));
IbatPeak=max(abs(x(quality,8)));VdcMin=min(x(event,7));VdcMax=max(x(event,7));
bessLimitMin=min(x(quality,14));

assert(V.settling_s<.35&&V.tail_min>.90e4&&V.tail_max<1.10e4, ...
    'PCC voltage has sustained excursion or divergence.');
assert(F.settling_s<.35&&F.tail_min>48&&F.tail_max<51, ...
    'Frequency has sustained excursion or divergence.');
assert(V.late_pp<.03*S1.base.Vpcc_V,'PCC voltage has sustained oscillation.');
assert(F.late_pp<.20,'Frequency has sustained oscillation.');
assert(Pset<.40,'PV 3 MW settling-time requirement failed.');
assert(phasePeak<.20&&phaseRms<.05,'PV PLL lock requirement failed.');
assert(IpvRef<=1.001*IpvLimit&&IpvActual<=1.03*IpvLimit, ...
    'PV current limit requirement failed.');
assert(pvLimitMin>0.98&&pvLimitMin<=1.001, ...
    'PV entered current limiting in the ordinary Stage-1 baseline.');
assert(IbatPeak<G.dcdc.Imax_A,'BESS battery current protection failed.');
assert(VdcMin>.95*G.dc.Vdc_ref_V&&VdcMax<1.05*G.dc.Vdc_ref_V, ...
    'BESS DC-link protection band failed.');
assert(bessLimitMin>0.95&&bessLimitMin<=1.001, ...
    'BESS entered AC current limiting in the ordinary Stage-1 baseline.');

fprintf(['STAGE1 PRE  Ppv=%.4f MW Qpv=%.4f Mvar Pbess=%.4f MW Qbess=%.4f Mvar\n' ...
    'STAGE1 POST Ppv=%.4f MW Qpv=%.4f Mvar Pbess=%.4f MW Qbess=%.4f Mvar\n' ...
    'DELTA dPpv=%+.4f MW dPbess=%+.4f MW sum=%+.4f MW; balance pre/post=%+.4f/%+.4f MW\n' ...
    'DYNAMIC Vavg=[%.1f %.1f] V tail=[%.1f %.1f] V pp_late=%.1f V; ' ...
    'favg=[%.4f %.4f] Hz tail=[%.4f %.4f] Hz RoCoF=%.3f Hz/s settleP=%.4f s\n' ...
    'LIMITS PV phase peak/rms=%.5f/%.5f rad Iactual/Iref/Ilim=%.1f/%.1f/%.1f A ' ...
    'PVfactor_min=%.4f; Ibat_peak=%.1f A Vdc=[%.2f %.2f] V BESSfactor_min=%.4f\n'], ...
    Ppv0/1e6,Qpv0/1e6,Pb0/1e6,Qb0/1e6,Ppv1/1e6,Qpv1/1e6,Pb1/1e6,Qb1/1e6, ...
    dPpv/1e6,dPb/1e6,(dPpv+dPb)/1e6,balance0/1e6,balance1/1e6, ...
    V.avg_min,V.avg_max,V.tail_min,V.tail_max,V.late_pp,F.avg_min,F.avg_max, ...
    F.tail_min,F.tail_max,rocof,Pset,phasePeak,phaseRms,IpvActual,IpvRef,IpvLimit, ...
    pvLimitMin,IbatPeak,VdcMin,VdcMax,bessLimitMin);
fprintf('BESS_PV_STAGE1_NATURAL_AC_COORDINATION_PASS=1\n');
close_system(model,0);

function b=band_metrics(t,y,startTime,event,lower,upper)
dt=5e-4;tu=(t(1):dt:t(end)).';yu=interp1(t,y,tu,'linear');
ya=movmean(yu,round(.02/dt),'Endpoints','shrink');valid=tu>=startTime+.02;
b.avg_min=min(ya(valid));b.avg_max=max(ya(valid));
tail=tu>=tu(end)-.12;b.tail_min=min(ya(tail));b.tail_max=max(ya(tail));
late=tu>=tu(end)-.10;b.late_pp=range(ya(late));
bad=ya<lower|ya>upper;idx=find(tu>=max(event+.02,startTime+.02));
b.settling_s=inf;n=round(.10/dt);
for ii=idx(:).'
    if ii+n-1<=numel(tu)&&~any(bad(ii:ii+n-1)),b.settling_s=tu(ii)-event;break,end
end
end

function ts=settling_metric(t,y,target,event,tol)
dt=5e-4;tu=(t(1):dt:t(end)).';yu=interp1(t,y,tu,'linear');
ya=movmean(yu,round(.02/dt),'Endpoints','shrink');bad=abs(ya-target)>tol;
idx=find(tu>=event+.02);n=round(.10/dt);ts=inf;
for ii=idx(:).'
    if ii+n-1<=numel(tu)&&~any(bad(ii:ii+n-1)),ts=tu(ii)-event;break,end
end
end

function r=max_rocof(t,f)
tu=(t(1):1e-3:t(end)).';fu=interp1(t,f,tu,'linear');
fu=smoothdata(fu,'movmean',5);r=max(abs(gradient(fu,tu)));
end
