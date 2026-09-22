scriptDir=fileparts(mfilename('fullpath'));
root=fileparts(scriptDir);
models={ ...
    fullfile(root,'references','Renewable-Energy-Integration-Simscape-master','Models','Wind Model','WindGFLMpp.slx'), ...
    fullfile(root,'Wind_PV_SOC_DCAC_864.slx'), ...
    fullfile(root,'Wind_PV_SOC_DCAC_864_5MW.slx'), ...
    fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx')};
for m=1:numel(models)
    f=models{m};
    [~,name]=fileparts(f);
    fprintf('\n===== %s =====\n',name);
    try
        load_system(f);
    catch ME
        fprintf('LOAD_FAILED: %s\n',ME.message);
        continue
    end
    b=find_system(name,'SearchDepth',4,'Type','Block');
    for k=2:numel(b)
        bt=get_param(b{k},'BlockType');
        mt=''; try,mt=get_param(b{k},'MaskType');catch,end
        fprintf('%s | %s | %s\n',b{k},bt,mt);
    end
    close_system(name,0);
end
