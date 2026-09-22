% Validate R8 SOC-direction protection without forcing an unsupplied island.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
run(fullfile(scriptDir,'init_bess_gfm_dynamic_r7.m'));
modelName='BESS_GFM_10kV_Readable_R8';
load_system(fullfile(projectRoot,'build',[modelName '.slx']));
cleanup=onCleanup(@()close_system(modelName,0)); %#ok<NASGU>
ctrl=[modelName '/01 BESS DC Source/02 Bidirectional DC-DC Control'];

discharge=[ctrl '/SOC_Discharge_Allowed'];
charge=[ctrl '/SOC_Charge_Allowed'];
upperGain=[ctrl '/Discharge_Current_Limit'];
lowerGain=[ctrl '/Charge_Current_Limit'];
limit=[ctrl '/DC_Current_Limit'];
assert(strcmp(get_param(discharge,'relop'),'>') && ...
    strcmp(get_param(discharge,'const'),'G.bess.SOC_min'), ...
    'Discharge permission is not tied to SOC > SOC_min.');
assert(strcmp(get_param(charge,'relop'),'<') && ...
    strcmp(get_param(charge,'const'),'G.bess.SOC_max'), ...
    'Charge permission is not tied to SOC < SOC_max.');
assert(strcmp(get_param(upperGain,'Gain'),'G.dcdc.Iref_limit_A'), ...
    'Discharge current bound is incorrect.');
assert(strcmp(get_param(lowerGain,'Gain'),'-G.dcdc.Iref_limit_A'), ...
    'Charge current bound is incorrect.');

% Saturation Dynamic port order: upper limit, requested current, lower limit.
expected={'Discharge_Current_Limit','Hardware_Current_Limit','Charge_Current_Limit'};
ph=get_param(limit,'PortHandles');
for k=1:3
    line=get_param(ph.Inport(k),'Line');
    assert(line>0,'SOC current limiter input %d is unconnected.',k);
    source=get_param(get_param(line,'SrcPortHandle'),'Parent');
    assert(strcmp(get_param(source,'Name'),expected{k}), ...
        'SOC current limiter input %d comes from %s, expected %s.', ...
        k,get_param(source,'Name'),expected{k});
end

% Four direction cases. Positive battery current means discharge.
I=G.dcdc.Iref_limit_A;
sat=@(request,lower,upper)min(max(request,lower),upper);
lowForbidden=sat(+I,-I,0);
lowRecovery=sat(-I,-I,0);
highForbidden=sat(-I,0,+I);
highRecovery=sat(+I,0,+I);
assert(lowForbidden==0 && lowRecovery==-I, ...
    'SOC_min truth table does not block only discharge.');
assert(highForbidden==0 && highRecovery==I, ...
    'SOC_max truth table does not block only charge.');

fprintf(['BESS_GFM_R8_SOC_LIMITS_PASS=1\n' ...
    'SOC_MIN: discharge=%g A, recovery_charge=%g A\n' ...
    'SOC_MAX: charge=%g A, recovery_discharge=%g A\n'], ...
    lowForbidden,lowRecovery,highForbidden,highRecovery);
