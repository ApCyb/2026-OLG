function [bValues,U] = grids(cfg)
s=cfg.search; width=diff(s.bRange); n=round(width/s.bStep);
if abs(n*s.bStep-width)>1e-10*max(1,abs(width))
    error('OLG:Grid','The interval length must be an integer multiple of bStep.');
end
first=1-double(s.includeLowerEndpoint);
bValues=s.bRange(1)+(first:n)'*s.bStep;
bValues(end)=s.bRange(2);
% Store only the two axes; never materialize their Cartesian product.
if isempty(s.stateGridSize)
    steps=s.stateStep; widths=diff(s.Q,1,2)'; cells=round(widths./steps);
    assert(all(cells>=1) && all(abs(cells.*steps-widths)<=1e-10*max(1,max(widths))), ...
        'OLG:StateGrid','Each Q side length must be an integer multiple of stateStep.');
    C=s.Q(1,1)+(0:cells(1))*steps(1); C(end)=s.Q(1,2);
    L=s.Q(2,1)+(0:cells(2))*steps(2); L(end)=s.Q(2,2);
else
    C=linspace(s.Q(1,1),s.Q(1,2),s.stateGridSize(1));
    L=linspace(s.Q(2,1),s.Q(2,2),s.stateGridSize(2));
    steps=[C(2)-C(1),L(2)-L(1)];
end
U=struct('C',C,'L',L,'shape',[numel(C) numel(L)], ...
    'count',double(numel(C))*numel(L),'step',steps,'order','C varies fastest');
assert(U.count<=flintmax,'OLG:StateGrid','State count exceeds exact double indexing.');
end
