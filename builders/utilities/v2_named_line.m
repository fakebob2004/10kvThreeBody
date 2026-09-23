function h=v2_named_line(parent,source,destination,name)
%V2_NAMED_LINE Add and name a signal, including typed-bus element inputs.
h=add_line(parent,source,destination,'autorouting','on');set_param(h,'Name',name);
end
