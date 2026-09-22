% Stage 2 R1: three-source natural AC-coupling acceptance, no coordinator.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
if exist('STAGE2_MODEL_OVERRIDE','var')&&strlength(string(STAGE2_MODEL_OVERRIDE))>0
    model=char(STAGE2_MODEL_OVERRIDE);
else
    model='BESS_PV_WIND_STAGE2_R1';
end
load_system(fullfile(root,'build',[model '.slx']));
run(fullfile(scriptDir,'init_bess_pv_wind_stage2_r1.m'));
pv=[model '/03 PV-GFL Branch'];wind=[model '/04 Wind-GFL Branch'];
supFound=find_system(model,'SearchDepth',2,'Name','06 Supervision and Results');
assert(numel(supFound)==1,'Supervision owner is missing or ambiguous.');sup=supFound{1};
loadSys=[model '/05 Island Load'];

% Structural isolation gate.
check_boundary(pv,1,1,1);check_boundary(wind,1,1,1);
assert(getSimulinkBlockHandle([pv '/01 GFL PCS/01 Secondary Control/02 Local SRF-PLL'])>0);
assert(getSimulinkBlockHandle([wind '/03 GFL PCS/01 Secondary Control/02 Local SRF-PLL'])>0);
for resource={pv,wind}
    tags=find_system(resource{1},'LookUnderMasks','all','RegExp','on','BlockType','(From|Goto)');
    for k=1:numel(tags)
        assert(~startsWith(get_param(tags{k},'GotoTag'),'R8_'), ...
            'GFL resource reads a hidden BESS route.');
    end
end
apiFound=find_system(model,'SearchDepth',2,'Name','07 Resource API Layer');
isApiVariant=numel(apiFound)==1;
if ~isApiVariant
    assert(isempty(find_system(model,'RegExp','on','Name','(?i).*coordinator.*')), ...
        'Coordinator is out of scope for Stage 2 Step 1.');
else
    assert(getSimulinkBlockHandle([apiFound{1} '/MATLAB Function Coordinator'])>0, ...
        'API derivative is missing its coordinator boundary.');
end

R=struct();
R.A=run_case(model,sup,loadSys,'A_PV_2_TO_3',2e6,1e6,2e6,0,0,0,1.40);
R.B=run_case(model,sup,loadSys,'B_WIND_2_TO_3',2e6,0,2e6,1e6,0,0,1.40);
R.C=run_case(model,sup,loadSys,'C_PV_WIND_TO_3',2e6,1e6,2e6,1e6,0,0,1.60);
R.D=run_case(model,sup,loadSys,'D_LOAD_5_TO_6',2e6,0,2e6,0,1e6,.3e6,1.40);

% Case-specific natural balancing.
check_delta(R.A,+1e6,0,-1e6);check_delta(R.B,0,+1e6,-1e6);
check_delta(R.C,+1e6,+1e6,-2e6);check_delta(R.D,0,0,+1e6);
assert(R.C.post.Pbess<-.55e6,'Case C did not drive BESS into charging/absorption.');

names=fieldnames(R);
for k=1:numel(names)
    r=R.(names{k});print_case(r);
    assert(size(r.x,2)==54&&all(isfinite(r.x),'all'),['Invalid 54-channel log in ' names{k}]);
    if isfield(r,'api_log')
        assert(size(r.api_log,2)==48&&all(isfinite(r.api_log),'all'), ...
            ['Invalid 48-channel Resource API log in ' names{k}]);
    end
    assert(abs(r.pre.balance)<.30e6&&abs(r.post.balance)<.30e6,['Power balance failed in ' names{k}]);
    assert(r.dynamic.Vmin>.90e4&&r.dynamic.Vmax<1.10e4,['PCC voltage failed in ' names{k}]);
    assert(r.dynamic.fmin>48&&r.dynamic.fmax<51,['Frequency failed in ' names{k}]);
    assert(r.dynamic.rocof<5,['RoCoF failed in ' names{k}]);
    assert(r.dynamic.pv_phase_peak<.20&&r.dynamic.wind_phase_peak<.20, ...
        ['Local PLL lock failed in ' names{k}]);
    assert(r.dynamic.pv_limit_min>.98&&r.dynamic.wind_limit_min>.98, ...
        ['Ordinary GFL case entered current limiting in ' names{k}]);
    assert(r.dynamic.bess_limit_min>.95,['BESS entered AC current limiting in ' names{k}]);
    assert(r.dynamic.Ibat_peak<G.dcdc.Imax_A,['Battery current protection failed in ' names{k}]);
    assert(r.dynamic.Vdc_bess_min>.95*G.dc.Vdc_ref_V&& ...
        r.dynamic.Vdc_bess_max<1.05*G.dc.Vdc_ref_V,['BESS DC link failed in ' names{k}]);
    assert(r.post.Vdc_wind>.8*W1.dc.nominal_V&&r.post.Vdc_wind<1.2*W1.dc.nominal_V, ...
        ['Wind DC energy proxy failed in ' names{k}]);
end
fprintf('BESS_PV_WIND_STAGE2_R1_THREE_SOURCE_BASELINE_PASS=1\n');close_system(model,0);

