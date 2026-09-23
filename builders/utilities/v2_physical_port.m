function h=v2_physical_port(block)
%V2_PHYSICAL_PORT Return the sole conserving port of a boundary block.
p=get_param(block,'PortHandles');h=[p.LConn p.RConn];
assert(numel(h)==1,'Expected exactly one physical boundary port: %s',block);
end
