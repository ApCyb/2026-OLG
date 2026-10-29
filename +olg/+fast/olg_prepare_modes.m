function cfg=olg_prepare_modes(cfg)
cfg.phaseScan=validatestring(cfg.phaseScan,{'first_hit','full'});
cfg.phaseOrder=validatestring(cfg.phaseOrder,{'shuffle','lex','permuted'});
cfg.savePhaseRecords=strcmp(cfg.phaseScan,'full');
for field={'firstHitBatchSize','phaseBatchSize','phaseChunkSize','basinMaxPeriod','basinRepeats'}
    validateattributes(cfg.(field{1}),{'numeric'},{'scalar','integer','positive','finite'});
end
assert(cfg.basinMaxPeriod<=65535,'OLG:Period','Maximum period exceeds saved uint16 range.');
for field={'basinPeriodTol','basinClusterTol'}
    validateattributes(cfg.(field{1}),{'numeric'},{'scalar','positive','finite'});
end
validateattributes(cfg.confirmHorizon,{'numeric'},{'scalar','integer','positive','<=',double(intmax('uint32'))});
assert(cfg.confirmHorizon>=cfg.burn+cfg.sample,'OLG:Horizon','Confirmation must cover the screening horizon.');
end
