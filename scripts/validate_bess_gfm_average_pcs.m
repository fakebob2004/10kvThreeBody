% Validate bidirectional power flow of the standalone BESS-GFM average PCS.
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
run(fullfile(scriptDir,'init_bess_gfm_average_pcs.m'));
modelName = 'BESS_GFM_10kV_AveragePCS_R5';
modelFile = fullfile(projectRoot,'build',[modelName '.slx']);
resultPng = fullfile(projectRoot,'build',[modelName '_results.png']);
load_system(modelFile);
set_param(modelName,'InitFcn','');
set_param(modelName,'StopTime','0.7');
loadBlock = [modelName '/Adjusted_Island_Load'];

% Case 1: BESS supplies an islanded load.
set_param(loadBlock,'active_power','1.5e6','reactive_power','0.30e6');
outDischarge = sim(modelName);
d = normalize_result(outDischarge.get('gfm_pcs_result'));

% Case 2: an external surplus injects 0.5 MW, so the BESS must absorb it.
% A negative constant-power load is an AC-side source in this isolated test.
set_param(loadBlock,'active_power','-0.5e6','reactive_power','0');
outCharge = sim(modelName);
c = normalize_result(outCharge.get('gfm_pcs_result'));

ds = steady_values(d); cs = steady_values(c);
check_case(ds,G,true);
check_case(cs,G,false);
assert(ds.P > 0 && ds.Idc > 0 && d(end,6) < d(1,6), ...
    'Discharge direction is inconsistent.');
assert(cs.P < 0 && cs.Idc < 0 && c(end,6) > c(1,6), ...
    'Charge/absorption direction is inconsistent.');

fig = figure('Visible','off','Color','w','Position',[100 100 1120 720]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
nexttile; plot(d(:,1),d(:,2)/1e6,'LineWidth',1.2); hold on;
plot(c(:,1),c(:,2)/1e6,'LineWidth',1.2); yline(0,'k:'); grid on;
xlabel('Time (s)'); ylabel('P (MW)'); title('Bidirectional AC power');
legend('Discharge','Charge','Location','best');
nexttile; plot(d(:,1),d(:,8),'LineWidth',1.2); hold on;
plot(c(:,1),c(:,8),'LineWidth',1.2); yline(0,'k:'); grid on;
xlabel('Time (s)'); ylabel('I_{dc} (A)'); title('Battery current');
nexttile; plot(d(:,1),d(:,7),'LineWidth',1.2); hold on;
plot(c(:,1),c(:,7),'LineWidth',1.2); grid on;
xlabel('Time (s)'); ylabel('V_{dc} (V)'); title('DC-link voltage');
nexttile; yyaxis left; plot(d(:,1),d(:,4),'LineWidth',1.2); hold on;
plot(c(:,1),c(:,4),'LineWidth',1.2); ylabel('Frequency (Hz)');
yyaxis right; plot(d(:,1),d(:,6),'--','LineWidth',1.2); hold on;
plot(c(:,1),c(:,6),'--','LineWidth',1.2); ylabel('SOC'); grid on;
xlabel('Time (s)'); title('Droop frequency and SOC');
exportgraphics(fig,resultPng,'Resolution',160); close(fig);

fprintf(['BESS_GFM_AVERAGE_PCS_VALIDATION_PASS=1\n' ...
    'DISCHARGE: P=%.4f MW Q=%.4f Mvar Vdc=%.2f V Idc=%.2f A ' ...
    'Pdc=%.4f MW f=%.5f Hz m=%.4f\n' ...
    'CHARGE: P=%.4f MW Q=%.4f Mvar Vdc=%.2f V Idc=%.2f A ' ...
    'Pdc=%.4f MW f=%.5f Hz m=%.4f\nRESULT_PNG=%s\n'], ...
    ds.P/1e6,ds.Q/1e6,ds.Vdc,ds.Idc,ds.Pdc/1e6,ds.f,ds.m, ...
    cs.P/1e6,cs.Q/1e6,cs.Vdc,cs.Idc,cs.Pdc/1e6,cs.f,cs.m,resultPng);
close_system(modelName,0);

function r=normalize_result(raw)
r=squeeze(raw); if size(r,2)~=10, r=r.'; end
assert(size(r,2)==10 && all(isfinite(r),'all'),'Invalid PCS result array.');
end
function s=steady_values(r)
tail=r(:,1)>=r(end,1)-0.08;
x=mean(r(tail,:),1);
s=struct('P',x(2),'Q',x(3),'f',x(4),'Vcmd',x(5),'SOC',x(6), ...
    'Vdc',x(7),'Idc',x(8),'m',x(9),'Pdc',x(10));
end
function check_case(s,G,isDischarge)
assert(hypot(s.P,s.Q)<G.bess.S_VA,'PCS apparent-power rating exceeded.');
assert(abs(s.P)<G.bess.P_W,'BESS active-power rating exceeded.');
assert(abs(s.Idc)<1.2*G.dc.Irated_A,'Battery DC current exceeds 1.2 pu.');
assert(s.Vdc>G.dc.Vdc_min_V && s.Vdc<1.08*G.dc.Vbattery_V, ...
    'DC-link voltage outside the feasible modulation range.');
assert(s.m>0 && s.m<G.dc.modulation_max,'Modulation saturation reached.');
assert(abs(s.f-(G.f0_Hz-G.control.mp_Hz_per_W*s.P))<3e-3, ...
    'P-f droop equation mismatch.');
assert(abs(s.Vcmd-(G.ac.Vll_low_V-G.control.nq_V_per_var*s.Q))<0.3, ...
    'Q-V droop equation mismatch.');
if isDischarge
    assert(s.Pdc>0,'Expected positive battery power during discharge.');
else
    assert(s.Pdc<0,'Expected negative battery power during charging.');
end
end
