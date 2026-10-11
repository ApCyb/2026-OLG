function cfg = olg_config(mode, profile)
%OLG_CONFIG Configure either of the two OLG experiments.
% cfg = olg_config('compare_DE_vs_full_scan','paper');
% cfg = olg_config('compare_chaos_indicators','demo');
if nargin < 1, mode = 'compare_DE_vs_full_scan'; end
if nargin < 2, profile = 'demo'; end
mode = validatestring(mode, {'compare_DE_vs_full_scan','compare_chaos_indicators'});
profile = validatestring(profile, {'demo','paper'});
cfg.schemaVersion = 2;
cfg.mode = mode; cfg.profile = profile;
cfg.model = struct('lambda',3.01,'sigma',1.03,'beta',0.99);
cfg.horizon = struct('cheap',1000,'transient',100,'ftle',2000);
cfg.search = struct('bRange',[1 1.6],'bStep',0.0001, ...
    'includeLowerEndpoint',false,'snapToGrid',true, ...
    'Q',[0 1.3;0 2.1],'stateStep',[1e-4 1e-4],'stateGridSize',[], ...
    'stateBatchSize',1024,'retainInitialStatesMax',10000,'stateProgressSeconds',30, ...
    'population',20,'mutation',0.8,'strategy',7,'crossover',1,'repetitions',1, ...
    'maxEvaluations',Inf,'seed',20261011,'progressEvery',100);
cfg.parallel = struct('enabled',true,'workers','auto','resizePool',true);
cfg.filters = {'zero_one'}; % Ordered AND gates; optional: 'sali', 'condn'.
cfg.zeroOne = struct('cValues',pi/5+((1:32)-0.5)/32*3*pi/5, ...
    'lagFraction',0.1,'threshold',0.8);
cfg.sali = struct('threshold',1e-8);
cfg.rosenstein = struct('embedding',3,'delay',1,'theiler',32, ...
    'maxIter',48,'fit',5:20,'minPairs',20,'minR2',0.9);
cfg.condn = struct('reservoirSize',100,'samplingFactors',[1 2 4 8], ...
    'spectralRadius',0.9,'inputScale',0.5,'biasScale',0.2, ...
    'aperture',10,'ridge',1e-6,'seed',20261009,'threshold',0);
cfg.detector = struct('ftleThreshold',0.005,'regularTolerance',1e-7, ...
    'maxPeriod',32,'maxState',1e8);
cfg.timing = struct('b',1.54,'x0',[0.5 1], ...
    'indicators',{{'zero_one','sali','condn'}},'repetitions',7,'warmupPasses',1);
cfg.output = struct('enabled',true,'plots',true,'visible',true, ...
    'directory',fullfile(fileparts(mfilename('fullpath')),'results',mode,profile));
if strcmp(profile,'paper')
    cfg.horizon = struct('cheap',5000,'transient',1000,'ftle',10000);
end
if strcmp(mode,'compare_chaos_indicators')
    cfg.horizon.transient = 0; % Timing uses the full requested interval.
end
end
