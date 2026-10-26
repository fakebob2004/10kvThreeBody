function configure_bess_dvoc()
%CONFIGURE_BESS_DVOC Adapt strategy only; retain physical plant/protection.
V2=evalin('base','V2');
V2.BESS.control.strategy='dvoc';
% Native controller already has virtual admittance. Avoid applying an
% additional voltage-drop policy during first validation; interface remains.
V2.BESS.control.virtual_impedance_enabled=0;
assignin('base','V2',V2);
end
