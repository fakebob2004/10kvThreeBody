function parts=add_gfl_control(parent,cfg)
%ADD_GFL_CONTROL Add the shared shallow GFL control chain to a PCS.
parts=struct();
parts.pll=add_local_pll(parent,'01 Local PLL',cfg,[145 35 330 125]);
parts.pq=add_pq_to_dq(parent,'02 P-Q to dq Reference',cfg,[390 35 575 135]);
parts.limiter=add_current_circle_limiter(parent,'03 Current Limiter',cfg,[635 35 815 135]);
parts.current=add_gfl_current_controller(parent,'04 Current Controller',cfg,[875 35 1080 135]);
end
