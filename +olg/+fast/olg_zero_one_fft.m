function [K,kc]=olg_zero_one_fft(y,cfg)
% Same finite-sample MSD/correlation statistic as olg_zero_one, evaluated
% with FFT autocorrelations of cumulative p+i*q rather than lag loops.
y=y(:); N=numel(y); kc=NaN(size(cfg.cValues)); K=NaN;
if N<100 || any(~isfinite(y)), return; end
sd=std(y,1);
if sd<=1e-12*max(1,max(abs(y))), K=0; kc(:)=0; return; end
y=(y-mean(y))/sd;
persistent oldN oldC oldFraction carrier fftSize lag v
if isempty(oldN) || oldN~=N || ~isequal(oldC,cfg.cValues) || oldFraction~=cfg.lagFraction
    j=(1:N)'; lag=(1:floor(N*cfg.lagFraction))';
    phase=j*cfg.cValues(:)'; carrier=complex(cos(phase),sin(phase));
    fftSize=2^nextpow2(N+lag(end)); v=lag-mean(lag);
    oldN=N; oldC=cfg.cValues; oldFraction=cfg.lagFraction;
end
assert(~isempty(lag) && lag(end)<N,'OLG:ZeroOneLags','Maximum lag must be between 1 and N-1.');
% Padding by the maximum requested lag suffices for these correlations;
% padding to 2*N-1 needlessly doubles the FFT length at N=5000.
c=cfg.cValues(:).';
z=cumsum(y.*carrier,1);
power=cumsum(real(z).^2+imag(z).^2,1);
spectrum=fft(z,fftSize,1);
ac=real(ifft(real(spectrum).^2+imag(spectrum).^2,[],1));
D=(power(N,:)-power(lag,:)+power(N-lag,:)-2*ac(lag+1,:))./(N-lag);
D=D-mean(y)^2*(1-cos(lag*c))./(1-cos(c));
w=D-mean(D,1); denom=norm(v)*sqrt(sum(w.^2,1));
coeff=zeros(size(c)); valid=denom>0;
coeff(valid)=(v'*w(:,valid))./denom(valid);
kc=reshape(coeff,size(cfg.cValues)); K=median(coeff);
end
