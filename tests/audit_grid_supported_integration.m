function report=audit_grid_supported_integration()
%AUDIT_GRID_SUPPORTED_INTEGRATION Structural isolation and immutable source checks.
root=setup_v2_paths;init_grid_supported_integration;
m='GRID_SUPPORTED_PV_WIND_R1';load_system(fullfile(root,'models','integration',[m '.slx']));
cleanup=onCleanup(@()close_system(m,0));wind=[m '/Wind Resource'];
ctl=[wind '/04 GFL Control and SPWM'];
assert(getSimulinkBlockHandle([m '/Strong Synchronous Machine - Always Connected'])>0);
assert(getSimulinkBlockHandle([wind '/06 Grid Equivalent and Source'])<0,'Imported Wind source grid');
assert(getSimulinkBlockHandle([ctl '/06 SPWM and Physical Gate Interface'])<0);
assert(strcmp(get_param([wind '/03 DC Link and Two-Level GSC/Two-Level Three-Phase Bridge'], ...
 'device_type'),'ee.enum.converters.switchingdevice.averaged'));
align=get_param([ctl '/PLL Angle Alignment'],'PortHandles');
ln=get_param(align.Inport(1),'Line');src=get_param(ln,'SrcBlockHandle');
assert(strcmp(getfullname(src),[ctl '/PLL Angle for Control']),'Wind control uses a nonlocal angle');
assert(strcmp(get_param(src,'GotoTag'),'WIND_R3__THETA_PLL_DIAG'));
gotos=find_system(wind,'LookUnderMasks','all','FollowLinks','on','BlockType','Goto');
froms=find_system(wind,'LookUnderMasks','all','FollowLinks','on','BlockType','From');
for blocks={gotos,froms}
 items=blocks{1};
 for k=1:numel(items),assert(startsWith(get_param(items{k},'GotoTag'),'WIND_R3__'));end
end
for k=1:numel(gotos),assert(~strcmp(get_param(gotos{k},'TagVisibility'),'global'));end
assert(getSimulinkBlockHandle([m '/PV Resource/02 PCS/01 Local PLL'])>0);
assert(strcmp(get_param([m '/Strong Synchronous Machine - Always Connected/Synchronous Machine'],'Pt0'),'5e6'));
inputs={'build/Wind_PMSG_Transient_R3.slx','parameters/init_wind_pmsg_transient_r3.m','scripts/build_wind_pmsg_transient_r3.m'};
expected={'5f681e18b513c1ca7ed7fb3e360228e8f5c123ae1d0b6698b06408a0d1343278', ...
 '26a8c43dca0112f81858878bb820103e529b1716a7f488c5a4729693138fe414', ...
 '07d1c9ed504906951f7a42aab9395fe11038673a364162bf5d8556803dab995c'};
report=struct('island_operation',false,'structural_isolation_pass',true, ...
 'local_pll_control_pass',true,'wind_originals_unchanged',true,'source_files',struct());
for k=1:numel(inputs)
 p=fullfile(root,inputs{k});fid=fopen(p,'r');bytes=fread(fid,inf,'*uint8');fclose(fid);
 md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
 hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
 assert(strcmp(hash,expected{k}),'Supplied Wind source drifted: %s',inputs{k});
 report.source_files.(sprintf('input_%d',k))=struct('path',inputs{k},'sha256',hash);
end
folder=fullfile(root,'artifacts','grid_supported_integration');
fid=fopen(fullfile(folder,'source_and_interface_audit.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
fprintf('GRID_SUPPORTED_SOURCE_AND_INTERFACE_AUDIT_PASS=1\n');
end
