function s=olg_commit_phase_batch(folder,chunks,s,start,stop,cfg)
% Write records before committing their counters in the evaluation checkpoint.
% A restart may overwrite an orphan file; readers only use committed ranges.
for j=1:numel(chunks)
    b=chunks{j}; labels=b.records.attractor;
    for k=1:numel(b.registry)
        [s.registry,id]=olg.fast.olg_register_cycle(s.registry,b.registry(k).cycle,cfg.basinClusterTol);
        mask=labels==k; b.records.attractor(mask)=uint32(id);
        s.registry(id).count=s.registry(id).count+sum(mask);
    end
    s.statusCounts=s.statusCounts+accumarray(double(b.records.status)+1,1,[13 1]);
    chunks{j}=b.records;
end
records=struct(); names=fieldnames(chunks{1});
for k=1:numel(names)
    values=cellfun(@(x)x.(names{k}),chunks,'UniformOutput',false);
    records.(names{k})=vertcat(values{:});
end
olg.fast.olg_atomic_save(fullfile(folder,sprintf('batch_%012d.mat',start)), ...
    struct('records',records,'start',start,'stop',stop,'scanId',s.scanId));
end
