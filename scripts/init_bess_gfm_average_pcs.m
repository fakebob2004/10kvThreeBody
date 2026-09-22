% Parameters for the standalone bidirectional average-value BESS-GFM PCS.
run(fullfile(fileparts(mfilename('fullpath')),'init_bess_gfm_stage.m'));
G.revision = 'R5-BESS-GFM-average-PCS-2026-09-19';

% A 1200 V battery can directly support a 690 V line-line converter:
% Vdc,min = 2*sqrt(2)*Vll/sqrt(3) = 1126.8 V before control margin.
G.dc.Vbattery_V = 1200;
G.dc.Rbattery_ohm = 0.006;
G.dc.Cdc_F = 0.05;
G.dc.Vdc_min_V = 2*sqrt(2/3)*G.ac.Vll_low_V;
G.dc.modulation_max = 0.98;
G.dc.kmod = 2*sqrt(2/3);
G.dc.Irated_A = G.bess.P_W/G.dc.Vbattery_V;
G.control.Vdc_filter_s = 5e-4;

fprintf('Average PCS: Vdc,min=%.1f V, battery=%.0f V, Irated=%.1f A\n', ...
    G.dc.Vdc_min_V,G.dc.Vbattery_V,G.dc.Irated_A);
assignin('base','G',G);
