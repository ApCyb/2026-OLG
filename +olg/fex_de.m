function info = fex_de(B,s,budget,rep,visit)
% Run the unmodified Markus Buehren File Exchange 18593 implementation.
% VISIT(b,generation) returns [score,candidate]. Stop after the callback that
% finds a candidate or consumes the budget, including within initialization.
root=fileparts(fileparts(mfilename('fullpath')));
vendor=fullfile(root,'vendor','fex18593');
oldPath=path; oldDir=pwd; oldRng=rng;
work=tempname; mkdir(work);
restore=onCleanup(@()restore_environment(oldDir,oldPath,oldRng,work));
addpath(vendor,'-begin'); addpath(root,'-begin'); cd(work);
required={'differentialevolution','computenewpopulation','getdefaultparams'};
for k=1:numel(required)
    assert(strcmp(which(required{k}),fullfile(vendor,[required{k} '.m'])), ...
        'OLG:DEPath','The bundled DE implementation is shadowed on the MATLAB path.');
end
rng(s.seed+rep-1,'twister');
p=getdefaultparams;
p.NP=s.population; p.F=s.mutation; p.CR=s.crossover; p.strategy=s.strategy;
p.useInitParams=0; p.saveHistory=0; p.displayResults=0;
p.feedSlaveProc=0; p.maxMasterEvals=Inf; p.minimizeValue=0;
p.VTR=NaN; p.maxiter=Inf; p.maxtime=Inf;
p.infoIterations=Inf; p.infoPeriod=Inf;
if s.snapToGrid
    definition={'index',[1 numel(B)],1};
else
    definition={'b',[B(1) B(end)],0};
end
info=struct('name','Markus Buehren Differential Evolution', ...
    'fileExchangeID',18593,'version','1.16.0','releaseDate','2019-11-13', ...
    'sourceURL','https://www.mathworks.com/matlabcentral/fileexchange/18593-differential-evolution', ...
    'archiveSHA256','f7db38622a50982724f20d0af35ad63ad9d740da302561e401c3691859614f80', ...
    'parameters',p,'definition',{definition},'seed',s.seed+rep-1, ...
    'evaluations',0,'stopReason','','entryPoint',which('differentialevolution'));
count=0; stopped=false;
try
    differentialevolution(p,definition,@objective,{},[],[],struct('title','OLG search'));
catch err
    if ~(stopped && strcmp(err.identifier,'OLG:DEStop'))
        rethrow(err);
    end
end
assert(stopped,'OLG:DEUnexpectedStop','Upstream DE returned before the stopping rule was met.');
info.evaluations=count;

    function value=objective(params)
        % Version-pinned, read-only access to the native callback context.
        % This preserves upstream generation numbering, including restarts.
        generation=evalin('caller','iterationNr');
        if s.snapToGrid, b=B(params.index); else, b=params.b; end
        [value,candidate]=visit(b,generation);
        count=count+1;
        assert(isscalar(value) && isfinite(value),'OLG:DEScore','DE requires a finite scalar score.');
        if candidate || count>=budget
            stopped=true;
            if candidate, info.stopReason='candidate_found';
            else, info.stopReason='budget_exhausted'; end
            error('OLG:DEStop','The experiment stopping rule was met.');
        end
    end
end

function restore_environment(oldDir,oldPath,oldRng,work)
cd(oldDir); path(oldPath); rng(oldRng);
if isfolder(work), rmdir(work,'s'); end
end
