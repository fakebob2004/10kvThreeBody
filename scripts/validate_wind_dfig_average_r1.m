%VALIDATE_WIND_DFIG_AVERAGE_R1 Structural and dynamic acceptance checks.
root=fileparts(fileparts(mfilename('fullpath')));
model='Wind_DFIG_Average_R1';file=fullfile(root,'build',[model '.slx']);
assert(isfile(file),'Missing model: %s',file);
run(fullfile(root,'parameters','init_wind_dfig_average_r1.m'));
load_system(file);cleanup=onCleanup(@()closeIfLoaded(model));

plant=[model '/02 Wound-Rotor DFIG dq Plant'];
rsc=[model '/03 Rotor-Side Average Converter Control'];
gsc=[model '/04 DC Link and Grid-Side Average Converter'];
assert(getSimulinkBlockHandle([plant '/Flux State Integrator'])>0);
assert(getSimulinkBlockHandle([plant '/Flux to Current Matrix'])>0);
assert(getSimulinkBlockHandle([rsc '/Vdr Average Bridge Limit'])>0);
assert(getSimulinkBlockHandle([rsc '/Circular Limit Scale'])>0);
assert(getSimulinkBlockHandle([gsc '/DC Voltage State'])>0);
assert(getSimulinkBlockHandle([gsc '/Average GSC d Limit'])>0);
assert(isempty(find_system(model,'LookUnderMasks','all','MaskType','MATLAB Function')));
assert(isempty(find_system(model,'RegExp','on','Name','.*(Carrier|Comparator|PWM).*')));
set_param(model,'SimulationCommand','update');

out=sim(model);logs=out.logsout;
omega=firstTimeseries(logs,'OmegaGen');te=firstTimeseries(logs,'Te');
tm=firstTimeseries(logs,'TmCommand');vdc=firstTimeseries(logs,'Vdc');
slip=firstTimeseries(logs,'Slip');p=firstTimeseries(logs,'P_PCC');
q=firstTimeseries(logs,'Q_PCC');ir=firstTimeseries(logs,'Irdq');
irRef=firstTimeseries(logs,'IrReference');

pre=[0.20 0.30];post=[0.55 0.60];
Ppre=meanWindow(p,pre);Ppost=meanWindow(p,post);
Qpost=meanWindow(q,post);VdcPost=meanWindow(vdc,post);
OmegaPost=meanWindow(omega,post);SlipPost=meanWindow(slip,post);
TePost=meanWindow(te,post);TmPost=meanWindow(tm,post);
Ir=matrixWindow(ir,post);IrRef=matrixWindow(irRef,post);
IrMag=max(sqrt(sum(Ir.^2,2)));trackRms=sqrt(mean((Ir-IrRef).^2,'all'));

allMetrics=[Ppre Ppost Qpost VdcPost OmegaPost SlipPost TePost TmPost IrMag trackRms];
assert(all(isfinite(allMetrics)),'Non-finite DFIG dynamic result.');
assert(Ppre>2.5e6&&Ppre<4.0e6,'Unexpected pre-step active power.');
assert(Ppost>Ppre+0.40e6,'Wind-speed step did not increase grid active power.');
assert(abs(Qpost)<0.15*DFIG.Base.Sn,'PCC reactive power exceeds acceptance band.');
assert(VdcPost>0.88*DFIG.DC.Vnom&&VdcPost<1.12*DFIG.DC.Vnom, ...
    'DC voltage is outside the average-converter acceptance band.');
assert(OmegaPost>0.85*DFIG.Machine.wSyncMech&&OmegaPost<1.10*DFIG.Machine.wSyncMech, ...
    'Generator speed is outside the intended DFIG speed range.');
assert(SlipPost>0,'R1 wind step should remain in subsynchronous operation.');
assert(TePost<0&&TmPost>0,'Generating torque sign convention is inconsistent.');
assert(IrMag<1.01*DFIG.RSC.Imax,'RSC current exceeded the circular limit.');
assert(trackRms<0.10*DFIG.RSC.Imax,'Rotor-current tracking error is excessive.');

fprintf('WIND_DFIG_STRUCTURE_OK=1\n');
fprintf('WIND_DFIG_AVERAGE_CONVERTERS_OK=1\n');
fprintf('WIND_DFIG_DYNAMIC_OK=1\n');
fprintf(['P_PRE_MW=%.6f P_POST_MW=%.6f Q_POST_MVAR=%.6f VDC_POST_V=%.3f ' ...
    'SPEED_PU=%.6f SLIP_HZ=%.6f IR_MAX_A=%.3f IR_TRACK_RMS_A=%.3f\n'], ...
    Ppre/1e6,Ppost/1e6,Qpost/1e6,VdcPost, ...
    OmegaPost/DFIG.Machine.wSyncMech,SlipPost/(2*pi),IrMag,trackRms);
clear cleanup

function ts=firstTimeseries(logs,name)
e=logs.get(name);assert(~isempty(e),'Logged signal not found: %s',name);
ts=e.Values;
end
function y=meanWindow(ts,window)
x=squeeze(ts.Data);t=ts.Time(:);if size(x,1)~=numel(t),x=x.';end
x=x(t>=window(1)&t<=window(2),:);y=mean(x,'all');
end
function x=matrixWindow(ts,window)
x=squeeze(ts.Data);t=ts.Time(:);if size(x,1)~=numel(t),x=x.';end
x=x(t>=window(1)&t<=window(2),:);
end
function closeIfLoaded(model)
if bdIsLoaded(model),close_system(model,0);end
end
