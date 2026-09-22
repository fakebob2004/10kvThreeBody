function results=run_gfm_c0_checks
root=fileparts(mfilename('fullpath'));addpath(root);init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));assignin('base','GFM',GFM);
model='GFM_Inverter_C0';load_system(fullfile(root,[model '.slx']));
cleanup=onCleanup(@()bdclose(model)); %#ok<NASGU>
required={'GFM Controller','GFM Controller/01 Measurements and Power', ...
    'GFM Controller/02 P-f Droop and Angle', ...
    'GFM Controller/03 Q-V Droop and Magnitude', ...
    'GFM Controller/04 Voltage Reference and Limits', ...
    'GFM Controller/05 Carrier PWM'};
for k=1:numel(required),assert(getSimulinkBlockHandle([model '/' required{k}],true)>0,'Missing %s',required{k});end
assert(isempty(find_system(model,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','SubSystem','SFBlockType','MATLAB Function')),'Controller must remain graphical.');
set_param(model,'SimulationCommand','update');
simIn=Simulink.SimulationInput(model);simIn=setModelParameter(simIn,'StopTime','0.005');
out=sim(simIn);logs=out.logsout;
e=logs.get('GatePulses');
if isa(e,'Simulink.SimulationData.Dataset'),e=e.getElement(1);end
g=e.Values.Data;g=squeeze(g);
assert(all(isfinite(g),'all')&&all(g(:)==0|g(:)==1),'Invalid gates.');
assert(max(abs(g(:,1)+g(:,2)-1))==0&&max(abs(g(:,3)+g(:,4)-1))==0&& ...
    max(abs(g(:,5)+g(:,6)-1))==0,'Complementary gates failed.');
results=struct('Model',model,'DiagramUpdate','passed','SmokeSimulation','passed', ...
    'ControllerSubsystems',numel(required),'MATLABFunctionBlocks',0);
disp(results)
end
