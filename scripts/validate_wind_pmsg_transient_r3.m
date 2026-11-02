%VALIDATE_WIND_PMSG_TRANSIENT_R3 Structural and basic operating-point checks.
root=fileparts(fileparts(mfilename('fullpath')));
model='Wind_PMSG_Transient_R3'; modelFile=fullfile(root,'build',[model '.slx']);
assert(isfile(modelFile),'Missing generated model: %s',modelFile);
run(fullfile(root,'parameters','init_wind_pmsg_transient_r3.m'));
load_system(modelFile); cleanup=onCleanup(@()closeIfLoaded(model));

required={ ...
    '01 Wind Turbine Two-Mass Aerodynamics', ...
    '02 PMSG dq Machine and Average MSC', ...
    '03 DC Link and Two-Level GSC', ...
    '04 GFL Control and SPWM', ...
    '05 Filter Transformer and PCC', ...
    '06 Grid Equivalent and Source'};
for k=1:numel(required)
    assert(getSimulinkBlockHandle([model '/' required{k}])>0, ...
        'Missing top-level block: %s',required{k});
end
machine=[model '/02 PMSG dq Machine and Average MSC'];
for b={'id State','iq State','id Error','iq Error','Circular Voltage Scale', ...
        'Generated DC Power','Sampled Vdc'}
    assert(getSimulinkBlockHandle([machine '/' b{1}])>0,'Missing PMSG/MSC block: %s',b{1});
end
shaft=[model '/01 Wind Turbine Two-Mass Aerodynamics'];
for b={'Turbine Inertia','Generator Inertia','Shaft Twist','Flexible Shaft'}
    assert(getSimulinkBlockHandle([shaft '/' b{1}])>0,'Missing shaft block: %s',b{1});
end
assert(isempty(find_system(model,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','SubSystem','SFBlockType','MATLAB Function')), ...
    'MATLAB Function blocks are not allowed in this generated model.');
set_param(model,'SimulationCommand','update');

% Short switching-model smoke test. The wind step is tested separately by
% extending StopTime after this basic operating point has passed.
set_param(model,'StopTime','0.020');
out=sim(model); logs=out.logsout;
names={'Vdc_Meas','P_msc_W','PMSG_id_A','PMSG_iq_A','PMSG_id_ref_A', ...
    'PMSG_iq_ref_A','T_e_Nm','T_e_ref_Nm','omega_turbine_rad_s', ...
    'omega_generator_rad_s'};
for k=1:numel(names)
    ts=firstTimeseries(logs,names{k});
    assert(all(isfinite(ts.Data(:))),'Nonfinite data in %s.',names{k});
end

vdc=firstTimeseries(logs,'Vdc_Meas'); pdc=firstTimeseries(logs,'P_msc_W');
id=firstTimeseries(logs,'PMSG_id_A'); iq=firstTimeseries(logs,'PMSG_iq_A');
idr=firstTimeseries(logs,'PMSG_id_ref_A'); iqr=firstTimeseries(logs,'PMSG_iq_ref_A');
te=firstTimeseries(logs,'T_e_Nm'); ter=firstTimeseries(logs,'T_e_ref_Nm');
wt=firstTimeseries(logs,'omega_turbine_rad_s'); wg=firstTimeseries(logs,'omega_generator_rad_s');
tailStart=0.015;
VdcMean=tailMean(vdc,tailStart); PdcMean=tailMean(pdc,tailStart);
IdError=tailMeanAbsError(id,idr,tailStart); IqError=tailMeanAbsError(iq,iqr,tailStart);
TeError=tailMeanAbsError(te,ter,tailStart);
speedSplit=tailMaxPairDifference(wt,wg,tailStart);

gateNames={'Gate_AH','Gate_AL','Gate_BH','Gate_BL','Gate_CH','Gate_CL'}; g=[];
for k=1:numel(gateNames)
    ts=firstTimeseries(logs,gateNames{k});
    if isempty(g),g=zeros(numel(ts.Data),6);end
    g(:,k)=ts.Data(:);
end
gateComplement=max(abs(g(:,1)+g(:,2)-1))+max(abs(g(:,3)+g(:,4)-1))+ ...
    max(abs(g(:,5)+g(:,6)-1));

fprintf('R3_VDC_MEAN_V=%.9g\n',VdcMean);
fprintf('R3_MSC_POWER_MEAN_W=%.9g\n',PdcMean);
fprintf('R3_ID_MEAN_ABS_ERROR_A=%.9g\n',IdError);
fprintf('R3_IQ_MEAN_ABS_ERROR_A=%.9g\n',IqError);
fprintf('R3_TE_MEAN_ABS_ERROR_NM=%.9g\n',TeError);
fprintf('R3_MAX_SPEED_SPLIT_RAD_S=%.9g\n',speedSplit);
fprintf('R3_GATE_COMPLEMENT_ERROR=%.9g\n',gateComplement);

assert(VdcMean>PMSG.Validation.vdc_min_V && VdcMean<PMSG.Validation.vdc_max_V, ...
    'DC-link operating point is outside the accepted range.');
assert(PdcMean>0.5e6 && PdcMean<=1.01*PMSG.Sn_W,'MSC power is not in generating operation.');
assert(IdError<0.05*PMSG.current_limit_A,'d-axis current tracking failed.');
assert(IqError<PMSG.Validation.current_tracking_fraction*PMSG.current_limit_A, ...
    'q-axis current tracking failed.');
assert(TeError<0.12*PMSG.torque_limit_Nm,'Electromagnetic torque tracking failed.');
assert(speedSplit<PMSG.Validation.speed_split_max_rad_s,'Two-mass speed split is excessive.');
assert(isequal(unique(g(:)).',[0 1]),'GSC gate pulses are not binary.');
assert(gateComplement==0,'GSC upper/lower gate pairs are not complementary.');

fprintf('WIND_PMSG_TRANSIENT_R3_STRUCTURE_OK=1\n');
fprintf('WIND_PMSG_TRANSIENT_R3_OPERATING_POINT_OK=1\n');
fprintf('WIND_PMSG_TRANSIENT_R3_SWITCHING_INTERFACE_OK=1\n');
clear cleanup

function ts=firstTimeseries(logs,name)
for k=1:logs.numElements
    e=logs{k}; if strcmp(e.Name,name)&&isa(e.Values,'timeseries'),ts=e.Values;return,end
end
error('Logged timeseries not found: %s',name);
end
function v=tailMean(ts,t0)
d=ts.Data(ts.Time>=t0); assert(~isempty(d),'Empty tail for %s.',ts.Name); v=mean(d(:));
end
function e=tailMeanAbsError(a,b,t0)
t=a.Time(a.Time>=t0); av=a.Data(a.Time>=t0); bv=sampleAt(b,t);
e=mean(abs(av(:)-bv(:)));
end
function e=tailMaxPairDifference(a,b,t0)
t=a.Time(a.Time>=t0); av=a.Data(a.Time>=t0); bv=sampleAt(b,t);
e=max(abs(av(:)-bv(:)));
end
function v=sampleAt(ts,t)
if numel(ts.Time)==1,v=repmat(ts.Data(1),size(t));
else,v=interp1(ts.Time,ts.Data,t,'linear','extrap');end
end
function closeIfLoaded(model),if bdIsLoaded(model),close_system(model,0);end,end
