%PLOT_WIND_DFIG_AVERAGE_R1_RESULTS Run R1 and export a compact result figure.
root=fileparts(fileparts(mfilename('fullpath')));model='Wind_DFIG_Average_R1';
run(fullfile(root,'parameters','init_wind_dfig_average_r1.m'));
load_system(fullfile(root,'build',[model '.slx']));cleanup=onCleanup(@()closeIfLoaded(model));
out=sim(model);logs=out.logsout;
omega=getTs(logs,'OmegaGen');vdc=getTs(logs,'Vdc');p=getTs(logs,'P_PCC');
q=getTs(logs,'Q_PCC');ir=getTs(logs,'Irdq');irRef=getTs(logs,'IrReference');

f=figure('Color','w','Position',[100 100 1100 720]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;plot(omega.Time,omega.Data/DFIG.Machine.wSyncMech,'LineWidth',1.4);grid on;
xline(DFIG.Wind.stepTime,'--');ylabel('Speed (pu)');xlabel('Time (s)');title('Generator speed');
nexttile;plot(vdc.Time,vdc.Data,'LineWidth',1.4);grid on;xline(DFIG.Wind.stepTime,'--');
yline(DFIG.DC.Vnom,':');ylabel('V_{dc} (V)');xlabel('Time (s)');title('DC-link voltage');
nexttile;plot(p.Time,p.Data/1e6,'LineWidth',1.4);hold on;plot(q.Time,q.Data/1e6,'LineWidth',1.2);grid on;
xline(DFIG.Wind.stepTime,'--');ylabel('Power (MW/Mvar)');xlabel('Time (s)');legend('P_{PCC}','Q_{PCC}','Location','best');title('PCC power');
nexttile;plot(ir.Time,ir.Data,'LineWidth',1.2);hold on;plot(irRef.Time,irRef.Data,'--','LineWidth',1.0);grid on;
xline(DFIG.Wind.stepTime,'--');ylabel('Rotor current (A)');xlabel('Time (s)');legend('i_{dr}','i_{qr}','i^*_{dr}','i^*_{qr}','Location','best');title('RSC current tracking');
sgtitle('Wind DFIG Average R1 — 9 to 10 m/s wind step at 0.35 s');
exportgraphics(f,fullfile(root,'build','WIND_DFIG_R1_07_Dynamics.png'),'Resolution',180);
close(f);fprintf('WIND_DFIG_RESULT_FIGURE_OK=1\n');clear cleanup

function ts=getTs(logs,name)
e=logs.get(name);assert(~isempty(e),'Missing logged signal: %s',name);ts=e.Values;
end
function closeIfLoaded(model)
if bdIsLoaded(model),close_system(model,0);end
end
