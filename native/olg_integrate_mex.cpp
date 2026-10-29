#include "mex.h"
#include <cmath>
#include <vector>
#include <algorithm>
// No mutable global state, MATLAB callbacks, fast-math, or FMA contraction.
// Failed orbits reuse one scratch buffer; only complete survivors are kept.
void mexFunction(int nlhs,mxArray* out[],int nrhs,const mxArray* in[]) {
    if(nrhs!=7 || (nlhs!=6 && nlhs!=7)) mexErrMsgIdAndTxt("OLG:NativeArgs","Seven inputs; six or seven outputs required.");
    for(int k=0;k<7;++k) if(!mxIsDouble(in[k]) || mxIsComplex(in[k]) || mxIsSparse(in[k]))
        mexErrMsgIdAndTxt("OLG:NativeType","Inputs must be full real double arrays.");
    const mwSize n=mxGetM(in[0]);
    if(mxGetN(in[0])!=2 || mxGetM(in[1])!=n || mxGetN(in[1])!=2 || mxGetNumberOfElements(in[2])!=3)
        mexErrMsgIdAndTxt("OLG:NativeShape","Expected n-by-2 states, first updates, and three parameters.");
    for(int k=3;k<7;++k) if(mxGetNumberOfElements(in[k])!=1)
        mexErrMsgIdAndTxt("OLG:NativeShape","Expected scalar beta, horizon, safety limit, keepL.");
    const double h=mxGetScalar(in[4]);
    if(!std::isfinite(h) || h<1 || h!=std::floor(h) || h>1000000)
        mexErrMsgIdAndTxt("OLG:NativeHorizon","Invalid horizon.");
    const mwSize H=static_cast<mwSize>(h); const bool keepL=mxGetScalar(in[6])!=0;
    const double *u=mxGetDoubles(in[0]),*first=mxGetDoubles(in[1]),*theta=mxGetDoubles(in[2]);
    const double beta=mxGetScalar(in[3]),limit=mxGetScalar(in[5]);
    std::vector<double> scratch(H),scratchL(keepL?H:0),history,historyL,indices,finalC,finalL;
    double steps=0,origins=0;
    double* detail=nullptr;
    if(nlhs==7) { out[6]=mxCreateDoubleMatrix(n,4,mxREAL); detail=mxGetDoubles(out[6]); }
    for(mwSize j=0;j<n;++j) {
        double c=u[j],l=u[j+n];
        if(c==0 && l==0) { ++origins; if(detail) detail[j+3*n]=1; continue; }
        bool survived=true;
        for(mwSize t=0;t<H;++t) {
            const double cn=t==0?first[j]:std::pow(l,theta[1])-c;
            const double ln=t==0?first[j+n]:theta[2]*(beta*l-std::pow(c,theta[0]));
            ++steps;
            if(detail) {
                detail[j]=cn; detail[j+n]=ln; detail[j+2*n]=static_cast<double>(t+1);
                detail[j+3*n]=(cn<0 || ln<0)?2:(!std::isfinite(cn) || !std::isfinite(ln))?3:(cn>limit || ln>limit)?4:5;
            }
            if(cn<0 || ln<0 || !std::isfinite(cn) || !std::isfinite(ln) || cn>limit || ln>limit) {
                survived=false; break;
            }
            c=cn; l=ln; scratch[t]=c; if(keepL) scratchL[t]=l;
        }
        if(survived) {
            indices.push_back(static_cast<double>(j+1)); finalC.push_back(c); finalL.push_back(l);
            history.insert(history.end(),scratch.begin(),scratch.end());
            if(keepL) historyL.insert(historyL.end(),scratchL.begin(),scratchL.end());
        }
    }
    const mwSize m=indices.size();
    out[0]=mxCreateDoubleMatrix(H,m,mxREAL); out[1]=mxCreateDoubleMatrix(m,2,mxREAL);
    out[2]=mxCreateDoubleMatrix(m,1,mxREAL); out[3]=mxCreateDoubleScalar(steps);
    out[4]=mxCreateDoubleScalar(origins); out[5]=mxCreateDoubleMatrix(keepL?H:0,keepL?m:0,mxREAL);
    if(m) {
        std::copy(history.begin(),history.end(),mxGetDoubles(out[0]));
        std::copy(finalC.begin(),finalC.end(),mxGetDoubles(out[1]));
        std::copy(finalL.begin(),finalL.end(),mxGetDoubles(out[1])+m);
        std::copy(indices.begin(),indices.end(),mxGetDoubles(out[2]));
        if(keepL) std::copy(historyL.begin(),historyL.end(),mxGetDoubles(out[5]));
    }
}