function r=run_case(model,sup,loadSys,name,pv0,pvStep,w0,wStep,loadStepP,loadStepQ,tStop)
pvCmd=[sup '/01 PV Command Profile/'];wCmd=[sup '/02 Wind Command Profile/'];
set_param([pvCmd 'P Base Limit'],'UpperLimit',num2str(pv0,16));
set_param([pvCmd 'P Increment'],'After',num2str(pvStep,16),'Time','.30');
set_param([pvCmd 'Q Base Command'],'Value','0');set_param([pvCmd 'Q Increment'],'After','0');
set_param([pvCmd 'Enable Off'],'Time','10','After','0');set_param([pvCmd 'Enable On'],'Time','11','After','0');
set_param([wCmd 'P Available Base'],'Value','5e6');set_param([wCmd 'P Available Increment'],'After','0');
set_param([wCmd 'P Base Limit'],'UpperLimit',num2str(w0,16));
set_param([wCmd 'P Increment'],'After',num2str(wStep,16),'Time','.30');
set_param([wCmd 'Q Base Command'],'Value','0');set_param([wCmd 'Q Increment'],'After','0');
set_param([wCmd 'Enable Off'],'Time','10','After','0');set_param([wCmd 'Enable On'],'Time','11','After','0');
set_param([loadSys '/One_MW_Step_Load'],'active_power',num2str(loadStepP,16), ...
    'reactive_power',num2str(loadStepQ,16));
set_param(model,'StopTime',num2str(tStop,16));o=sim(model);x=squeeze(o.get('stage2_result'));
if size(x,2)~=54,x=x.';end
hasApi=~isempty(find_system(model,'SearchDepth',2,'Name','07 Resource API Layer'));
if hasApi
    apiLog=squeeze(o.get('resource_api_result'));
    if size(apiLog,2)~=48,apiLog=apiLog.';end
end
t=x(:,1);pre=t>.22&t<.28;post=t>tStop-.15;quality=t>=.20;
r.name=name;r.x=x;r.pre=state(mean(x(pre,:),1),loadStepP,loadStepQ,false);
if hasApi,r.api_log=apiLog;end
r.post=state(mean(x(post,:),1),loadStepP,loadStepQ,true);
[r.dynamic.Vmin,r.dynamic.Vmax]=cycle_tail(t,x(:,30),.20);
[r.dynamic.fmin,r.dynamic.fmax]=cycle_tail(t,x(:,4),.20);
r.dynamic.rocof=max_rocof(t(quality),x(quality,4));
r.dynamic.pv_phase_peak=max(abs(x(quality,26)));
r.dynamic.wind_phase_peak=max(abs(x(quality,42)));
r.dynamic.pv_limit_min=min(x(quality,28));r.dynamic.wind_limit_min=min(x(quality,44));
r.dynamic.bess_limit_min=min(x(quality,14));r.dynamic.Ibat_peak=max(abs(x(quality,8)));
r.dynamic.Vdc_bess_min=min(x(quality,7));r.dynamic.Vdc_bess_max=max(x(quality,7));
end

function s=state(a,loadStepP,loadStepQ,afterEvent)
s.Pbess=a(2);s.Qbess=a(3);s.Ppv=a(17);s.Qpv=a(18);s.Pwind=a(33);s.Qwind=a(34);
s.Vdc_wind=a(51);s.Pload=a(53)+afterEvent*loadStepP;s.Qload=a(54)+afterEvent*loadStepQ;
s.balance=s.Pload-s.Pbess-s.Ppv-s.Pwind;
end
function check_delta(r,dpv,dw,db)
assert(abs((r.post.Ppv-r.pre.Ppv)-dpv)<.22e6,[r.name ' PV delta failed']);
assert(abs((r.post.Pwind-r.pre.Pwind)-dw)<.22e6,[r.name ' Wind delta failed']);
assert(abs((r.post.Pbess-r.pre.Pbess)-db)<.30e6,[r.name ' BESS delta failed']);
assert(abs((r.post.Ppv-r.pre.Ppv)+(r.post.Pwind-r.pre.Pwind)+ ...
    (r.post.Pbess-r.pre.Pbess)-(r.post.Pload-r.pre.Pload))<.30e6,[r.name ' delta balance failed']);
end
function [mn,mx]=cycle_tail(t,y,startTime)
dt=5e-4;tu=(t(1):dt:t(end)).';ya=movmean(interp1(t,y,tu,'linear'),round(.02/dt),'Endpoints','shrink');
k=tu>=max(startTime,tu(end)-.12);mn=min(ya(k));mx=max(ya(k));
end
function r=max_rocof(t,f)
tu=(t(1):1e-3:t(end)).';fu=smoothdata(interp1(t,f,tu,'linear'),'movmean',11);r=max(abs(gradient(fu,tu)));
end
function print_case(r)
fprintf(['%-20s PRE  B/PV/W=%.3f/%.3f/%.3f MW balance=%+.3f MW\n' ...
    '                     POST B/PV/W=%.3f/%.3f/%.3f MW balance=%+.3f MW\n' ...
    '                     V=[%.1f %.1f] V f=[%.4f %.4f] Hz RoCoF=%.3f Hz/s limits B/PV/W=%.3f/%.3f/%.3f\n'], ...
    r.name,r.pre.Pbess/1e6,r.pre.Ppv/1e6,r.pre.Pwind/1e6,r.pre.balance/1e6, ...
    r.post.Pbess/1e6,r.post.Ppv/1e6,r.post.Pwind/1e6,r.post.balance/1e6, ...
    r.dynamic.Vmin,r.dynamic.Vmax,r.dynamic.fmin,r.dynamic.fmax,r.dynamic.rocof, ...
    r.dynamic.bess_limit_min,r.dynamic.pv_limit_min,r.dynamic.wind_limit_min);
end
function check_boundary(sys,ni,no,np)
ph=get_param(sys,'PortHandles');assert(numel(ph.Inport)==ni&&numel(ph.Outport)==no&&numel([ph.LConn ph.RConn])==np);
end
