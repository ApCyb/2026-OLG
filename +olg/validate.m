function validate(c)
% Fail before starting workers or creating output files.
assert(isfield(c,'schemaVersion') && c.schemaVersion==4,'OLG:ConfigVersion', ...
    'Create a fresh schema-4 configuration with this package''s olg_config.');
legacy={'phaseScan','phaseOrder','phaseSeed','firstHitBatchSize','outputDir','integrator','zeroOneBackend'};
assert(~any(isfield(c,legacy)),'OLG:LegacyFields', ...
    'Use grouped search/runtime/output fields shown in README, not the standalone experiment fields.');
assert(ismember(c.mode,{'compare_DE_vs_full_scan','compare_chaos_indicators'}), ...
    'OLG:Mode','Unknown experiment mode.');
validateattributes([c.model.lambda c.model.sigma],{'numeric'},{'real','finite','>',1});
validateattributes(c.model.beta,{'numeric'},{'scalar','real','finite','positive','<=',1});
validateattributes([c.horizon.cheap c.horizon.ftle],{'numeric'},{'integer','positive','finite'});
validateattributes(c.horizon.transient,{'numeric'},{'scalar','integer','nonnegative','finite'});
assert(c.horizon.ftle>=c.horizon.cheap && c.horizon.cheap-c.horizon.transient>=100, ...
    'OLG:Horizon','Require FTLE >= cheap and at least 100 retained cheap samples.');
