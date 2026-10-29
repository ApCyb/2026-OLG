function [s,steps] = olg_sali_fast(orbit,theta,beta)
% Same final SALI as per-step normalization, with scalar tangent updates.
% All N steps are processed. Normalization by a positive scalar does not
% change a tangent direction; perform it every 16 steps and at the endpoint.
N=size(orbit,1)-1; steps=N;
a=theta(2)*orbit(1:N,2).^(theta(2)-1);
b=-theta(3)*theta(1)*orbit(1:N,1).^(theta(1)-1);
d=theta(3)*beta;
u1=1; u2=0; v1=0; v2=1;
for first=1:16:N
    last=min(first+15,N);
    for k=first:last
        newU=-u1+a(k)*u2; u2=b(k)*u1+d*u2; u1=newU;
        newV=-v1+a(k)*v2; v2=b(k)*v1+d*v2; v1=newV;
    end
    nu=hypot(u1,u2); nv=hypot(v1,v2);
    assert(nu>0 && nv>0 && isfinite(nu) && isfinite(nv), ...
        'OLG:SALINumerics','Tangent normalization failed.');
    u1=u1/nu; u2=u2/nu; v1=v1/nv; v2=v2/nv;
end
s=min(hypot(u1+v1,u2+v2),hypot(u1-v1,u2-v2));
end
