#include "mex.h"
#include <algorithm>
#include <cmath>
#include <vector>
#ifdef __APPLE__
#include <Accelerate/Accelerate.h>
static FFTSetupD cachedSetup=nullptr;
static unsigned cachedLogSize=0;
static bool exitRegistered=false;
static void cleanupFFT() {
    if (cachedSetup) vDSP_destroy_fftsetupD(cachedSetup);
    cachedSetup=nullptr;
}
static FFTSetupD fftSetup(unsigned logSize) {
    if (!cachedSetup || cachedLogSize!=logSize) {
        cleanupFFT(); cachedSetup=vDSP_create_fftsetupD(logSize,kFFTRadix2);
        cachedLogSize=logSize;
    }
    if (!exitRegistered) { mexAtExit(cleanupFFT); exitRegistered=true; }
    return cachedSetup;
}
#endif

#ifndef __APPLE__
// Portable radix-2 fallback. macOS uses Accelerate for the same transforms.
static void transform(std::vector<double>& re,std::vector<double>& im,bool inverse) {
    const size_t n=re.size();
    for (size_t i=1,j=0;i<n;++i) {
        size_t bit=n>>1;
        for (;j&bit;bit>>=1) j^=bit;
        j^=bit;
        if (i<j) { std::swap(re[i],re[j]); std::swap(im[i],im[j]); }
    }
    const double pi=std::acos(-1.0);
    for (size_t len=2;len<=n;len<<=1) {
        const double a=(inverse?2:-2)*pi/static_cast<double>(len);
        const double wr=std::cos(a),wi=std::sin(a);
        for (size_t i=0;i<n;i+=len) {
            double cr=1,ci=0;
            for (size_t j=0;j<len/2;++j) {
                const size_t lo=i+j,hi=lo+len/2;
                const double tr=cr*re[hi]-ci*im[hi],ti=cr*im[hi]+ci*re[hi];
                re[hi]=re[lo]-tr; im[hi]=im[lo]-ti;
                re[lo]+=tr; im[lo]+=ti;
                const double next=cr*wr-ci*wi; ci=cr*wi+ci*wr; cr=next;
            }
        }
    }
}
#endif

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[]) {
    if (nrhs!=3 || nlhs>2)
        mexErrMsgIdAndTxt("OLG:NativeArgs","Expected y, cValues, maximum lag; up to two outputs.");
    for (int j=0;j<3;++j)
        if (!mxIsDouble(prhs[j]) || mxIsComplex(prhs[j]) || mxIsSparse(prhs[j]))
            mexErrMsgIdAndTxt("OLG:NativeType","Expected real full double inputs.");
    const size_t n=mxGetNumberOfElements(prhs[0]), count=mxGetNumberOfElements(prhs[1]);
    const double lagInput=mxGetScalar(prhs[2]);
    if (n<100 || count==0 || !std::isfinite(lagInput) || lagInput<2 || lagInput>=n ||
        std::floor(lagInput)!=lagInput || mxGetNumberOfElements(prhs[2])!=1)
        mexErrMsgIdAndTxt("OLG:NativeLength","Need N>=100, nonempty c values, 2<=maximum lag<N.");
    const size_t maxLag=static_cast<size_t>(lagInput);
    const double *input=mxGetDoubles(prhs[0]), *c=mxGetDoubles(prhs[1]);
    for (size_t ic=0;ic<count;++ic)
        if (!std::isfinite(c[ic]) || !(c[ic]>0 && c[ic]<std::acos(-1.0)))
            mexErrMsgIdAndTxt("OLG:NativeC","Every c must be in (0,pi).");
    double mean=0,largest=0;
    for (size_t i=0;i<n;++i) {
        if (!std::isfinite(input[i])) mexErrMsgIdAndTxt("OLG:NativeFinite","Nonfinite input.");
        mean+=input[i]; largest=std::max(largest,std::abs(input[i]));
    }
    mean/=static_cast<double>(n); double variance=0;
    for (size_t i=0;i<n;++i) { const double u=input[i]-mean; variance+=u*u; }
    const double sd=std::sqrt(variance/n);
    std::vector<double> coefficients(count,0);
    if (sd>1e-12*std::max(1.0,largest)) {
        std::vector<double> y(n);
        double normalizedMean=0;
        for (size_t i=0;i<n;++i) { y[i]=(input[i]-mean)/sd; normalizedMean+=y[i]; }
        normalizedMean/=static_cast<double>(n);
        size_t fftSize=1; unsigned logSize=0;
        while (fftSize<n+maxLag) { fftSize<<=1; ++logSize; }
        std::vector<double> re(fftSize),im(fftSize),power(n+1),displacement(maxLag);
#ifdef __APPLE__
        // Cache only input-independent FFT twiddles, like MATLAB's FFT
        // planning cache. No data or indicator results are cached.
        FFTSetupD setup=fftSetup(logSize);
        if (!setup) mexErrMsgIdAndTxt("OLG:FFTSetup","Unable to initialize FFT.");
        DSPDoubleSplitComplex split={re.data(),im.data()};
#endif
        const double lagMean=(maxLag+1)*0.5;
        double lagNorm2=0;
        for (size_t lag=1;lag<=maxLag;++lag) { const double v=lag-lagMean; lagNorm2+=v*v; }
        for (size_t ic=0;ic<count;++ic) {
            const double cc=std::cos(c[ic]),ss=std::sin(c[ic]);
            double cr=cc,ci=ss,zr=0,zi=0; power[0]=0;
            for (size_t j=0;j<n;++j) {
                zr+=y[j]*cr; zi+=y[j]*ci;
                re[j]=zr; im[j]=zi; power[j+1]=power[j]+zr*zr+zi*zi;
                const double next=cr*cc-ci*ss; ci=cr*ss+ci*cc; cr=next;
            }
            std::fill(re.begin()+n,re.end(),0); std::fill(im.begin()+n,im.end(),0);
#ifdef __APPLE__
            vDSP_fft_zipD(setup,&split,1,logSize,FFT_FORWARD);
#else
            transform(re,im,false);
#endif
            for (size_t j=0;j<fftSize;++j) { re[j]=re[j]*re[j]+im[j]*im[j]; im[j]=0; }
#ifdef __APPLE__
            vDSP_fft_zipD(setup,&split,1,logSize,FFT_INVERSE);
#else
            transform(re,im,true);
#endif
            double dMean=0;
            for (size_t lag=1;lag<=maxLag;++lag) {
                const double msd=(power[n]-power[lag]+power[n-lag]-2*re[lag]/fftSize)/(n-lag);
                displacement[lag-1]=msd-normalizedMean*normalizedMean*(1-std::cos(lag*c[ic]))/(1-cc);
                dMean+=displacement[lag-1];
            }
            dMean/=maxLag; double cross=0,dNorm2=0;
            for (size_t lag=1;lag<=maxLag;++lag) {
                const double v=displacement[lag-1]-dMean;
                cross+=(lag-lagMean)*v; dNorm2+=v*v;
            }
            coefficients[ic]=dNorm2>0?cross/std::sqrt(lagNorm2*dNorm2):0;
        }
    }
    if (nlhs>1) {
        plhs[1]=mxCreateDoubleMatrix(1,count,mxREAL);
        std::copy(coefficients.begin(),coefficients.end(),mxGetDoubles(plhs[1]));
    }
    std::sort(coefficients.begin(),coefficients.end());
    const double k=count%2?coefficients[count/2]:0.5*(coefficients[count/2-1]+coefficients[count/2]);
    if (nlhs) plhs[0]=mxCreateDoubleScalar(k);
}
