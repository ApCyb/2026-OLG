function X = state_block(U,first,last)
% Match [C(:),L(:)] for ndgrid(U.C,U.L), with bounded memory.
if isnumeric(U), X=U(first:last,:); return; end
k=(first:last)'-1; nC=U.shape(1);
X=[reshape(U.C(mod(k,nC)+1),[],1),reshape(U.L(floor(k/nC)+1),[],1)];
end
