function [registry,id]=olg_register_cycle(registry,cycle,tolerance)
id=0; if isempty(cycle), return; end
for j=1:numel(registry)
    ref=registry(j).cycle;
    if isequal(size(cycle),size(ref)) && max(abs(cycle(:)-ref(:)))<=tolerance*max(1,max(abs(ref(:))))
        id=j; return;
    end
end
item=struct('cycle',cycle,'period',size(cycle,1),'count',0);
if isempty(registry), registry=item; else, registry(end+1)=item; end
id=numel(registry);
end
