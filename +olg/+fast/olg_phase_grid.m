function grid=olg_phase_grid(cfg)
% Virtual Cartesian grid: no ndgrid or array proportional to total nodes.
step=cfg.stateStep; if isscalar(step), step=[step step]; end
n=round(diff(cfg.Q,1,2)./step(:));
assert(all(abs(diff(cfg.Q,1,2)./step(:)-n)<1e-7) && all(n>=1), ...
    'OLG:PhaseGrid','Q side lengths must be positive multiples of stateStep.');
grid=struct('Q',cfg.Q,'step',step,'size',(n+1)', ...
    'totalPoints',prod(n+1),'mode',cfg.phaseMode,'ids',[],'maxPoints',prod(n+1), ...
    'multiplier',1,'offset',0,'order',cfg.phaseOrder);
assert(grid.totalPoints<=double(intmax('uint32')),'OLG:PhaseGrid','Grid indices exceed uint32 record range.');
assert(strcmp(grid.mode,'full'),'OLG:PhaseMode','This experiment traverses the full grid.');
if strcmp(cfg.phaseOrder,'shuffle')
    assert(grid.totalPoints<=double(intmax('uint32')),'OLG:ShuffleSize','Shuffle supports up to 2^32-1 nodes.');
    old=rng; cleanup=onCleanup(@()rng(old));
    rng(cfg.phaseSeed,'twister'); grid.halfBits=max(1,ceil(log2(grid.totalPoints)/2));
    grid.keys=uint32(randi([0 2^32-1],1,6));
elseif strcmp(grid.mode,'full') && strcmp(cfg.phaseOrder,'permuted')
    old=rng; cleanup=onCleanup(@()rng(old));
    rng(cfg.phaseSeed,'twister'); grid.offset=randi(grid.totalPoints)-1;
    grid.multiplier=15485863;
    while gcd(grid.multiplier,grid.totalPoints)~=1, grid.multiplier=grid.multiplier+2; end
    assert(grid.multiplier*grid.totalPoints+grid.offset<flintmax, ...
        'OLG:PhaseGrid','Affine permutation exceeds exact integer precision.');
elseif ~strcmp(cfg.phaseOrder,'lex') && ~strcmp(cfg.phaseOrder,'permuted')
    error('OLG:PhaseOrder','phaseOrder must be shuffle, lex or permuted.');
end
end
