function [value, details] = rosenstein(y,cfg)
% Largest Lyapunov exponent estimate from a finite scalar time series.
% Rosenstein, Collins and De Luca (1993), natural log per map iteration.
% Use the entire input series, with no hidden truncation or downsampling.
y=y(:); N=numel(y); scale=std(y,1); value=NaN;
details=struct('samples',N,'embedding',cfg.embedding,'delay',cfg.delay, ...
    'lags',(0:cfg.maxIter)','divergence',nan(cfg.maxIter+1,1), ...
    'pairCounts',zeros(cfg.maxIter+1,1),'fit',cfg.fit,'rSquared',NaN, ...
    'status','insufficient_data');
if N<100 || any(~isfinite(y)), return; end
if scale<=1e-12*max(1,max(abs(y))), details.status='constant_signal'; return; end
y=(y-mean(y))/scale;
M=N-(cfg.embedding-1)*cfg.delay;
if M<=cfg.maxIter+2*cfg.theiler+cfg.minPairs, return; end
Y=zeros(M,cfg.embedding);
for j=1:cfg.embedding, Y(:,j)=y((1:M)+(j-1)*cfg.delay); end
nearest=zeros(M,1);
% O(M^2) time, O(M*m) memory. No Statistics Toolbox dependency.
for i=1:M
    distances=sum((Y-Y(i,:)).^2,2);
    distances(max(1,i-cfg.theiler):min(M,i+cfg.theiler))=Inf;
    [v,nearest(i)]=min(distances);
    if ~isfinite(v), nearest(i)=0; end
end
for k=0:cfg.maxIter
    refs=find(nearest>0 & (1:M)'<=M-k & nearest<=M-k);
    if isempty(refs), continue; end
    distances=sqrt(sum((Y(refs+k,:)-Y(nearest(refs)+k,:)).^2,2));
    distances=distances(distances>sqrt(eps) & isfinite(distances));
    details.pairCounts(k+1)=numel(distances);
    if ~isempty(distances), details.divergence(k+1)=mean(log(distances)); end
end
ix=cfg.fit+1;
if any(details.pairCounts(ix)<cfg.minPairs) || any(~isfinite(details.divergence(ix))), return; end
x=cfg.fit(:); d=details.divergence(ix); coefficients=polyfit(x,d,1);
residual=sum((d-polyval(coefficients,x)).^2); total=sum((d-mean(d)).^2);
if total>0, details.rSquared=1-residual/total; end
value=coefficients(1); details.intercept=coefficients(2); details.status='estimated';
end
