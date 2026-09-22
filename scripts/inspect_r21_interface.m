root=fileparts(fileparts(mfilename('fullpath')));
f=fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx');
load_system(f); m='PV_GFL_864_SystemLevel_SM_R2_1_Readable';
parents={m,[m '/01 PV-GFL Branch R2.1'],[m '/02 Commissioning Command Profile']};
for p=1:numel(parents)
 fprintf('\n[%s]\n',parents{p});
 b=find_system(parents{p},'SearchDepth',1,'Type','Block');
 for k=2:numel(b)
  pos=get_param(b{k},'Position'); bt=get_param(b{k},'BlockType');
  fprintf('%s | %s | [%s]\n',get_param(b{k},'Name'),bt,num2str(pos));
 end
end
close_system(m,0);
