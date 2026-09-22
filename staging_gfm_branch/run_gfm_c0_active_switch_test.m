function results=run_gfm_c0_active_switch_test
% Prove that the GFM branch, not the grid, creates DC-link PWM voltage.
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
Grid.vll_nominal_for_test=Grid.Vll;
Grid.Vll=1;
% Decouple the 1 V source from the converter.  Otherwise the normal
% 250 MVA Thevenin impedance turns this source-depression test into a
% three-phase short-circuit test as soon as the bridge becomes active.
Grid.R=1e4;
Grid.L=1;
model='GFM_Inverter_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
% Prevent the model callback from replacing the deliberately weakened grid.
set_param(model,'InitFcn','');
simIn=Simulink.SimulationInput(model);
simIn=setVariable(simIn,'Grid',Grid);
simIn=setModelParameter(simIn,'StopTime','0.001');
out=sim(simIn);logs=out.logsout;
gate=rows(firstTS(logs,'GatePulses').Data);
vll=rows(firstTS(logs,'Vll_inv').Data);
iabc=rows(firstTS(logs,'Iabc_sw').Data);
assert(all(gate(:)==0|gate(:)==1),'Gate pulses are not binary.');
assert(max(abs(gate(:,1)+gate(:,2)-1))==0 && ...
    max(abs(gate(:,3)+gate(:,4)-1))==0 && ...
    max(abs(gate(:,5)+gate(:,6)-1))==0,'Gate pairs are not complementary.');
vllPeak=max(abs(vll),[],'all');currentPeak=max(abs(iabc),[],'all');
assert(vllPeak>0.5*Converter.Vdc_nom, ...
    'VSC did not generate a DC-link-scale PWM line voltage with a 1 V grid.');
assert(isfinite(currentPeak),'Switching current is non-finite.');
results=struct('Model',model,'GridVll_V',Grid.Vll,'Simulation','passed', ...
    'VSCLineVoltagePeak_V',vllPeak,'SwitchCurrentPeak_A',currentPeak, ...
    'GridIsolationResistance_Ohm',Grid.R, ...
    'GateThreshold_V',Converter.GateThreshold_V,'GateHigh_V',Converter.GateHigh_V);
disp(results)
end

function ts=firstTS(logs,name)
e=logs.get(name);assert(~isempty(e),'Missing logged signal: %s',name);
if isa(e,'Simulink.SimulationData.Dataset'),e=e.getElement(1);end
ts=e.Values;
end

function x=rows(x)
x=squeeze(x);
if isvector(x),x=x(:);return,end
if size(x,1)<=6&&size(x,2)>size(x,1),x=x.';end
end
