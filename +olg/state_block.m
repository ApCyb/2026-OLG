function X = state_block(U,first,last)
% Recover ordered points from the bijective virtual grid.
if isnumeric(U), X=U(first:last,:); return; end
X=olg.fast.olg_phase_points(U,first:last);
end
