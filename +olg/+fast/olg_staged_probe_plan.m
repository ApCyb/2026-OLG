function plan=olg_staged_probe_plan(cfg)
b=cfg.bValues; [distance,target]=min(abs(b-cfg.historicalCandidateB));
assert(distance<1e-10,'OLG:HistoricalTarget','Historical candidate must be on the b-grid.');
first=(1:min(cfg.gridFirstProbeCount,target))'; indices=first;
if cfg.gridExtraProbes
    edges=[-Inf cfg.gridRegimeBreaks(:)' Inf];
    for s=1:numel(edges)-1
        region=find((b>=edges(s) & b<edges(s+1)) & (1:numel(b))'<=target);
        if any(ismember(region,first)), continue; end % Prefix already times this regime.
        available=setdiff(region,first,'stable');
        if ~isempty(available)
            n=min(cfg.gridProbesPerRegime,numel(available));
            picks=round(linspace(1,numel(available),n+2));
            indices=[indices;available(picks(2:end-1))]; %#ok<AGROW>
        end
    end
    indices=[indices;target];
end
indices=unique(indices,'stable'); edges=[-Inf cfg.gridRegimeBreaks(:)' Inf];
regime=zeros(size(indices));
for s=1:numel(edges)-1, regime(b(indices)>=edges(s) & b(indices)<edges(s+1))=s; end
plan=table(indices,b(indices),ismember(indices,first),regime, ...
    'VariableNames',{'gridIndex','b_L','firstPrefix','regime'});
end
