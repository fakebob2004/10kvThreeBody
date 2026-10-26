%DIAGNOSE_WIND_COURSE_OPERATING_POINT_R2 Honest 80 ms operating-point audit.
root=fileparts(fileparts(mfilename('fullpath')));
model='Wind_DirectDrive_SPWM_R2';
load_system(fullfile(root,'build',[model '.slx']));
cleanupModel=onCleanup(@() closeIfLoaded(model));
set_param(model,'StopTime','0.08');
out=sim(model);logs=out.logsout;
vdc=firstTimeseries(logs,'Vdc_Meas');
p=firstTimeseries(logs,'P_PCC');q=firstTimeseries(logs,'Q_PCC');
pmsc=firstTimeseries(logs,'P_msc_W');
iabc=firstTimeseries(logs,'Iabc_Converter_Meas');
vll=firstTimeseries(logs,'Vll_inv');
idRaw=firstTimeseries(logs,'Id_cmd_raw');
idRef=firstTimeseries(logs,'Id_ref_lim');
iqRef=firstTimeseries(logs,'Iq_ref_lim');
idMeas=firstTimeseries(logs,'Id_converter');
iqMeas=firstTimeseries(logs,'Iq_converter');
mod=firstTimeseries(logs,'Vabc_mod');
vd=firstTimeseries(logs,'Vd_pcc_lv');
vq=firstTimeseries(logs,'Vq_pcc_lv');
ix=vdc.Time>=0.06;
VdcMean=mean(vdc.Data(ix));
pw=vectorWindow(p,0.06);qw=vectorWindow(q,0.06);
PMean=mean(pw);QMean=mean(qw);
PmscMean=mean(pmsc.Data(pmsc.Time>=0.06));
[Irms,Ipos,Ineg]=threePhaseAudit(iabc,0.06,Base.f);
[Vrms,Vpos,Vneg]=threePhaseAudit(vll,0.06,Base.f);
PowerTransferValidated=abs(PMean-PmscMean)<0.15*max(PmscMean,1) && ...
    abs(QMean)<0.10*6.25e6 && Ineg/max(Ipos,1)<0.05;
fprintf('VdcMean_V=%.9g\nP_PCC_Mean_W=%.9g\nQ_PCC_Mean_var=%.9g\n', ...
    VdcMean,PMean,QMean);
fprintf('P_PCC_MinMax_W=[%.9g %.9g]\nQ_PCC_MinMax_var=[%.9g %.9g]\n', ...
    min(pw),max(pw),min(qw),max(qw));
fprintf('Iabc_RMS_A=[%.9g %.9g %.9g]\nI_NEG_POS_RATIO=%.9g\n', ...
    Irms,Ineg/max(Ipos,eps));
fprintf('Vll_RMS_V=[%.9g %.9g %.9g]\nV_NEG_POS_RATIO=%.9g\n', ...
    Vrms,Vneg/max(Vpos,eps));
fprintf('ID_RAW_REF_MEAS_MEAN_A=[%.9g %.9g %.9g]\n', ...
    mean(vectorWindow(idRaw,0.06)),mean(vectorWindow(idRef,0.06)), ...
    mean(vectorWindow(idMeas,0.06)));
fprintf('IQ_REF_MEAS_MEAN_A=[%.9g %.9g]\n', ...
    mean(vectorWindow(iqRef,0.06)),mean(vectorWindow(iqMeas,0.06)));
mw=matrixWindow(mod,0.06);
fprintf('MODULATION_MIN_MAX=[%.9g %.9g]\n',min(mw(:)),max(mw(:)));
fprintf('VDQ_PCC_MEAN_V=[%.9g %.9g]\n', ...
    mean(vectorWindow(vd,0.06)),mean(vectorWindow(vq,0.06)));
fprintf('P_msc_Mean_W=%.9g\nPowerTransferValidated=%s\n', ...
    PmscMean,mat2str(PowerTransferValidated));
clear cleanupModel

function x=vectorWindow(ts,t0)
x=reshape(ts.Data,[],1);
x=x(ts.Time>=t0);
end

function x=matrixWindow(ts,t0)
x=squeeze(ts.Data);t=ts.Time(:);
if size(x,1)~=numel(t),x=x.';end
x=x(t>=t0,:);
end

function [phaseRms,posMag,negMag]=threePhaseAudit(ts,t0,f)
t=ts.Time(:);x=squeeze(ts.Data);
if size(x,1)~=numel(t),x=x.';end
keep=t>=t0;t=t(keep);x=x(keep,:);
phaseRms=sqrt(mean(x.^2,1));
tu=linspace(t(1),t(end),2001).';
xu=interp1(t,x,tu,'linear');
X=(2/numel(tu))*sum(xu.*exp(-1j*2*pi*f*tu),1);
a=exp(1j*2*pi/3);
posMag=abs((X(1)+a*X(2)+a^2*X(3))/3);
negMag=abs((X(1)+a^2*X(2)+a*X(3))/3);
end

function ts=firstTimeseries(logs,name)
for k=1:logs.numElements
    element=logs{k};
    if strcmp(element.Name,name) && isa(element.Values,'timeseries')
        ts=element.Values;
        return
    end
end
error('Logged timeseries not found: %s',name);
end

function closeIfLoaded(model)
if bdIsLoaded(model),close_system(model,0);end
end
