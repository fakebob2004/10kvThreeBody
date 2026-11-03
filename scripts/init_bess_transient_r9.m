run(fullfile(fileparts(mfilename('fullpath')),'init_bess_gfm_dynamic_r7.m'));
% Illustrative aggregated pack, not an OEM OCV curve or pulse-test fit.
G.r9.R0=0.002; G.r9.Rp=0.001; G.r9.tau=1.5;
G.r9.Ts=25e-6; G.r9.wi=2*pi*400; G.r9.wv=2*pi*45;
G.r9.Ipk=sqrt(2)*G.control.Iac_limit_A;
assignin('base','G',G);
