function [dh,e,mu,modulation,omega] = dvoc_limited_controller(h,i,v,io,pref,qref,R,X)
%DVOC_LIMITED_CONTROLLER Frozen native limited dVOC, dq per-unit.
% X = omega_nominal * L_pu. io EXCLUDES capacitor current.
% Limits are research settings; external engineering protection is separate.
J=[0 -1;1 0];
iref=(h-v)/.2;
mu=min(1,3/sqrt(sum(iref.^2)+1e-24));
requested=v+R*i+X*J*i+10*X*(mu*iref-i); % 500 Hz / 50 Hz
modulation=min(1,1.4/sqrt(sum(requested.^2)+1e-24));
e=modulation*requested;
dh=3*((qref+1-sum(h.^2))*h+pref*J*h-J*io);
E=sqrt(sum(h.^2)+1e-24);unit=h/E;tangent=J*unit;
radial=max(-50,min(50,dh'*unit));
omega=max(-15,min(15,dh'*tangent/E));
if (E>=1.4 && radial>0)||(E<=.05 && radial<0),radial=0;end
dh=radial*unit+omega*E*tangent;
end
