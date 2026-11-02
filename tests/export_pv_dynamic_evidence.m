function export_pv_dynamic_evidence(out)
%EXPORT_PV_DYNAMIC_EVIDENCE Export model hierarchy and simulated waveforms.
root=fileparts(fileparts(mfilename('fullpath')));setup_v2_paths;
dirpath=fullfile(root,'docs','evidence','pv_dynamic');if ~exist(dirpath,'dir'),mkdir(dirpath);end
m='pv_resource_dynamic_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
scopes={m,[m '/PV Resource'],[m '/PV Resource/01 PV Source and DC Side'], ...
 [m '/PV Resource/02 PCS'],[m '/PV Resource/02 PCS/02 DC Voltage and dq Current']};
names={'assembly','resource','source_dc','pcs','controller'};
for k=1:numel(scopes),v2_render(scopes{k},fullfile(dirpath,[names{k} '.png']));end
x=out.pv_dynamic;t=x.Time(:);a=x.Data;
fig=figure('Visible','off','Color','w','Position',[100 100 1000 900]);
tiledlayout(4,1,'TileSpacing','compact');
nexttile;plot(t,a(:,22)/1e6,t,a(:,23)/1e6,'LineWidth',1);grid on;ylabel('P, Q (MW, Mvar)');legend('P_{PCC}','Q_{PCC}','Location','best');
nexttile;plot(t,a(:,3),'LineWidth',1);grid on;ylabel('V_{dc} (V)');
nexttile;plot(t,a(:,1),t,a(:,6),'LineWidth',1);grid on;ylabel('PV voltage (V)');legend('Measured','MPPT / curtailment target','Location','best');
nexttile;plot(t,hypot(a(:,9),a(:,10)),'LineWidth',1);grid on;ylabel('Current (A peak)');xlabel('Time (s)');
exportgraphics(fig,fullfile(dirpath,'dispatch_waveforms.png'),'Resolution',150);close(fig);
end
