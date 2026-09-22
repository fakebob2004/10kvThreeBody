% Standalone BESS-GFM sizing for the first physical-control stage.
G = struct();
G.revision = 'R4-BESS-GFM-only-2026-09-18';
G.f0_Hz = 50;
G.w0_rad_s = 2*pi*G.f0_Hz;
G.bess.P_W = 2.5e6;
G.bess.S_VA = 3.15e6;
G.bess.E_Wh = 2.0e6;
G.bess.Vbattery_V = 1200;
G.bess.Vdc_V = 690*sqrt(2)*2/sqrt(3)*1.15;
G.bess.capacity_Ah = G.bess.E_Wh/G.bess.Vbattery_V;
G.bess.SOC0 = 0.60;
G.bess.SOC_min = 0.20;
G.bess.SOC_max = 0.90;
G.ac.Vll_low_V = 690;
G.ac.Vll_high_V = 10e3;
G.load.P_W = 1.5e6;
G.load.Q_var = 0.30e6;

% 0.5 Hz active-power droop at 2.5 MW and 5% voltage droop at 2.5 Mvar.
G.control.mp_Hz_per_W = 0.5/G.bess.P_W;
G.control.nq_V_per_var = 0.05*G.ac.Vll_low_V/G.bess.P_W;
G.control.P_filter_s = 0.05;
G.control.Q_filter_s = 0.05;

% LCL values on the reduced 3.15 MVA BESS PCS base.
G.filter.Zbase_ohm = G.ac.Vll_low_V^2/G.bess.S_VA;
G.filter.L1_H = 0.08*G.filter.Zbase_ohm/G.w0_rad_s;
G.filter.L2_H = 0.03*G.filter.Zbase_ohm/G.w0_rad_s;
G.filter.R1_ohm = 0.005*G.filter.Zbase_ohm;
G.filter.R2_ohm = 0.005*G.filter.Zbase_ohm;
G.filter.C_F = 0.05*G.bess.S_VA/(G.w0_rad_s*G.ac.Vll_low_V^2);
G.filter.fres_Hz = (1/(2*pi))*sqrt((G.filter.L1_H+G.filter.L2_H)/ ...
    (G.filter.L1_H*G.filter.L2_H*G.filter.C_F));
G.filter.Rd_ohm = 1/(3*2*pi*G.filter.fres_Hz*G.filter.C_F);

G.transformer.S_VA = G.bess.S_VA;
G.transformer.pu_Rw1 = 0.005;
G.transformer.pu_Rw2 = 0.005;
G.transformer.pu_Xl1 = 0.03;
G.transformer.pu_Xl2 = 0.03;

fprintf('BESS-GFM stage: %.2f MW / %.2f MWh, %.1f Ah at %.0f V\n', ...
    G.bess.P_W/1e6, G.bess.E_Wh/1e6, G.bess.capacity_Ah, G.bess.Vbattery_V);
fprintf('Adjusted island test load: %.2f MW + j%.2f Mvar\n', ...
    G.load.P_W/1e6, G.load.Q_var/1e6);
fprintf('GFM droop: mp=%.4f Hz/MW, nq=%.3f V/Mvar\n', ...
    1e6*G.control.mp_Hz_per_W, 1e6*G.control.nq_V_per_var);
assignin('base','G',G);
