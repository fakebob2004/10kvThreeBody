% Bidirectional validation of the final 5 MW / 10 MWh BESS-GFM baseline.
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
run(fullfile(scriptDir,'init_bess_gfm_final_r6.m'));
modelName = 'BESS_GFM_10kV_Final_R6';
modelFile = fullfile(projectRoot,'build',[modelName '.slx']);
resultPng = fullfile(projectRoot,'build',[modelName '_results.png']);
load_system(modelFile);
set_param(modelName,'InitFcn','','StopTime','0.7');
loadBlock = [modelName '/Adjusted_Island_Load'];

% Worst-case loss of renewables: BESS supplies the nominal 5 MW island load.
set_param(loadBlock,'active_power','5.0e6','reactive_power','1.5e6');
outD = sim(modelName); d = normalize_result(outD.get('gfm_pcs_result'));

% Worst-case renewable surplus: negative load represents 5 MW AC injection.
set_param(loadBlock,'active_power','-5.0e6','reactive_power','0');
outC = sim(modelName); c = normalize_result(outC.get('gfm_pcs_result'));
ds = steady_values(d); cs = steady_values(c);

check_case(ds,G);
check_case(cs,G);
assert(ds.P>0 && ds.Ibat>0 && ds.Pbat>0 && d(end,6)<d(1,6), ...
    'Discharge direction/SOC is inconsistent.');
assert(cs.P<0 && cs.Ibat<0 && cs.Pbat<0 && c(end,6)>c(1,6), ...
    'Charge direction/SOC is inconsistent.');
assert(ds.P>0.98*G.bess.P_W && ds.P<1.03*G.bess.P_W, ...
    'The BESS does not supply the nominal 5 MW load.');
assert(cs.P<-0.98*G.bess.P_W && cs.P>-1.03*G.bess.P_W, ...
    'The BESS does not absorb the nominal 5 MW surplus.');

fig=figure('Visible','off','Color','w','Position',[100 100 1120 720]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
nexttile; plot(d(:,1),d(:,2)/1e6,'LineWidth',1.2); hold on;
plot(c(:,1),c(:,2)/1e6,'LineWidth',1.2); yline(0,'k:'); grid on;
xlabel('Time (s)'); ylabel('P (MW)'); title('5 MW bidirectional AC power');
legend('Discharge','Absorb surplus','Location','best');
nexttile; plot(d(:,1),d(:,8),'LineWidth',1.2); hold on;
plot(c(:,1),c(:,8),'LineWidth',1.2); yline(0,'k:'); grid on;
xlabel('Time (s)'); ylabel('Battery current (A)'); title('1200 V battery current');
nexttile; plot(d(:,1),d(:,7),'LineWidth',1.2); hold on;
plot(c(:,1),c(:,7),'LineWidth',1.2); grid on;
xlabel('Time (s)'); ylabel('V_{dc} (V)'); title('Regulated 1500 V DC link');
nexttile; yyaxis left; plot(d(:,1),d(:,4),'LineWidth',1.2); hold on;
plot(c(:,1),c(:,4),'LineWidth',1.2); ylabel('Frequency (Hz)');
yyaxis right; plot(d(:,1),d(:,6),'--','LineWidth',1.2); hold on;
plot(c(:,1),c(:,6),'--','LineWidth',1.2); ylabel('SOC'); grid on;
xlabel('Time (s)'); title('GFM droop and physical SOC change');
exportgraphics(fig,resultPng,'Resolution',160); close(fig);

fprintf(['BESS_GFM_FINAL_R6_VALIDATION_PASS=1\n' ...
    'DISCHARGE P=%.4f MW Q=%.4f Mvar S=%.4f MVA Vdc=%.2f V ' ...
    'Ibat=%.1f A Pbat=%.4f MW f=%.5f Hz m=%.4f SOCend=%.7f\n' ...
    'CHARGE P=%.4f MW Q=%.4f Mvar S=%.4f MVA Vdc=%.2f V ' ...
    'Ibat=%.1f A Pbat=%.4f MW f=%.5f Hz m=%.4f SOCend=%.7f\n' ...
    'RESULT_PNG=%s\n'], ...
    ds.P/1e6,ds.Q/1e6,ds.S/1e6,ds.Vdc,ds.Ibat,ds.Pbat/1e6,ds.f,ds.m,d(end,6), ...
    cs.P/1e6,cs.Q/1e6,cs.S/1e6,cs.Vdc,cs.Ibat,cs.Pbat/1e6,cs.f,cs.m,c(end,6), ...
    resultPng);
close_system(modelName,0);

function r=normalize_result(raw)
r=squeeze(raw); if size(r,2)~=10, r=r.'; end
assert(size(r,2)==10 && all(isfinite(r),'all'),'Invalid R6 result array.');
end
function s=steady_values(r)
x=mean(r(r(:,1)>=r(end,1)-0.08,:),1);
s=struct('P',x(2),'Q',x(3),'S',hypot(x(2),x(3)),'f',x(4), ...
    'Vcmd',x(5),'SOC',x(6),'Vdc',x(7),'Ibat',x(8),'m',x(9),'Pbat',x(10));
end
function check_case(s,G)
assert(s.S<G.bess.S_VA,'6.25 MVA PCS rating exceeded.');
assert(abs(s.Ibat)<1.10*G.dc.Irated_A,'Battery current exceeds 1.10 pu.');
assert(abs(s.Vdc-G.dc.Vdc_ref_V)<2,'1500 V DC link regulation failed.');
assert(s.m>0 && s.m<G.dc.modulation_max,'VSC modulation saturation reached.');
assert(abs(s.f-(G.f0_Hz-G.control.mp_Hz_per_W*s.P))<3e-3, ...
    'P-f droop equation mismatch.');
assert(abs(s.Vcmd-(G.ac.Vll_low_V-G.control.nq_V_per_var*s.Q))<0.3, ...
    'Q-V droop equation mismatch.');
end
