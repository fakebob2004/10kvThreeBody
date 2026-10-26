function [dh,cmd] = dvoc_bess_kernel(u,p)
%DVOC_BESS_KERNEL Local abc/SI adapter; no PCC PLL or shared resource angle.
% u: time, oscillator dq(2), bridge iabc(3), filter vLL(3), ioabc(3),
%    P_ref,Q_ref,V_ref,f_ref,enable,mode. p: S,VLL,f,R1,L1.
% V_ref/f_ref are nominal-only in this first frozen-controller adapter.
u=u(:);p=p(:);
assert(abs(u(15)-p(2))<1e-6 && abs(u(16)-p(3))<1e-6, ...
    'Frozen dVOC adapter currently requires nominal V_ref and f_ref');
assert(u(18)==1,'Frozen dVOC adapter currently supports mode 1 only');
w=2*pi*p(3);theta=w*u(1);h=u(2:3);
Vpk=sqrt(2/3)*p(2);Ipk=sqrt(2/3)*p(1)/p(2);
clarke=(2/3)*[1 -.5 -.5;0 sqrt(3)/2 -sqrt(3)/2];
rot=[cos(theta) sin(theta);-sin(theta) cos(theta)];
vll=u(7:9);vphase=[vll(1)-vll(3);vll(2)-vll(1);vll(3)-vll(2)]/3;
v=rot*clarke*vphase/Vpk;
i=rot*clarke*u(4:6)/Ipk;io=rot*clarke*u(10:12)/Ipk;
Z=p(2)^2/p(1);R=p(4)/Z;X=w*p(5)/Z;
[dh,e,~,~,domega]=dvoc_limited_controller(h,i,v,io,u(13)/p(1),u(14)/p(1),R,X);
enabled=min(1,max(0,u(17)));
if enabled<.5,dh=zeros(2,1);end
ab=rot'*e;
vabc=Vpk*[ab(1);-.5*ab(1)+sqrt(3)/2*ab(2);-.5*ab(1)-sqrt(3)/2*ab(2)]*enabled;
cmd=[vabc;theta+atan2(h(2),h(1));w+domega;norm(h)*p(2);enabled];
end
