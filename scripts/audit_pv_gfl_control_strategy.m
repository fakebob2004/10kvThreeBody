% Read-only audit of the accepted PV-GFL R2.1 control strategy.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
file=fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx');
expected='1136cba422854210220e012f6b6657bc36e93da67c77325096dd45fd4c47fa35';
assert(strcmpi(sha256(file),expected),'Frozen PV-GFL R2.1 SHA-256 changed.');
model='PV_GFL_864_SystemLevel_SM_R2_1_Readable';load_system(file);
run(fullfile(scriptDir,'init_pv_gfl_r2_1.m'));
pv=[model '/01 PV-GFL Branch R2.1'];

% Interface and ownership.
ph=get_param(pv,'PortHandles');
assert(numel(ph.Inport)==1&&numel(ph.Outport)==1&&numel([ph.LConn ph.RConn])==1);
assert(~isempty(unique_block(pv,'02 Local SRF-PLL')));
assert(isempty(find_system(pv,'LookUnderMasks','all','BlockType','From','GotoTag','R8_theta')));

% Extract the implemented equations, not merely workspace design values.
p2i=unique_block(pv,'P to Id');q2i=unique_block(pv,'Q to Iq');
trackD=unique_block(pv,'Id Tracking');trackQ=unique_block(pv,'Iq Tracking');
circle=unique_block(pv,'Current Circle Factor');enable=unique_block(pv,'Enable Clamp');
assert(strcmp(get_param(p2i,'Expr'),'2*u(1)/(sqrt(3)*sqrt(u(2)^2+1))'));
assert(contains(get_param(q2i,'Expr'),'S1.filter.C_F'));
assert(strcmp(get_param(trackD,'Denominator'),'[1/(2*pi*S1.control.current_bandwidth_Hz) 1]'));
assert(strcmp(get_param(trackQ,'Denominator'),'[1/(2*pi*S1.control.current_bandwidth_Hz) 1]'));
assert(strcmp(get_param(circle,'UpperLimit'),'1')&&strcmp(get_param(circle,'LowerLimit'),'0'));
assert(strcmp(get_param(enable,'UpperLimit'),'1')&&strcmp(get_param(enable,'LowerLimit'),'0'));

w0=2*pi*S1.base.f_Hz;
Qpassive=w0*S1.filter.C_F*S1.pv.Vll_low_V^2;
fprintf(['PV_GFL_CONTROL_STRATEGY_AUDIT_PASS=1\n' ...
    'MODEL_SHA256=%s\n' ...
    'ARCHITECTURE=local_PCC_PLL__PQ_to_dq__enable_gate__circle_limit__150Hz_tracking__average_current_PCS\n' ...
    'PCS=%.3f_MVA  VLL=%.0f/%.0f_V  ILIMIT=%.3f_Apeak\n' ...
    'FILTER_L1=%.9g_H L2=%.9g_H C=%.9g_F FRES=%.3f_Hz PASSIVE_Q=%.3f_Mvar\n'], ...
    expected,S1.pv.S_pcs_VA/1e6,S1.pv.Vll_low_V,S1.pv.Vll_high_V, ...
    S21.control.Ilimit_peak_A,S1.filter.L1_H,S1.filter.L2_H,S1.filter.C_F, ...
    S1.filter.fres_Hz,Qpassive/1e6);
close_system(model,0);

function b=unique_block(root,name)
b=find_system(root,'LookUnderMasks','all','FollowLinks','on','Name',name);
assert(numel(b)==1,['Expected exactly one block named ' name]);b=b{1};
end
function h=sha256(file)
[ok,out]=system(sprintf('/usr/bin/shasum -a 256 "%s"',file));assert(ok==0);
h=extractBefore(strtrim(out),' ');
end
