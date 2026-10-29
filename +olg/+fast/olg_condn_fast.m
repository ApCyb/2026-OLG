function [delta,traces] = olg_condn_fast(y,cfg)
% Same conceptor trace signature and reservoir as indicatorConDN in the
% original benchmark. No autonomous reconstruction is requested, so Wout
% and internalized W are not needed to compute this signature.
persistent previousCfg W Win bias
if isempty(previousCfg) || ~isequaln(previousCfg,cfg)
    previous=rng; restore=onCleanup(@()rng(previous));
    rng(cfg.seed,'twister'); N=cfg.reservoirSize;
    Win=cfg.inputScale*randn(N,1); bias=cfg.biasScale*randn(N,1);
    W=randn(N); W(rand(N)>0.1)=0;
    rho=max(abs(eig(W))); W=sparse(cfg.spectralRadius*W/rho);
    previousCfg=cfg;
end
y=y(:); factors=cfg.samplingFactors;
L=min(floor((numel(y)-1)./factors)+1);
patterns=numel(factors); P=zeros(L,patterns);
for j=1:patterns
    p=y(1:factors(j):end); p=p(1:L);
    P(:,j)=(p-mean(p))/max(std(p,1),eps);
end
N=cfg.reservoirSize;
% Batch independent drives; each column has its own recurrent state.
x=zeros(N,patterns); states=zeros(N,L*patterns);
for t=1:L
    x=tanh(W*x+Win*P(t,:)+bias);
    states(:,(t-1)*patterns+(1:patterns))=x;
end
traces=zeros(1,patterns); ridge=cfg.aperture^(-2)*eye(N);
for j=1:patterns
    X=states(:,j:patterns:end); R=(X*X')/L;
    % C=R/(R+gamma^-2 I) is symmetric positive semidefinite, hence its
    % nuclear norm (the original sum of SVD values) equals trace(C).
    C=R/(R+ridge); traces(j)=trace(C);
end
delta=traces-traces(1);
end
