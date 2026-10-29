function [bValues,U] = grids(cfg)
s=cfg.search; width=diff(s.bRange); n=round(width/s.bStep);
assert(abs(n*s.bStep-width)<=1e-10*max(1,abs(width)), ...
    'OLG:Grid','The interval length must be an integer multiple of bStep.');
first=1-double(s.includeLowerEndpoint);
bValues=s.bRange(1)+(first:n)'*s.bStep; bValues(end)=s.bRange(2);
f=olg.fast_config(cfg,false); U=olg.fast.olg_phase_grid(f);
U.C=s.Q(1,1)+(0:U.size(1)-1)*U.step(1);
U.L=s.Q(2,1)+(0:U.size(2)-1)*U.step(2);
U.shape=U.size; U.count=U.totalPoints;
end
