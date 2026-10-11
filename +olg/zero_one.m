function [K, kc] = zero_one(y, cfg)
% Correlation 0-1 test, fixed c values (Gottwald and Melbourne, 2009).
y = y(:); N = numel(y);
if N<100 || any(~isfinite(y)), K=NaN; kc=[]; return; end
scale=std(y,1);
if scale<=1e-12*max(1,max(abs(y)))
    K=0; kc=zeros(size(cfg.cValues)); return;
end
y=(y-mean(y))/scale;
lags=(1:floor(N*cfg.lagFraction))'; j=(1:N)'; kc=zeros(size(cfg.cValues));
v=lags-mean(lags);
for ic=1:numel(cfg.cValues)
    c=cfg.cValues(ic); p=cumsum(y.*cos(j*c)); q=cumsum(y.*sin(j*c));
    M=zeros(size(lags));
    for lag=lags'
        M(lag)=mean((p(lag+1:end)-p(1:end-lag)).^2 ...
            +(q(lag+1:end)-q(1:end-lag)).^2);
    end
    D=M-mean(y)^2*(1-cos(lags*c))/(1-cos(c)); w=D-mean(D);
    denom=norm(v)*norm(w);
    if denom>0, kc(ic)=(v'*w)/denom; end
end
K=median(kc);
end
