% Rebuild the three intended top-level Simscape networks explicitly.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
modelName='BESS_GFM_10kV_Readable_R8';
modelFile=fullfile(projectRoot,'build',[modelName '.slx']);
load_system(modelFile);

% Existing top-level segments are disconnected graphical remnants.
lines=find_system(modelName,'FindAll','on','SearchDepth',1,'Type','line');
for k=1:numel(lines),try,delete_line(lines(k));catch,end,end

% Delete the two nested ordinary Inports that are both dangling.
for b={ ...
        [modelName '/02 GFM PCS and Step-up/In1'], ...
        [modelName '/02 GFM PCS and Step-up/03 GFM Control and Limits/In3']}
    if getSimulinkBlockHandle(b{1})>0,delete_block(b{1});end
end

dc=get_param([modelName '/01 BESS DC Source'],'PortHandles');
gfm=get_param([modelName '/02 GFM PCS and Step-up'],'PortHandles');
loadp=get_param([modelName '/03 Island Load Scenario'],'PortHandles');
assert(numel(dc.LConn)==1&&numel(dc.RConn)==1,'Unexpected DC power ports.');
assert(numel(gfm.RConn)==3,'Unexpected GFM power ports.');
assert(numel(loadp.LConn)==2,'Unexpected load power ports.');

% Two-pole 1500 Vdc link.
add_line(modelName,dc.LConn(1),gfm.RConn(1),'autorouting','on');
add_line(modelName,dc.RConn(1),gfm.RConn(2),'autorouting','on');
% One three-phase 10 kV bus feeding base and switched loads.
add_line(modelName,gfm.RConn(3),loadp.LConn(1),'autorouting','on');
add_line(modelName,gfm.RConn(3),loadp.LConn(2),'autorouting','on');

save_system(modelName,modelFile);
set_param(modelName,'SimulationCommand','update');
fprintf('R8_TOP_POWER_LINKS_REPAIRED=1\n');
save_system(modelName,modelFile);close_system(modelName,0);
