function value = sali(path, model, b)
% Independently renormalized deviations; no Gram-Schmidt orthogonalization.
v1=[1;0]; v2=[0;1]; value=sqrt(2);
for k=1:size(path,1)-1
    J=olg.jacobian(path(k,:),model,b); v1=J*v1; v2=J*v2;
    n1=norm(v1); n2=norm(v2);
    if ~isfinite(n1+n2), value=NaN; return; end
    if n1==0 || n2==0, value=0; return; end
    v1=v1/n1; v2=v2/n2; value=min(norm(v1+v2),norm(v1-v2));
end
end
