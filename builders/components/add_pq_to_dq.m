function path=add_pq_to_dq(parent,name,cfg,pos)
%ADD_PQ_TO_DQ Convert PCC P/Q commands to peak dq-current references.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[0.90,0.96,0.86]','ContentPreviewEnabled','off');
in={'P_ref_W','Q_ref_var','Vll_peak_V'};
for k=1:3,add_block('simulink/Ports & Subsystems/In1',[path '/' in{k}], ...
        'Port',num2str(k),'Position',[20 35+60*(k-1) 50 49+60*(k-1)]);end
add_block('simulink/Signal Routing/Mux',[path '/P and V'], ...
    'Position',[100 30 105 105],'Inputs','2');
add_block('simulink/Signal Routing/Mux',[path '/Q and V'], ...
    'Position',[100 125 105 200],'Inputs','2');
add_block('simulink/User-Defined Functions/Fcn',[path '/P to Id'], ...
    'Position',[150 50 285 85],'Expr','2*u(1)/(sqrt(3)*sqrt(u(2)^2+1))');
% Q reference is defined at the 10 kV PCC.  The low-voltage shunt
% capacitor remains connected when the converter is enabled, so the PCS
% cancels its predictable fundamental-frequency reactive power locally.
% With Vll_peak as u(2), Qc=(omega*C/2)*Vll_peak^2.
qexpr=['-2*(u(1)-(2*pi*' cfg '.rating.f_Hz*' cfg ...
    '.filter.C_F/2)*u(2)^2)/(sqrt(3)*sqrt(u(2)^2+1))'];
add_block('simulink/User-Defined Functions/Fcn',[path '/Q to Iq'], ...
    'Position',[150 145 285 180],'Expr',qexpr);
add_block('simulink/Ports & Subsystems/Out1',[path '/Id_raw_Apk'], ...
    'Port','1','Position',[335 60 365 74]);
add_block('simulink/Ports & Subsystems/Out1',[path '/Iq_raw_Apk'], ...
    'Port','2','Position',[335 155 365 169]);
add_line(path,'P_ref_W/1','P and V/1');add_line(path,'Vll_peak_V/1','P and V/2');
add_line(path,'Q_ref_var/1','Q and V/1');add_line(path,'Vll_peak_V/1','Q and V/2');
add_line(path,'P and V/1','P to Id/1');add_line(path,'Q and V/1','Q to Iq/1');
add_line(path,'P to Id/1','Id_raw_Apk/1');add_line(path,'Q to Iq/1','Iq_raw_Apk/1');
end
