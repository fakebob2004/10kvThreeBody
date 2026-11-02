%VALIDATE_WIND_PMSG_TRANSIENT_R4 PLL, energy conversion and switching checks.
root=fileparts(fileparts(mfilename('fullpath')));model='Wind_PMSG_Transient_R4';
file=fullfile(root,'build',[model '.slx']);assert(isfile(file),'Missing R4 model.');
run(fullfile(root,'parameters','init_wind_pmsg_transient_r4.m'));
load_system(file);cleanup=onCleanup(@()closeIfLoaded(model));
control=[model '/04 GFL Control and SPWM'];
assert(getSimulinkBlockHandle([control '/PLL Angle for Control'])>0,'Active PLL source missing.');
assert(strcmp(get_param([control '/PLL Angle for Control'],'GotoTag'),'THETA_PLL_DIAG'));
assert(strcmp(get_param([control '/PLL Angle Alignment'],'Bias'),'Control.PLL.ControlAngleBias'));
ph=get_param([control '/PLL Angle Alignment'],'PortHandles');ln=get_param(ph.Inport(1),'Line');
src=get_param(get_param(ln,'SrcPortHandle'),'Parent');
assert(strcmp(src,[control '/PLL Angle for Control']),'Control angle is not sourced by the PLL.');
assert(getSimulinkBlockHandle([control '/Nominal Angle Monitor'])>0, ...
    'Nominal angle must remain monitor-only.');
set_param(model,'SimulationCommand','update');set_param(model,'StopTime','0.080');
out=sim(model);logs=out.logsout;
pa=ts(logs,'P_aero_W');pdc=ts(logs,'P_msc_W');ppcc=ts(logs,'P_PCC');
vdc=ts(logs,'Vdc_Meas');omega=ts(logs,'omega_PLL');vq=ts(logs,'Vq_pcc_lv');
win=[0.065 0.080];Pa=meanWindow(pa,win);Pdc=meanWindow(pdc,win);Ppcc=meanWindow(ppcc,win);
Vdc=meanWindow(vdc,win);Fpll=meanWindow(omega,win)/(2*pi);Vq=meanWindow(vq,win);
eta=Pdc/Pa;
gates={'Gate_AH','Gate_AL','Gate_BH','Gate_BL','Gate_CH','Gate_CL'};g=[];
for k=1:6,x=ts(logs,gates{k});if isempty(g),g=zeros(numel(x.Data),6);end;g(:,k)=x.Data(:);end
comp=max(abs(g(:,1)+g(:,2)-1))+max(abs(g(:,3)+g(:,4)-1))+max(abs(g(:,5)+g(:,6)-1));
fprintf(['R4_PAERO_W=%.9g\nR4_PMSC_W=%.9g\nR4_PPCC_W=%.9g\n' ...
 'R4_MSC_OVER_AERO=%.9g\nR4_VDC_V=%.9g\nR4_PLL_HZ=%.9g\nR4_VQ_PCC_LV=%.9g\n'], ...
 Pa,Pdc,Ppcc,eta,Vdc,Fpll,Vq);
assert(all(isfinite([Pa Pdc Ppcc eta Vdc Fpll Vq])),'Nonfinite R4 result.');
assert(eta>PMSG.Validation.minimum_msc_efficiency&&eta<1,'PMSG/MSC efficiency is outside range.');
assert(abs(Ppcc-Pdc)<0.12*Pdc,'PCC power does not follow MSC power.');
assert(Vdc>PMSG.Validation.vdc_min_V&&Vdc<PMSG.Validation.vdc_max_V,'Vdc out of range.');
assert(Fpll>PMSG.Validation.pll_frequency_min_Hz&&Fpll<PMSG.Validation.pll_frequency_max_Hz, ...
 'PLL frequency out of range.');
assert(abs(Vq)<0.08*Base.Vll_lv,'PLL-aligned PCC q voltage is excessive.');
assert(isequal(unique(g(:)).',[0 1])&&comp==0,'Switching gates invalid.');
fprintf('WIND_PMSG_TRANSIENT_R4_PLL_ACTIVE_OK=1\n');
fprintf('WIND_PMSG_TRANSIENT_R4_POWER_CHAIN_OK=1\n');
fprintf('WIND_PMSG_TRANSIENT_R4_SWITCHING_OK=1\n');
clear cleanup
function x=ts(logs,name)
for k=1:logs.numElements,e=logs{k};if strcmp(e.Name,name)&&isa(e.Values,'timeseries'),x=e.Values;return,end,end
error('Missing log: %s',name);
end
function v=meanWindow(x,w),k=x.Time>=w(1)&x.Time<=w(2);assert(any(k));v=mean(x.Data(k));end
function closeIfLoaded(m),if bdIsLoaded(m),close_system(m,0);end,end
