function h=v2_port(block,side,index)
%V2_PORT Return a Simulink or Simscape port handle.
p=get_param(block,'PortHandles');h=p.(side)(index);
end
