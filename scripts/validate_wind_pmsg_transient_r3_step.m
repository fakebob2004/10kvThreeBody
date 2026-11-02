%VALIDATE_WIND_PMSG_TRANSIENT_R3_STEP Basic wind-step transient acceptance.
root=fileparts(fileparts(mfilename('fullpath')));
model='Wind_PMSG_Transient_R3'; file=fullfile(root,'build',[model '.slx']);
assert(isfile(file),'Missing generated model: %s',file);
run(fullfile(root,'parameters','init_wind_pmsg_transient_r3.m'));
load_system(file); cleanup=onCleanup(@()closeIfLoaded(model));
set_param(model,'StopTime','0.180'); out=sim(model); logs=out.logsout;

wind=ts(logs,'wind_speed_mps'); pa=ts(logs,'P_aero_W'); pdc=ts(logs,'P_msc_W');
vdc=ts(logs,'Vdc_Meas'); wt=ts(logs,'omega_turbine_rad_s'); wg=ts(logs,'omega_generator_rad_s');
iq=ts(logs,'PMSG_iq_A'); iqr=ts(logs,'PMSG_iq_ref_A'); te=ts(logs,'T_e_Nm');
pre=[0.090 0.115]; post=[0.165 0.180];
windPre=windowMean(wind,pre); windPost=windowMean(wind,post);
paPre=windowMean(pa,pre); paPost=windowMean(pa,post);
pdcPre=windowMean(pdc,pre); pdcPost=windowMean(pdc,post);
vdcMin=min(vdc.Data(vdc.Time>=post(1))); vdcMax=max(vdc.Data(vdc.Time>=post(1)));
split=maxPairDifference(wt,wg,post); iqError=windowMeanAbsError(iq,iqr,post);
teMin=min(te.Data(te.Time>=post(1)));

fprintf('R3_STEP_WIND_PRE_MPS=%.9g\n',windPre);
fprintf('R3_STEP_WIND_POST_MPS=%.9g\n',windPost);
fprintf('R3_STEP_PAERO_PRE_W=%.9g\n',paPre);
fprintf('R3_STEP_PAERO_POST_W=%.9g\n',paPost);
fprintf('R3_STEP_PMSC_PRE_W=%.9g\n',pdcPre);
fprintf('R3_STEP_PMSC_POST_W=%.9g\n',pdcPost);
fprintf('R3_STEP_VDC_MIN_V=%.9g\n',vdcMin);
fprintf('R3_STEP_VDC_MAX_V=%.9g\n',vdcMax);
fprintf('R3_STEP_MAX_SPEED_SPLIT_RAD_S=%.9g\n',split);
fprintf('R3_STEP_IQ_MEAN_ABS_ERROR_A=%.9g\n',iqError);

assert(abs(windPre-Wind.wind_initial_mps)<0.01,'Incorrect pre-step wind speed.');
assert(abs(windPost-(Wind.wind_initial_mps+Wind.wind_step_mps))<0.01, ...
    'Wind step did not reach the requested final value.');
assert(paPost>1.20*paPre,'Aerodynamic power did not respond to the wind step.');
assert(all(isfinite([paPre paPost pdcPre pdcPost vdcMin vdcMax split iqError teMin])), ...
    'Wind-step result contains nonfinite values.');
assert(pdcPre>0.5e6 && pdcPost>0.5e6,'MSC left generating operation.');
assert(vdcMin>1350 && vdcMax<1650,'DC voltage left the basic transient range.');
assert(split<Drive.torsional_frequency_Hz*0.10,'Two-mass response is excessive.');
assert(iqError<0.12*PMSG.current_limit_A,'MSC current tracking failed during wind step.');
assert(teMin>0,'PMSG electromagnetic torque changed sign.');
fprintf('WIND_PMSG_TRANSIENT_R3_WIND_STEP_OK=1\n');
clear cleanup

function x=ts(logs,name)
for k=1:logs.numElements,e=logs{k};if strcmp(e.Name,name)&&isa(e.Values,'timeseries'),x=e.Values;return,end,end
error('Missing log: %s',name);
end
function v=windowMean(x,w),d=x.Data(x.Time>=w(1)&x.Time<=w(2));assert(~isempty(d));v=mean(d(:));end
function e=windowMeanAbsError(a,b,w)
t=a.Time(a.Time>=w(1)&a.Time<=w(2));av=a.Data(a.Time>=w(1)&a.Time<=w(2));bv=sampleAt(b,t);e=mean(abs(av(:)-bv(:)));
end
function e=maxPairDifference(a,b,w)
t=a.Time(a.Time>=w(1)&a.Time<=w(2));av=a.Data(a.Time>=w(1)&a.Time<=w(2));bv=sampleAt(b,t);e=max(abs(av(:)-bv(:)));
end
function v=sampleAt(x,t)
if numel(x.Time)==1,v=repmat(x.Data(1),size(t));else,v=interp1(x.Time,x.Data,t,'linear','extrap');end
end
function closeIfLoaded(model),if bdIsLoaded(model),close_system(model,0);end,end
