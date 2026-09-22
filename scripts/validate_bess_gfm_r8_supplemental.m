% Supplemental Stage-0 tests.  The frozen R8 file is never saved here.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
modelName='BESS_GFM_10kV_Readable_R8';
modelFile=fullfile(projectRoot,'build',[modelName '.slx']);

%% 1) Load rejection: 5 MW -> 4 MW
[r,G]=load_case(modelFile,modelName); %#ok<ASGLU>
cmd=[modelName '/03 Island Load Scenario/Load_Step_Command'];
set_param(cmd,'Before','0','After','1');
r=run_case(modelName,0.8);
t=r(:,1); pre=t>0.22&t<0.28; post=t>0.70;
Ppre=mean(r(pre,2)); Ppost=mean(r(post,2));
assert(Ppre>4.88e6&&Ppre<5.15e6,'Unload pre-event power is incorrect.');
assert(Ppost>3.88e6&&Ppost<4.12e6,'Unload post-event power is incorrect.');
assert(Ppost<Ppre-0.8e6,'BESS did not reduce power after load rejection.');
[fmin,fmax,rocof,vmin,vmax,tsettle]=dynamic_metrics(r,0.30);
fprintf(['R8_UNLOAD_PASS=1 PRE=%.4f MW POST=%.4f MW ' ...
    'f=[%.5f %.5f] Hz RoCoFmax=%.3f Hz/s Vcmd=[%.2f %.2f] V ' ...
    'f_settle=%.4f s\n'],Ppre/1e6,Ppost/1e6,fmin,fmax,rocof, ...
    vmin,vmax,tsettle);
close_system(modelName,0);

%% 2) Force the existing AC limiter to intervene in a controlled test.
% Lower the test threshold only in memory.  This isolates limiter action
% without asking the 5 MW BESS to sustain an impossible 8 MW island load.
[~,G]=load_case(modelFile,modelName);
limiter=[modelName '/02 GFM PCS and Step-up/03 GFM Control and Limits/AC_Current_Limit_Factor'];
set_param(limiter,'Expr','0.75*G.control.Iac_rated_A/(u(1)+1)');
r=run_case(modelName,0.50);
t=r(:,1); active=t>0.36&t<0.46;
factorMin=min(r(active,14));
assert(factorMin<0.95,'Forced AC limit test did not enter limiting.');
assert(all(isfinite(r(t<0.42,:)),'all'),'AC limit intervention produced invalid telemetry.');
assert(max(r(active,9))<0.99,'Modulation limiter did not respond to AC limiting.');
fprintf('R8_AC_LIMIT_INTERVENTION_PASS=1 factor_min=%.4f modulation_max=%.4f\n', ...
    factorMin,max(r(active,9)));
close_system(modelName,0);

%% 3) Dynamic SOC boundary harness using the exact R8 interlock topology.
% A complete island cannot remain energized after its only source is
% forbidden to discharge.  Test the boundary transition dynamically at
% controller level; system-level boundary ride-through belongs to Stage 1,
% where PV supplies the missing power.
run_soc_boundary_harness(G,'min');
run_soc_boundary_harness(G,'max');
fprintf('BESS_GFM_R8_SUPPLEMENTAL_PASS=1\n');

function [r,G]=load_case(modelFile,modelName)
if bdIsLoaded(modelName),close_system(modelName,0);end
load_system(modelFile);
run(fullfile(fileparts(mfilename('fullpath')),'init_bess_gfm_dynamic_r7.m'));
r=[];
end

function r=run_case(modelName,stopTime)
out=sim(modelName,'StopTime',num2str(stopTime));
r=squeeze(out.get('gfm_r7_result'));
if size(r,2)~=15,r=r.';end
assert(size(r,2)==15&&all(isfinite(r),'all'),'Invalid R8 telemetry.');
end

function [fmin,fmax,rocof,vmin,vmax,tsettle]=dynamic_metrics(r,eventTime)
t=r(:,1); f=r(:,4); v=r(:,5);
window=t>eventTime-0.03;
fmin=min(f(window)); fmax=max(f(window));
dt=diff(t); df=diff(f); valid=dt>1e-8;
rocof=max(abs(df(valid)./dt(valid)));
vmin=min(v(window)); vmax=max(v(window));
post=t>max(t)-0.08; target=mean(f(post)); band=0.01;
bad=find(t>=eventTime & abs(f-target)>band,1,'last');
if isempty(bad),tsettle=0;else,tsettle=max(0,t(bad)-eventTime);end
end

function run_soc_boundary_harness(G,boundary)
m=['R8_SOC_' upper(boundary) '_Dynamic_Harness'];
if bdIsLoaded(m),close_system(m,0);end
new_system(m);
if strcmp(boundary,'min')
    start=G.bess.SOC_min+5e-4; slope=-0.05;
    request=G.dcdc.Iref_limit_A;
else
    start=G.bess.SOC_max-5e-4; slope=0.05;
    request=-G.dcdc.Iref_limit_A;
end
add_block('simulink/Sources/Ramp',[m '/SOC_Ramp'],'slope',num2str(slope,17), ...
    'start','0','InitialOutput',num2str(start,17),'Position',[40 70 90 100]);
add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
    [m '/Discharge_Allowed'],'relop','>','const',num2str(G.bess.SOC_min,17), ...
    'Position',[140 35 260 65]);
add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
    [m '/Charge_Allowed'],'relop','<','const',num2str(G.bess.SOC_max,17), ...
    'Position',[140 115 260 145]);
add_block('simulink/Math Operations/Gain',[m '/Upper'], ...
    'Gain',num2str(G.dcdc.Iref_limit_A,17),'Position',[300 35 380 65]);
add_block('simulink/Math Operations/Gain',[m '/Lower'], ...
    'Gain',num2str(-G.dcdc.Iref_limit_A,17),'Position',[300 115 380 145]);
add_block('simulink/Sources/Constant',[m '/Request'], ...
    'Value',num2str(request,17),'Position',[300 75 380 105]);
add_block('simulink/Discontinuities/Saturation Dynamic',[m '/SOC_Limit'], ...
    'Position',[430 55 520 125]);
add_block('simulink/Signal Routing/Mux',[m '/Mux'],'Inputs','3', ...
    'Position',[570 45 575 145]);
add_block('simulink/Sinks/To Workspace',[m '/Log'],'VariableName','soc_harness', ...
    'SaveFormat','Array','Position',[620 80 710 110]);
add_line(m,'SOC_Ramp/1','Discharge_Allowed/1');
add_line(m,'SOC_Ramp/1','Charge_Allowed/1');
add_line(m,'Discharge_Allowed/1','Upper/1');
add_line(m,'Charge_Allowed/1','Lower/1');
add_line(m,'Upper/1','SOC_Limit/1');
add_line(m,'Request/1','SOC_Limit/2');
add_line(m,'Lower/1','SOC_Limit/3');
add_line(m,'SOC_Ramp/1','Mux/1');
add_line(m,'Request/1','Mux/2');
add_line(m,'SOC_Limit/1','Mux/3');
add_line(m,'Mux/1','Log/1');
out=sim(m,'StopTime','0.02');
x=out.get('soc_harness');
t=out.tout;
before=t<0.008; after=t>0.012;
assert(abs(mean(x(before,3))-request)<1,'SOC harness pre-boundary output mismatch.');
assert(abs(mean(x(after,3)))<1,'SOC harness failed to block forbidden direction.');
fprintf('R8_SOC_%s_DYNAMIC_PASS=1 before=%.1f A after=%.1f A\n', ...
    upper(boundary),mean(x(before,3)),mean(x(after,3)));
close_system(m,0);
end
