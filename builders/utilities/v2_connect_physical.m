function line=v2_connect_physical(parent,a,sideA,indexA,b,sideB,indexB)
%V2_CONNECT_PHYSICAL Connect two named child conserving ports.
line=add_line(parent,v2_port([parent '/' a],sideA,indexA), ...
    v2_port([parent '/' b],sideB,indexB),'autorouting','on');
end
