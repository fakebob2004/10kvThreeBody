function f=p3_release_model_path(root,m)
folder='integration';
if strcmp(version('-release'),'2023b'),folder='r2023b';end
f=fullfile(root,'models',folder,[m '.slx']);assert(isfile(f),'Missing model: %s',f);
end
