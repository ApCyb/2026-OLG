function preview=olg_plot_phase_map(folder,showFigure,maxAxis)
% Read committed per-node outcomes without recomputing trajectories.
% Render a regular subset of the exact Q nodes (no interpolation of labels).
if nargin<2, showFigure=true; end
if nargin<3, maxAxis=600; end
validateattributes(maxAxis,{'numeric'},{'scalar','integer','>=',2});
m=load(fullfile(folder,'metadata.mat')); g=m.grid;
step=g.step; if isscalar(step), step=[step step]; end
[parent,name]=fileparts(folder); suffix='_basin';
checkpoint=fullfile(parent,[name(1:end-numel(suffix)) '.mat']);
x=load(checkpoint,'s'); s=x.s;
assert(strcmp(m.scanId,s.scanId),'OLG:MapMismatch','Metadata and checkpoint differ.');
ci=unique(round(linspace(1,g.size(1),min(maxAxis,g.size(1)))));
li=unique(round(linspace(1,g.size(2),min(maxAxis,g.size(2)))));
cl=zeros(g.size(1),1); cl(ci)=1:numel(ci); ll=zeros(g.size(2),1); ll(li)=1:numel(li);
status=zeros(numel(li),numel(ci),'uint8'); regular=zeros(size(status),'uint32');
files=dir(fullfile(folder,'batch_*.mat')); committed=s.nextPosition-1; readNodes=0;
for k=1:numel(files)
    start=sscanf(files(k).name,'batch_%d.mat');
    if start>committed, continue; end
    b=load(fullfile(folder,files(k).name));
    if ~strcmp(b.scanId,s.scanId) || b.stop>committed, continue; end
    id=double(b.records.id); c=cl(mod(id-1,g.size(1))+1); l=ll(floor((id-1)/g.size(1))+1);
    use=c>0 & l>0; ix=sub2ind(size(status),l(use),c(use));
    status(ix)=b.records.status(use); regular(ix)=b.records.attractor(use);
    readNodes=readNodes+numel(id);
end
assert(readNodes==committed,'OLG:MapIncomplete','Committed record files are missing.');
preview=struct('C',g.Q(1,1)+(ci-1)*step(1),'L',g.Q(2,1)+(li-1)*step(2), ...
    'status',status,'regular',regular,'regularRegistry',s.registry, ...
    'statusCounts',s.statusCounts,'labels',{m.labels},'committedNodes',committed, ...
    'totalNodes',g.totalPoints,'complete',committed==g.totalPoints);
visibility='off'; if showFigure, visibility='on'; end
f=figure('Visible',visibility,'Color','w','Position',[100 100 1250 510]);
subplot(1,2,1); imagesc(preview.C,preview.L,status); axis xy; clim([-.5 12.5]);
palette=[1 1 1;0 0 0;.82 .84 .86;.55 0 0;1 .55 .1;.55 .8 1; ...
    .1 .3 .85;.5 .2 .75;.95 .85 .2;.1 .65 .3;.9 .5 .7;.9 .1 .1;.45 .3 .1];
colormap(gca,palette); cb=colorbar; cb.Ticks=0:12;
cb.TickLabels={'unvisited','exact origin','exit Pi','nonfinite','safety stop', ...
    'survived','regular fixed','regular periodic','unresolved','chaos candidate', ...
    'Rosenstein rejected','confirmation failed','indicator failed'};
xlabel('C_0'); ylabel('L_0'); title(sprintf('Finite-horizon outcomes: %d / %d nodes',committed,g.totalPoints));
subplot(1,2,2); z=double(regular); z(z==0)=NaN;
h=imagesc(preview.C,preview.L,z); set(h,'AlphaData',~isnan(z)); axis xy;
nr=max(1,numel(s.registry)); colormap(gca,lines(nr)); clim([.5 nr+.5]); cb=colorbar;
if nr<=20, cb.Ticks=1:nr; end
xlabel('C_0'); ylabel('L_0'); title('Regular regime IDs (numerical tail matching)');
exportgraphics(f,fullfile(folder,'phase_map.png'),'Resolution',160);
olg.fast.olg_atomic_save(fullfile(folder,'phase_map_preview.mat'),struct('preview',preview));
if ~showFigure, close(f); end
fprintf('Map uses %d x %d exact nodes; chaotic attractor identities are unresolved.\n',numel(ci),numel(li));
end
