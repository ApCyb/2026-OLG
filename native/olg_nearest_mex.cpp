#include "mex.h"
#include <vector>
#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
// Exact balanced k-d tree. Temporal exclusion and d^2>eps match the original.
// Equal distances choose the smallest original row, like MATLAB min().
struct Tree {
    const double* y; mwSize n,d; long window; double eps;
    std::vector<mwSize> order;
    Tree(const double* v,mwSize count,mwSize dim,long w,double e):y(v),n(count),d(dim),window(w),eps(e),order(n) {
        std::iota(order.begin(),order.end(),0); build(0,n,0);
    }
    double value(mwSize i,mwSize a) const { return y[i+a*n]; }
    void build(mwSize lo,mwSize hi,mwSize depth) {
        if(lo>=hi) return; mwSize mid=lo+(hi-lo)/2,a=depth%d;
        std::nth_element(order.begin()+lo,order.begin()+mid,order.begin()+hi,
            [&](mwSize i,mwSize j){return value(i,a)==value(j,a)?i<j:value(i,a)<value(j,a);});
        build(lo,mid,depth+1); build(mid+1,hi,depth+1);
    }
    void query(mwSize q,mwSize lo,mwSize hi,mwSize depth,double& best,mwSize& index) const {
        if(lo>=hi) return; mwSize mid=lo+(hi-lo)/2,i=order[mid],a=depth%d;
        double dist=0;
        for(mwSize k=0;k<d;++k) { const double z=value(q,k)-value(i,k); dist+=z*z; }
        if(std::abs(static_cast<long>(q)-static_cast<long>(i))>window && dist>eps && std::isfinite(dist) &&
           (dist<best || (dist==best && i<index))) {best=dist;index=i;}
        const double delta=value(q,a)-value(i,a);
        if(delta<=0) {
            query(q,lo,mid,depth+1,best,index);
            if(delta*delta<=best) query(q,mid+1,hi,depth+1,best,index);
        } else {
            query(q,mid+1,hi,depth+1,best,index);
            if(delta*delta<=best) query(q,lo,mid,depth+1,best,index);
        }
    }
};
void mexFunction(int nlhs,mxArray* out[],int nrhs,const mxArray* in[]) {
    if(nrhs!=2 || nlhs!=1 || !mxIsDouble(in[0]) || mxIsComplex(in[0]) || mxIsSparse(in[0]) ||
       !mxIsDouble(in[1]) || mxIsComplex(in[1]) || mxGetNumberOfElements(in[1])!=1)
        mexErrMsgIdAndTxt("OLG:NearestArgs","Expected real double Y and scalar Theiler window; one output.");
    const mwSize n=mxGetM(in[0]),d=mxGetN(in[0]); const double *y=mxGetDoubles(in[0]),w=mxGetScalar(in[1]);
    if(d<1 || !std::isfinite(w) || w<0 || w!=std::floor(w) || w>static_cast<double>(n))
        mexErrMsgIdAndTxt("OLG:NearestShape","Invalid dimension or Theiler window.");
    for(mwSize i=0;i<n*d;++i) if(!std::isfinite(y[i])) mexErrMsgIdAndTxt("OLG:NearestFinite","Nonfinite Y.");
    Tree tree(y,n,d,static_cast<long>(w),std::numeric_limits<double>::epsilon());
    out[0]=mxCreateDoubleMatrix(n,1,mxREAL); double* indices=mxGetDoubles(out[0]);
    for(mwSize i=0;i<n;++i) {
        double best=std::numeric_limits<double>::infinity(); mwSize nearest=n;
        tree.query(i,0,n,0,best,nearest); indices[i]=nearest==n?0:static_cast<double>(nearest+1);
    }
}
