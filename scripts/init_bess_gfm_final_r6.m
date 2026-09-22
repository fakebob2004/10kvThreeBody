% Final standalone BESS-GFM baseline for the 5 MW islanded project.
run(fullfile(fileparts(mfilename('fullpath')),'init_bess_gfm_average_pcs.m'));
G.revision = 'R6-BESS-GFM-final-5MW-10MWh-2026-09-19';

G.bess.P_W = 5.0e6;
G.bess.S_VA = 6.25e6;
G.bess.E_Wh = 10.0e6;
G.bess.Vbattery_V = 1200;
G.bess.capacity_Ah = G.bess.E_Wh/G.bess.Vbattery_V;
G.bess.SOC0 = 0.55;
G.bess.SOC_min = 0.20;
G.bess.SOC_max = 0.90;
G.bess.P_charge_max_W = 5.0e6;
G.bess.P_discharge_max_W = 5.0e6;

G.dc.Vbattery_V = 1200;
G.dc.Vdc_ref_V = 1500;
G.dc.Rbattery_ohm = 0.003;
G.dc.Cdc_F = 0.05;
G.dc.dcdc_efficiency_pct = 99;
G.dc.modulation_max = 0.98;
G.dc.kmod = 2*sqrt(2/3);
G.dc.Irated_A = G.bess.P_W/G.dc.Vbattery_V;
G.dc.Vdc_min_V = G.dc.kmod*G.ac.Vll_low_V/G.dc.modulation_max;

G.load.P_W = 5.0e6;
G.load.Q_var = 1.5e6;

% 0.5 Hz active-power droop at 5 MW; 5% voltage droop at 5 Mvar.
G.control.mp_Hz_per_W = 0.5/G.bess.P_W;
G.control.nq_V_per_var = 0.05*G.ac.Vll_low_V/G.bess.P_W;

% Recalculate the filter on the 6.25 MVA PCS base.
G.filter.Zbase_ohm = G.ac.Vll_low_V^2/G.bess.S_VA;
G.filter.L1_H = 0.08*G.filter.Zbase_ohm/G.w0_rad_s;
G.filter.L2_H = 0.03*G.filter.Zbase_ohm/G.w0_rad_s;
G.filter.R1_ohm = 0.005*G.filter.Zbase_ohm;
G.filter.R2_ohm = 0.005*G.filter.Zbase_ohm;
G.filter.C_F = 0.05*G.bess.S_VA/(G.w0_rad_s*G.ac.Vll_low_V^2);
G.filter.fres_Hz = (1/(2*pi))*sqrt((G.filter.L1_H+G.filter.L2_H)/ ...
    (G.filter.L1_H*G.filter.L2_H*G.filter.C_F));
G.filter.Rd_ohm = 1/(3*2*pi*G.filter.fres_Hz*G.filter.C_F);

G.transformer.S_VA = 6.3e6;
fprintf(['FINAL BESS-GFM: %.1f MW / %.1f MWh, %.0f V %.1f Ah, ' ...
    'DC link %.0f V, PCS %.2f MVA, transformer %.2f MVA\n'], ...
    G.bess.P_W/1e6,G.bess.E_Wh/1e6,G.bess.Vbattery_V, ...
    G.bess.capacity_Ah,G.dc.Vdc_ref_V,G.bess.S_VA/1e6, ...
    G.transformer.S_VA/1e6);
assignin('base','G',G);
