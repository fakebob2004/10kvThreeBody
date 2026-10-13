%VALIDATE_WIND_COURSE_AVERAGE Structural and dynamic acceptance checks.
root=fileparts(fileparts(mfilename('fullpath')));
model='Wind_DirectDrive_Average';
file=fullfile(root,'models','resources',[model '.slx']);
assert(isfile(file),'Missing model: %s',file);
run(fullfile(root,'parameters','init_wind_course_average.m'));
load_system(file);cleanup=onCleanup(@()closeIfLoaded(model));

plant=[model '/03 DC Link and Average GSC'];
control=[model '/04 GFL Control'];
assert(getSimulinkBlockHandle([plant '/Averaged-Switch Three-Phase Bridge'])>0);
assert(strcmp(get_param([plant '/Averaged-Switch Three-Phase Bridge'], ...
    'device_type'),'ee.enum.converters.switchingdevice.averaged'));
assert(getSimulinkBlockHandle([plant '/Two-Level Three-Phase Bridge'])<0);
assert(getSimulinkBlockHandle([control '/06 SPWM and Physical Gate Interface'])<0);
assert(getSimulinkBlockHandle([control '/06 Average Duty Interface/One Control-Step Delay'])>0);
assert(getSimulinkBlockHandle([control '/06 Average Duty Interface/Triangular Carrier'])<0);
assert(getSimulinkBlockHandle([control '/PLL Angle for Control'])>0);
assert(strcmp(get_param([control '/PLL Angle for Control'],'GotoTag'),'THETA_PLL_DIAG'));
assert(strcmp(get_param([control '/PLL Angle Alignment'],'Bias'), ...
    'Control.PLL.ControlAngleBias'));
assert(getSimulinkBlockHandle([control '/Nominal Angle Monitor'])>0);
set_param(model,'SimulationCommand','update');

set_param(model,'StopTime','0.20');
out=sim(model);logs=out.logsout;
p=firstTimeseries(logs,'P_PCC');q=firstTimeseries(logs,'Q_PCC');
vdc=firstTimeseries(logs,'Vdc_Meas');pmsc=firstTimeseries(logs,'P_msc_W');
omega=firstTimeseries(logs,'omega_PLL');mod=firstTimeseries(logs,'Vabc_mod');
P=meanWindow(p,0.17);Q=meanWindow(q,0.17);Vdc=meanWindow(vdc,0.17);
Pmsc=meanWindow(pmsc,0.17);Omega=meanWindow(omega,0.17);
M=matrixWindow(mod,0.17);
fprintf('DIAG PMSC_MW=%.6f P_PCC_MW=%.6f Q_PCC_MVAR=%.6f VDC_V=%.3f F_PLL_HZ=%.5f MOD_MAX=%.6f\n', ...
    Pmsc/1e6,P/1e6,Q/1e6,Vdc,Omega/(2*pi),max(abs(M),[],'all'));
assert(all(isfinite([P Q Vdc Pmsc Omega])),'Non-finite dynamic result.');
assert(abs(P-Pmsc)<0.15*max(abs(Pmsc),1),'PCC power does not track MSC power.');
assert(abs(Q)<0.12*Base.Sn,'Reactive power exceeds the acceptance band.');
assert(Vdc>1400&&Vdc<1600,'DC link is outside 1400-1600 V.');
assert(Omega>2*pi*48&&Omega<2*pi*52,'PLL frequency is outside 48-52 Hz.');
assert(max(abs(M),[],'all')<=1.001*Converter.ModulationMax, ...
    'Average modulation exceeds its limiter.');

fprintf('WIND_AVERAGE_STRUCTURE_OK=1\n');
fprintf('WIND_AVERAGE_PLL_ACTIVE_OK=1\n');
fprintf('WIND_AVERAGE_DYNAMIC_OK=1\n');
fprintf('PMSC_MW=%.6f P_PCC_MW=%.6f Q_PCC_MVAR=%.6f VDC_V=%.3f F_PLL_HZ=%.5f MOD_MAX=%.6f\n', ...
    Pmsc/1e6,P/1e6,Q/1e6,Vdc,Omega/(2*pi),max(abs(M),[],'all'));
clear cleanup

function ts=firstTimeseries(logs,name)
for k=1:logs.numElements
    e=logs{k};
    if strcmp(e.Name,name)&&isa(e.Values,'timeseries'),ts=e.Values;return,end
end
error('Logged timeseries not found: %s',name);
end
function y=meanWindow(ts,t0)
x=reshape(ts.Data,[],1);y=mean(x(ts.Time>=t0));
end
function x=matrixWindow(ts,t0)
x=squeeze(ts.Data);t=ts.Time(:);if size(x,1)~=numel(t),x=x.';end
x=x(t>=t0,:);
end
function closeIfLoaded(model)
if bdIsLoaded(model),close_system(model,0);end
end
