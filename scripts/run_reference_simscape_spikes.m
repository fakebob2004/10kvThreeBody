function run_reference_simscape_spikes(stopTime)
% Original upstream plant/controller, native temporary-fault scenario.
if nargin<1,stopTime=4;end
root=fileparts(fileparts(mfilename('fullpath')));
ref=fullfile(root,'references','Renewable-Energy-Integration-Simscape-master');
outdir=fullfile(root,'artifacts','reference_spike_audit');
outdir=fullfile(outdir,sprintf('simscape_raw_%gs',stopTime));
if ~exist(outdir,'dir'),mkdir(outdir);end
addpath(genpath(ref));m='BatteryStoragePVPlantGFM';load_system(m);
% Parameters are loaded into base workspace by the model PreLoadFcn.
assignin('base','BESSControl',1); % native VSM grid-forming variant
S=evalin('base','Scenario');S.number=4;S.t_event=1.5;
p=BatteryStoragePVPlantGFMSettingScenario(4,stopTime,1.5);
fields={'Fault_distance','Fault_time','Fault_duration','Load_switching_time', ...
    'Solar_flactuation_time','Grid_outage_time','Line_trip_time'};
for k=1:7,S.(fields{k})=p(k);end
assignin('base','Scenario',S);assignin('base','SimulationTime',stopTime);
fprintf('UPSTREAM_GFM_RUN fault=%.6g clear=%.6g Ts=%.9g\n',S.Fault_time,S.Fault_time+S.Fault_duration,evalin('base','Ts'));
% Native Vabc_pcc passes a 0.5 ms measurement filter. Log BEFORE it.
rawBlock=[m '/Measurements & PLL/' sprintf('PS-Simulink\nConverter2')];
ph=get_param(rawBlock,'PortHandles');
set_param(ph.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom', ...
    'DataLoggingName','RAW_PCC_VABC_BEFORE_FILTER');
o=sim(m,'StopTime',num2str(stopTime),'ReturnWorkspaceOutputs','on');
logs=o.get('logs_ee_spv_park_battery');
disp(logs.getElementNames);
abc=logs.get('RAW_PCC_VABC_BEFORE_FILTER').Values;mag=logs.get('Vmag_pcc').Values;
filteredAbc=logs.get('Vabc_pcc').Values;
t=abc.Time(:);v=squeeze(abc.Data);if size(v,1)~=numel(t),v=v';end
% Preserve original logged values; don't assume phase-peak versus RMS base.
envelope=sqrt(sum(v.^2,2)/3);pre=t>1.4&t<1.49;
base=mean(envelope(pre));relative=envelope/base;
windows=[0 .03;0 .6;1.6 1.601;1.6 1.62;1.6 stopTime];
metrics=zeros(size(windows,1),5);
for k=1:size(windows,1)
    ix=find(t>=windows(k,1)&t<=windows(k,2));
    [peak,j]=max(relative(ix));
    metrics(k,:)=[windows(k,:) peak t(ix(j)) max(abs(v(ix,:)),[],'all')];
end
T=array2table(metrics,'VariableNames',{'start_s','end_s','peak_vs_prefault','peak_time_s','max_abs_logged_abc'});
disp(T);writetable(T,fullfile(outdir,'simscape_original_gfm_spikes.csv'));
save(fullfile(outdir,'simscape_original_gfm_waveforms.mat'),'abc','filteredAbc','mag','S','base','T','-v7.3');
fig=figure('Visible','off','Position',[20 20 1200 800]);tiledlayout(2,2);
nexttile;plot(t,v);xlim([0 .03]);title('Startup: original Vabc PCC log');grid on;
nexttile;plot(t,relative);xlim([0 .03]);title('Startup vector magnitude / prefault magnitude');grid on;
nexttile;plot(t,v);xlim([1.599 1.62]);title('Clearing: original Vabc PCC log');grid on;
nexttile;plot(t,relative);xlim([1.599 1.62]);title('Clearing vector magnitude / prefault magnitude');grid on;
exportgraphics(fig,fullfile(outdir,'simscape_original_gfm_spikes.png'),'Resolution',150);close(fig);
fig=figure('Visible','off','Position',[20 20 1200 600]);tiledlayout(2,1);
nexttile;plot(t,relative);xline(1.5);xline(1.6);ylabel('Vector magnitude / prefault');grid on;
nexttile;plot(t,v);xline(1.5);xline(1.6);ylabel('Original Vabc PCC log');xlabel('Time (s)');grid on;
exportgraphics(fig,fullfile(outdir,'simscape_full_event.png'),'Resolution',150);close(fig);
close_system(m,0);fprintf('SIMSCAPE_ORIGINAL_GFM_SPIKE_AUDIT_COMPLETE=1\n');
end
