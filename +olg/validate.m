function validate(c)
% Fail before starting workers or creating output files.
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
if strcmp(c.mode,'compare_chaos_indicators'), return; end
s=c.search;
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
validateattributes(s.retainInitialStatesMax,{'numeric'},{'scalar','integer','nonnegative','finite'});
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
assert(numel(B)>=s.population,'OLG:Population','The b grid must have at least population nodes.');
if ~(ischar(c.parallel.workers) && strcmp(c.parallel.workers,'auto'))
    validateattributes(c.parallel.workers,{'numeric'},{'scalar','integer','positive','finite'});
end
end
