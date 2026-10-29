function [K,kc]=olg_zero_one_fft_reference(y,cfg)
% Same finite-sample MSD/correlation statistic as olg_zero_one, evaluated
% with FFT autocorrelations of cumulative p+i*q rather than lag loops.
y=y(:); N=numel(y); kc=NaN(size(cfg.cValues)); K=NaN;
if N<100 || any(~isfinite(y)), return; end
sd=std(y,1);
if sd<=1e-12*max(1,max(abs(y))), K=0; kc(:)=0; return; end
y=(y-mean(y))/sd; j=(1:N)'; lag=(1:floor(N*cfg.lagFraction))';
v=lag-mean(lag); fftSize=2^nextpow2(2*N-1);
for k=1:numel(cfg.cValues)
    c=cfg.cValues(k); z=cumsum(y.*cos(j*c))+1i*cumsum(y.*sin(j*c));
    power=cumsum(abs(z).^2); ac=real(ifft(abs(fft(z,fftSize)).^2));
    D=(power(N)-power(lag)+power(N-lag)-2*ac(lag+1))./(N-lag);
    D=D-mean(y)^2*(1-cos(lag*c))/(1-cos(c));
    w=D-mean(D); denom=norm(v)*norm(w);
    if denom>0, kc(k)=(v'*w)/denom; else, kc(k)=0; end
end
K=median(kc);
end
