%VALIDATE_WIND_PMSG_TRANSIENT_R4_STEP Wind-step, PLL and power-chain checks.
root=fileparts(fileparts(mfilename('fullpath')));model='Wind_PMSG_Transient_R4';
file=fullfile(root,'build',[model '.slx']);assert(isfile(file),'Missing R4 model.');
run(fullfile(root,'parameters','init_wind_pmsg_transient_r4.m'));
load_system(file);cleanup=onCleanup(@()closeIfLoaded(model));
set_param(model,'StopTime','0.180');out=sim(model);logs=out.logsout;
wind=ts(logs,'wind_speed_mps');pa=ts(logs,'P_aero_W');pdc=ts(logs,'P_msc_W');
vdc=ts(logs,'Vdc_Meas');wt=ts(logs,'omega_turbine_rad_s');wg=ts(logs,'omega_generator_rad_s');
iq=ts(logs,'PMSG_iq_A');iqr=ts(logs,'PMSG_iq_ref_A');omega=ts(logs,'omega_PLL');
pre=[0.090 0.115];post=[0.165 0.180];
R.wind_pre=meanWindow(wind,pre);R.wind_post=meanWindow(wind,post);
R.paero_pre=meanWindow(pa,pre);R.paero_post=meanWindow(pa,post);
R.pmsc_pre=meanWindow(pdc,pre);R.pmsc_post=meanWindow(pdc,post);
R.vdc_min=minWindow(vdc,post);R.vdc_max=maxWindow(vdc,post);
R.speed_split=maxPair(wt,wg,post);R.iq_error=meanAbsError(iq,iqr,post);
R.pll_min=minWindow(omega,post)/(2*pi);R.pll_max=maxWindow(omega,post)/(2*pi);
R.pre_conversion=R.pmsc_pre/R.paero_pre;
fprintf('R4_STEP_METRICS=%s\n',jsonencode(R));
assert(abs(R.wind_pre-Wind.wind_initial_mps)<0.01&& ...
 abs(R.wind_post-Wind.wind_initial_mps-Wind.wind_step_mps)<0.01,'Wind step mismatch.');
assert(R.paero_post>1.2*R.paero_pre,'Aerodynamic response missing.');
assert(R.pre_conversion>PMSG.Validation.minimum_msc_efficiency&&R.pre_conversion<1, ...
 'Pre-step machine conversion efficiency invalid.');
assert(R.pmsc_post>0.5e6,'MSC left generating operation.');
assert(R.vdc_min>1350&&R.vdc_max<1650,'Vdc left transient range.');
assert(R.speed_split<0.10,'Two-mass speed split excessive.');
assert(R.iq_error<0.12*PMSG.current_limit_A,'MSC q-current tracking failed.');
assert(R.pll_min>49&&R.pll_max<51,'PLL left the wind-step frequency band.');
fprintf('WIND_PMSG_TRANSIENT_R4_WIND_STEP_OK=1\n');
clear cleanup
function x=ts(logs,name)
for k=1:logs.numElements,e=logs{k};if strcmp(e.Name,name)&&isa(e.Values,'timeseries'),x=e.Values;return,end,end
error('Missing log: %s',name);
end
function v=meanWindow(x,w),k=x.Time>=w(1)&x.Time<=w(2);assert(any(k));v=mean(x.Data(k));end
function v=minWindow(x,w),k=x.Time>=w(1)&x.Time<=w(2);v=min(x.Data(k));end
function v=maxWindow(x,w),k=x.Time>=w(1)&x.Time<=w(2);v=max(x.Data(k));end
function e=meanAbsError(a,b,w)
t=a.Time(a.Time>=w(1)&a.Time<=w(2));av=a.Data(a.Time>=w(1)&a.Time<=w(2));bv=sampleAt(b,t);e=mean(abs(av(:)-bv(:)));
end
function e=maxPair(a,b,w)
t=a.Time(a.Time>=w(1)&a.Time<=w(2));av=a.Data(a.Time>=w(1)&a.Time<=w(2));bv=sampleAt(b,t);e=max(abs(av(:)-bv(:)));
end
function v=sampleAt(x,t)
if numel(x.Time)==1,v=repmat(x.Data(1),size(t));else,v=interp1(x.Time,x.Data,t,'linear','extrap');end
end
function closeIfLoaded(m),if bdIsLoaded(m),close_system(m,0);end,end
