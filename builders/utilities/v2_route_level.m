function v2_route_level(system)
%V2_ROUTE_LEVEL Route only lines owned by this diagram level.
l=find_system(system,'FindAll','on','SearchDepth',1,'Type','line');
if ~isempty(l),Simulink.BlockDiagram.routeLine(l);end
end
