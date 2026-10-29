function cycle=olg_regular_cycle(c,sigma,cfg)
% Numerical tail classification only: not a proof of asymptotic attraction.
cycle=[]; n=numel(c); scale=max(1,max(abs(c(max(1,n-512):n))));
tol=cfg.basinPeriodTol*scale;
for p=1:cfg.basinMaxPeriod
    count=max(64,cfg.basinRepeats*p);
    if n<count+p+1, break; end
    if abs(c(n)-c(n-p))>tol, continue; end
    tail=c(n-count+1:n); template=c(n-p+1:n);
    prediction=template(mod((-count:-1)',p)+1);
    if max(abs(tail-prediction))>tol, continue; end
    cc=c(n-p:n-1); ll=(cc+c(n-p+1:n)).^(1/sigma);
    cycle=sortrows([cc ll],[1 2]); return;
end
end
