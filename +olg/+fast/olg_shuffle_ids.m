function ids=olg_shuffle_ids(positions,N,halfBits,keys)
% Six-round Feistel bijection followed by cycle walking into [0,N).
% Pseudorandom order, not a claim of uniform choice among all N! permutations.
% Integer products are <= 2^48: exact in double, no saturating uint multiply.
v=uint32(positions(:)-1); v=permute(v,halfBits,keys);
bad=double(v)>=N;
while any(bad)
    v(bad)=permute(v(bad),halfBits,keys); bad=double(v)>=N;
end
ids=double(v)+1;
end
function v=permute(v,h,keys)
mask=uint32(2^h-1); L=bitshift(v,-h); R=bitand(v,mask);
for k=1:numel(keys)
    z=bitxor(R,keys(k)); z=bitxor(z,bitshift(z,-16));
    z=uint32(mod(double(z)*65521,2^32)); z=bitxor(z,bitshift(z,-13));
    z=uint32(mod(double(z)*65519,2^32)); z=bitxor(z,bitshift(z,-16));
    next=bitxor(L,bitand(z,mask)); L=R; R=next;
end
v=bitor(bitshift(L,h),R);
end
