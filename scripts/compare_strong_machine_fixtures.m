function compare_strong_machine_fixtures()
%COMPARE_STRONG_MACHINE_FIXTURES Compare accepted and v2 commissioning grids.
root=fileparts(fileparts(mfilename('fullpath')));setup_v2_paths;
oldFile=fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx');
newFile=fullfile(root,'models','resources','pv_resource_standalone.slx');
load_system(oldFile);load_system(newFile);
old='PV_GFL_864_SystemLevel_SM_R2_1_Readable/Strong Synchronous Machine (Governor + AVR)';
new='pv_resource_standalone/Strong Synchronous Machine Test Grid';
bo=find_system(old,'LookUnderMasks','all','FollowLinks','on','Type','Block');
bn=find_system(new,'LookUnderMasks','all','FollowLinks','on','Type','Block');
fprintf('OLD_BLOCKS=%d NEW_BLOCKS=%d\n',numel(bo),numel(bn));
ro=cellfun(@(x)erase(x,[old '/']),bo,'UniformOutput',false);
rn=cellfun(@(x)erase(x,[new '/']),bn,'UniformOutput',false);
fprintf('ONLY_OLD=%d ONLY_NEW=%d\n',numel(setdiff(ro,rn)),numel(setdiff(rn,ro)));
common=intersect(ro,rn,'stable');different=0;
for k=1:numel(common)
    a=[old '/' common{k}];b=[new '/' common{k}];
    da=get_param(a,'DialogParameters');db=get_param(b,'DialogParameters');
    if ~isstruct(da)||~isstruct(db),continue,end
    fields=intersect(fieldnames(da),fieldnames(db));
    for j=1:numel(fields)
        try,va=char(string(get_param(a,fields{j})));vb=char(string(get_param(b,fields{j})));
        catch,continue,end
        if ~strcmp(va,vb)
            different=different+1;
            fprintf('DIFF %s :: %s :: OLD=%s NEW=%s\n',common{k},fields{j},va,vb);
        end
    end
end
fprintf('MACHINE_PARAMETER_DIFFERENCES=%d\n',different);
close_system(bdroot(old),0);close_system(bdroot(new),0);
end
