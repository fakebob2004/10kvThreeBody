function v2_disable_previews(root)
%V2_DISABLE_PREVIEWS Keep each drawing at one abstraction level.
s=find_system(root,'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem');
for k=1:numel(s),try,set_param(s{k},'ContentPreviewEnabled','off');catch,end,end
end
