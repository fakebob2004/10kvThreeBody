run(fullfile(fileparts(mfilename('fullpath')),'init_bess_transient_r9.m'));
% H on the 5 MW active-power base, not on the 6.25 MVA converter base.
G.vsm.H=5;G.vsm.D=G.f0_Hz/(G.control.mp_Hz_per_W*G.bess.P_W);
G.vsm.Pset_W=0;G.vsm.rise_s=.10;G.vsm.guard=.94;
% Charged DC bus; no initial AC load current/flux is prescribed.
G.dcdc.Iref_initial_A=0;
assignin('base','G',G);
