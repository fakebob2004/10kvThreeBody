function path=v2_add_pmio(parent,name,port,side,domain,pos)
%V2_ADD_PMIO Add a deterministic Simscape conserving port.
path=[parent '/' name];
add_block('built-in/PMIOPort',path,'Port',num2str(port),'Side',side, ...
    'ConnectionType',['Connection: ' domain],'Position',pos);
end
