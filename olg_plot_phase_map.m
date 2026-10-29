function preview=olg_plot_phase_map(folder,showFigure,maxAxis)
% Read committed finite-horizon map records; no new trajectories.
if nargin<2, showFigure=true; end
if nargin<3, maxAxis=600; end
preview=olg.fast.olg_plot_phase_map(folder,showFigure,maxAxis);
end
