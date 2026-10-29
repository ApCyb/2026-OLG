function r = olg_rosenstein(x,opt)
% Headless adaptation of mirwais' File Exchange submission 38424 (2012).
% Original file and its BSD license are retained under vendor/rosenstein.
% Changes: no plots/console output; finite distances only; valid reference
% pairs; configurable fitting window; unit sampling interval; quality flag.
% A reconstructed time-series LLE estimate, NOT a Jacobian FTLE.
x=x(:); x=x(1:min(numel(x),opt.maxPoints));
r=struct('lle',NaN,'r2',NaN,'valid',false,'divergence',[], ...
    'lags',[],'pairs',[],'fit',opt.fit);
sd=std(x,1);
if any(~isfinite(x)) || sd<=1e-12*max(1,max(abs(x))), return; end
x=(x-mean(x))/sd;
M=numel(x)-(opt.embedding-1)*opt.delay;
if M<=2*opt.theiler+opt.maxIter+10, return; end
Y=zeros(M,opt.embedding);
for j=1:opt.embedding, Y(:,j)=x((1:M)+(j-1)*opt.delay); end
useNative=isfield(opt,'neighborMethod') && strcmp(opt.neighborMethod,'native');
if useNative
    nearest=olg.fast.olg_nearest_mex(Y,double(opt.theiler));
else
    nearest=zeros(M,1);
    for i=1:M
        d=sum((Y-Y(i,:)).^2,2);
        d(abs((1:M)'-i)<=opt.theiler | d<=eps | ~isfinite(d))=Inf;
        [value,idx]=min(d);
        if isfinite(value), nearest(i)=idx; end
    end
end
lags=(0:opt.maxIter)'; div=NaN(size(lags)); pairs=zeros(size(lags));
for k=lags'
    refs=find(nearest>0 & (1:M)'<=M-k & nearest<=M-k);
    if isempty(refs), continue; end
    d=sqrt(sum((Y(refs+k,:)-Y(nearest(refs)+k,:)).^2,2));
    d=d(d>sqrt(eps) & isfinite(d));
    pairs(k+1)=numel(d);
    if ~isempty(d), div(k+1)=mean(log(d)); end
end
fit=opt.fit(:); idx=fit+1;
minPairs=20; if isfield(opt,'minPairs'), minPairs=opt.minPairs; end
if any(idx>numel(div)) || any(~isfinite(div(idx))) || any(pairs(idx)<minPairs), return; end
coef=polyfit(fit,div(idx),1); pred=polyval(coef,fit);
ss=sum((div(idx)-mean(div(idx))).^2);
if ss>0, r.r2=1-sum((div(idx)-pred).^2)/ss; end
r.lle=coef(1); r.divergence=div; r.lags=lags; r.pairs=pairs;
r.valid=isfinite(r.r2) && r.r2>=opt.minR2;
end
