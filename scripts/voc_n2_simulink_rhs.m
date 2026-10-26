function dx=voc_n2_simulink_rhs(u)
%VOC_N2_SIMULINK_RHS Adapter for the readable independent research harness.
c=evalin('base','VOC_N2_CASE');
dx=voc_n2_rhs(u(1),u(2:18),c);
end
