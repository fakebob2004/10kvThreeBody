function v2_render(system,file)
%V2_RENDER Export a diagram for mandatory visual review.
folder=fileparts(file);if ~exist(folder,'dir'),mkdir(folder);end
try,set_param(system,'ZoomFactor','FitSystem');hilite_system(system,'none');catch,end
print(['-s' system],'-dpng','-r150',file);
end
