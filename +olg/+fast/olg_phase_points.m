function [states,ids]=olg_phase_points(grid,positions)
% C varies fastest, exactly as in the original ndgrid convention.
if strcmp(grid.order,'shuffle')
    ids=olg.fast.olg_shuffle_ids(positions,grid.totalPoints,grid.halfBits,grid.keys);
else
    ids=mod((positions(:)-1)*grid.multiplier+grid.offset,grid.totalPoints)+1;
end
cIndex=mod(ids-1,grid.size(1)); lIndex=floor((ids-1)/grid.size(1));
states=[grid.Q(1,1)+grid.step(1)*cIndex,grid.Q(2,1)+grid.step(2)*lIndex];
end
