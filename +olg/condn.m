function [value, details] = condn(y, cfg)
% ConDN multirate trace signature, based on Ismail et al. (2022).
% Reports trace(C_last)-trace(C_1), not a fitted saturation coefficient.
% A private stream leaves both DE and the caller's random state unchanged.
stream=RandStream('mt19937ar','Seed',cfg.seed);
y=y(:); factors=cfg.samplingFactors; L=numel(y(1:max(factors):end));
N=cfg.reservoirSize; P=zeros(L,numel(factors));
for j=1:numel(factors)
    sample=y(1:factors(j):end); sample=sample(1:L);
    P(:,j)=(sample-mean(sample))/max(std(sample,1),eps);
end
Win=cfg.inputScale*randn(stream,N,1); bias=cfg.biasScale*randn(stream,N,1);
Wstar=randn(stream,N); Wstar(rand(stream,N)>0.1)=0;
rho=max(abs(eig(Wstar)));
if rho==0, error('OLG:Reservoir','Reservoir has zero spectral radius.'); end
Wstar=cfg.spectralRadius*Wstar/rho;
noise=randn(stream,L,1); x=zeros(N,1); Xv=zeros(N,L);
for t=1:L
    x=tanh(Wstar*x+Win*noise(t)+bias); Xv(:,t)=x;
end
Wout=(noise'*Xv')/(Xv*Xv'+cfg.ridge*eye(N));
XX=zeros(N,(L-1)*numel(factors)); YY=XX;
traces=zeros(size(factors));
for j=1:numel(factors)
    x=zeros(N,1); X=zeros(N,L);
    for t=1:L
        x=tanh(Wstar*x+Win*P(t,j)+bias); X(:,t)=x;
    end
    ix=(j-1)*(L-1)+(1:L-1);
    XX(:,ix)=X(:,2:end);
    YY(:,ix)=Wstar*X(:,1:end-1)+Win*P(1:end-1,j)'+bias;
    R=(X*X')/L; C=R/(R+cfg.aperture^(-2)*eye(N));
    traces(j)=sum(svd(C,'econ'));
end
W=YY*XX'/(XX*XX'+cfg.ridge*eye(N));
delta=traces-traces(1); value=delta(end);
details=struct('traces',traces,'delta',delta,'samplingFactors',factors, ...
    'samplesPerFactor',L,'trainedWeights',W,'readout',Wout);
end
