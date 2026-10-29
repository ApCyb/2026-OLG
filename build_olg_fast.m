function build_olg_fast
% Build optional C++ kernels for THIS MATLAB platform; no downloaded binaries.
clear('olg.fast.olg_integrate_mex','olg.fast.olg_nearest_mex','olg.fast.olg_zero_one_native_mex');
root=fileparts(mfilename('fullpath')); out=fullfile(root,'+olg','+fast');
flags='CXXFLAGS=$CXXFLAGS -std=c++17 -O3 -ffp-contract=off';
if ispc, flags='COMPFLAGS=$COMPFLAGS /std:c++17 /O2 /fp:strict'; end
platform={}; if ismac, platform={'LINKEXPORTCPP=','LDFLAGS=$LDFLAGS -framework Accelerate'}; end
for name={'olg_integrate_mex','olg_nearest_mex','olg_zero_one_native_mex'}
    mex('-R2018a',flags,fullfile(root,'native',[name{1} '.cpp']),'-outdir',out,platform{:});
end
rehash;
end
