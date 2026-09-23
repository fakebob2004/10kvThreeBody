function path=add_strong_machine_fixture(parent,name,root,pos)
%ADD_STRONG_MACHINE_FIXTURE Import the documented reference commissioning grid.
% The resource model remains generated independently; this block is a test
% fixture derived from Renewable Energy Integration with Simscape.
ref=fullfile(root,'references','Renewable-Energy-Integration-Simscape-master', ...
    'Models','PVPlant','BatteryStoragePVPlantGFM.slx');
assert(isfile(ref),'Strong-machine reference fixture is missing: %s',ref);
addpath(fullfile(root,'references','Renewable-Energy-Integration-Simscape-master', ...
    'ScriptsData','PVPlant'));
load_system(ref);
src=sprintf(['BatteryStoragePVPlantGFM/Conventional Source/Variant Subsystem/' ...
    'Synchronous Machine']);
path=[parent '/' name];add_block(src,path,'Position',pos);
xf=[path '/230//24 kV'];
set_param(xf,'SRated','SM.MVA','FRated','Grid.frequency', ...
    'VRated1','Grid.voltage','VRated2','SM.Voltage');
field=[path '/AVR and Exciter/' sprintf('Synchronous Machine\nField Circuit (pu)')];
if getSimulinkBlockHandle(field)>0,set_param(field,'FRated','Grid.frequency');end
avr=[path '/AVR and Exciter/SM AC1C'];
if getSimulinkBlockHandle(avr)>0,set_param(avr,'K_A','50','T_A','0.05');end
psInputs=find_system(path,'LookUnderMasks','all','FollowLinks','on', ...
    'MaskType',sprintf('Simulink-PS\nConverter'));
for k=1:numel(psInputs)
    p=get_param(psInputs{k},'DialogParameters');
    if isfield(p,'FilteringAndDerivatives'),set_param(psInputs{k},'FilteringAndDerivatives','zero');end
end
set_param(path,'BackgroundColor','[0.92,0.92,0.92]');
define_strong_machine_fixture(true);
close_system('BatteryStoragePVPlantGFM',0);
end