assert(c.detector.maxState>0 && isfinite(c.detector.maxState), 'OLG:StateLimit','Invalid state limit.');
validateattributes(c.detector.ftleThreshold,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(c.detector.regularTolerance,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(c.detector.maxPeriod,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(c.zeroOne.cValues,{'numeric'},{'vector','real','finite','>',0,'<',pi});
validateattributes(c.zeroOne.lagFraction,{'numeric'},{'scalar','>',0,'<=',0.5});
validateattributes(c.zeroOne.threshold,{'numeric'},{'scalar','real','finite','>',0,'<=',1});
validateattributes(c.sali.threshold,{'numeric'},{'scalar','real','finite','positive','<',sqrt(2)});
validateattributes([c.rosenstein.embedding c.rosenstein.delay c.rosenstein.maxIter ...
    c.rosenstein.minPairs],{'numeric'},{'integer','positive','finite'});
validateattributes(c.rosenstein.theiler,{'numeric'},{'scalar','integer','nonnegative','finite'});
validateattributes(c.rosenstein.minR2,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(c.rosenstein.fit,{'numeric'},{'vector','integer','nonnegative','finite'});
assert(numel(c.rosenstein.fit)>=3 && all(diff(c.rosenstein.fit)>0) ...
    && max(c.rosenstein.fit)<=c.rosenstein.maxIter,'OLG:Rosenstein','Invalid linear fit lags.');
validateattributes(c.condn.threshold,{'numeric'},{'scalar','real','finite'});
validateattributes(c.condn.reservoirSize,{'numeric'},{'scalar','integer','>=',10,'finite'});
validateattributes(c.condn.samplingFactors,{'numeric'},{'vector','integer','positive','finite'});
assert(numel(c.condn.samplingFactors)>=2 && c.condn.samplingFactors(1)==1 ...
    && all(diff(c.condn.samplingFactors)>0),'OLG:ConDN','Use increasing factors starting at 1.');
assert(ceil((c.horizon.cheap-c.horizon.transient)/max(c.condn.samplingFactors))>=3, ...
    'OLG:ConDN','Too few samples after subsampling.');
validateattributes([c.condn.spectralRadius c.condn.inputScale c.condn.biasScale ...
    c.condn.aperture c.condn.ridge],{'numeric'},{'real','finite','positive'});
validateattributes(c.condn.seed,{'numeric'},{'scalar','integer','nonnegative','<=',2^32-1});
valid={'zero_one','sali','condn'};
for names={c.filters,c.timing.indicators}
    a=names{1};
    assert(iscell(a) && isrow(a) && all(cellfun(@ischar,a)) && ~isempty(a) && all(ismember(a,valid)) ...
        && numel(unique(a))==numel(a),'OLG:Indicators','Use a nonempty cell array of unique indicator names.');
end
validateattributes(c.timing.b,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(c.timing.x0,{'numeric'},{'row','numel',2,'real','finite','nonnegative'});
assert(all(c.timing.x0<=c.detector.maxState),'OLG:StateLimit','Initial state exceeds maxState.');
validateattributes(c.timing.repetitions,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(c.timing.warmupPasses,{'numeric'},{'scalar','integer','nonnegative','finite'});
assert(ismember(c.timing.implementation,{'reference','optimized'}),'OLG:Implementation','Unknown timing implementation.');
assert(ismember(c.timing.zeroOneBackend,{'matlab','native'}),'OLG:Backend','Unknown timing 0-1 backend.');
assert(ismember(c.timing.neighborMethod,{'auto','brute','native'}),'OLG:Backend','Unknown timing neighbor backend.');
if strcmp(c.timing.zeroOneBackend,'native'), assert(olg.has_native('olg_zero_one_native_mex'),'OLG:Build','Run build_olg_fast.'); end
if strcmp(c.timing.neighborMethod,'native'), assert(olg.has_native('olg_nearest_mex'),'OLG:Build','Run build_olg_fast.'); end
if strcmp(c.mode,'compare_chaos_indicators'), return; end
s=c.search;
assert(~isfield(s,'completePositiveQ'),'OLG:Deprecated','Use search.phaseScan=first_hit or full in a fresh configuration.');
assert(ismember(s.phaseScan,{'first_hit','full'}),'OLG:PhaseScan','Unknown phase scan mode.');
assert(~strcmp(s.phaseScan,'full') || c.output.enabled,'OLG:FullOutput','Full mode requires output.enabled=true for per-node records.');
validateattributes(s.firstHitBatchSize,{'numeric'},{'scalar','integer','positive','finite'});
olg.fast.olg_prepare_modes(olg.fast_config(c,false));
validateattributes(s.bRange,{'numeric'},{'row','numel',2,'real','finite','positive'});
assert(diff(s.bRange)>0,'OLG:Grid','bRange must be increasing.');
validateattributes(s.bStep,{'numeric'},{'scalar','real','finite','positive','<=',diff(s.bRange)});
validateattributes(s.Q,{'numeric'},{'size',[2 2],'real','finite','nonnegative'});
assert(all(s.Q(:,2)>s.Q(:,1)) && all(s.Q(:)<=c.detector.maxState), ...
    'OLG:Grid','Q must have positive widths and fit inside the numerical state limit.');
if isempty(s.stateGridSize)
    validateattributes(s.stateStep,{'numeric'},{'row','numel',2,'real','finite','positive'});
else
    validateattributes(s.stateGridSize,{'numeric'},{'row','numel',2,'integer','>=',2,'finite'});
end
validateattributes(s.stateBatchSize,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(s.stateChunkSize,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(s.stateCheckpointSeconds,{'numeric'},{'scalar','real','positive','finite'});
assert(mod(s.stateBatchSize,s.stateChunkSize)==0,'OLG:Batch','stateBatchSize must be a multiple of stateChunkSize.');
assert(ismember(s.stateOrder,{'shuffle','lex','permuted'}),'OLG:StateOrder','Unknown Q traversal.');
assert(ismember(s.gridMode,{'estimate','full_scan'}),'OLG:GridMode','Use estimate or full_scan.');
assert(isequal(c.filters,{'zero_one'}),'OLG:Gate','Search uses 0-1 and Rosenstein only; SALI/ConDN are diagnostics.');
assert(ismember(c.runtime.integrator,{'matlab','native','auto'}) && ismember(c.runtime.zeroOneBackend,{'matlab','native'}),'OLG:Backend','Unknown backend.');
assert(ismember(c.parallel.poolType,{'auto','Threads','Processes'}),'OLG:PoolType','Invalid pool type.');
validateattributes(s.stateSeed,{'numeric'},{'scalar','integer','nonnegative','<=',2^32-1});
validateattributes(s.gridFirstProbeCount,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(s.gridProbesPerRegime,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(s.gridRegimeBreaks,{'numeric'},{'vector','real','finite','increasing'});
validateattributes(s.stateProgressSeconds,{'numeric'},{'scalar','real','positive','finite'});
validateattributes(s.population,{'numeric'},{'scalar','integer','>=',4,'finite'});
validateattributes(s.mutation,{'numeric'},{'scalar','real','finite','>',0,'<=',2});
validateattributes(s.strategy,{'numeric'},{'scalar','integer','>=',1,'<=',10});
validateattributes(s.crossover,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(s.repetitions,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(s.seed,{'numeric'},{'scalar','integer','nonnegative','<=',2^32-1-s.repetitions});
if ~isequal(s.maxEvaluations,Inf)
    validateattributes(s.maxEvaluations,{'numeric'},{'scalar','integer','positive','finite'});
end
validateattributes(s.progressEvery,{'numeric'},{'scalar','integer','positive','finite'});
[B,~]=olg.grids(c);
if strcmp(s.gridMode,'estimate')
    assert(any(abs(B-s.historicalCandidateB)<1e-10),'OLG:HistoricalTarget', ...
        'historicalCandidateB must be a grid node; or use gridMode=full_scan.');
end
assert(numel(B)>=s.population,'OLG:Population','The b grid must have at least population nodes.');
if ~(ischar(c.parallel.workers) && strcmp(c.parallel.workers,'auto'))
    validateattributes(c.parallel.workers,{'numeric'},{'scalar','integer','positive','finite'});
end
end
