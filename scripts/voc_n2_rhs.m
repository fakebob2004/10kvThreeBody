function [dx,y]=voc_n2_rhs(t,x,c)
%VOC_N2_RHS Exact limited dVOC/N2 research equations, common dq pu base.
% State: hat(2), bridge i(2), node v(4), line i(6), mu, SG angle, SG speed.
w=2*pi*50; J=[0 -1;1 0]; L=.25/w; R=.03;
A=[1 1 0;-1 -1 1;0 0 -1];
h=x(1:2); i=x(3:4); v=reshape(x(5:8),2,2);
il=reshape(x(9:14),2,3); angle=x(16); speed=x(17);
g=c.load_g(:); closed=ones(3,1);
if t+1e-12>=c.entry && t+1e-12<c.clear,g=g+c.fault_g(:);end
if t+1e-12>=c.trip_time,closed=closed-c.trip_mask(:);end
external=(A(1:2,:)*(il.*closed')')'+v.*g';
io=external(:,1);
% Frozen limited variant: gain=1; mu filter exists but is not fed back.
iref=(h-v(:,1))/.2;
mu=min(1,3/sqrt(sum(iref.^2)+1e-24)); limited=mu*iref;
requested=v(:,1)+R*i+w*L*J*i+2*pi*500*L*(limited-i);
modulation=min(1,1.4/sqrt(sum(requested.^2)+1e-24)); e=modulation*requested;
dh=3*((c.qref+1-sum(h.^2))*h+c.pref*J*h-J*io);
E=sqrt(sum(h.^2)+1e-24); unit=h/E; tangent=J*unit;
radial=max(-50,min(50,dh'*unit)); omega=max(-15,min(15,dh'*tangent/E));
if (E>=1.4 && radial>0)||(E<=.05 && radial<0),radial=0;end
dh=radial*unit+omega*E*tangent;
di=(e-v(:,1)-R*i)/L-w*J*i;
dv=([i zeros(2,1)]-(A(1:2,:)*(il.*closed')')'-v.*g')./c.cap(:)'-w*J*v;
sg=c.sg_E*[cos(angle);sin(angle)]; voltage=[v sg];
drops=voltage*A; lineL=c.edges(:,4)/w;
dl=(drops.*closed'-il.*(c.edges(:,3)+2*(1-closed))' ...
    -(J*il).*c.edges(:,5)')./lineL'-w*J*il;
outgoing=(A*(il.*closed')')'; psg=sg'*outgoing(:,3);
ds=(c.pm-psg-c.sg_D*speed)/(2*c.sg_H);
dx=[dh;di;dv(:);dl(:);(mu-x(15))/.002;w*speed;ds];
if nargout>1
    y=[norm(v(:,1));norm(v(:,2));norm(i);norm(h);norm(e);mu;modulation; ...
       v(:,1)'*io;v(:,1)'*J*io;e'*i;50+omega/(2*pi);50*(1+speed)];
end
end
