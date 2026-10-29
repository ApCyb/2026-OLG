function tests=test_fex_and_batches
tests=functiontests(localfunctions);
end

function testNativeEngineBudgetAndReproducibility(t)
c=olg_config; c.search.population=4; c.search.seed=1234;
B=(1.0001:0.0001:1.002)';
oldDir=pwd; oldPath=path; oldRng=rng;
trace=[]; native=false;
a=olg.fex_de(B,c.search,7,1,@visit); first=trace;
verifyTrue(t,native); verifyEqual(t,size(first,1),7);
verifyTrue(t,all(first(1:4,2)==0)); verifyGreaterThan(t,first(end,2),0);
verifyTrue(t,all(ismember(first(:,1),B)));
verifyEqual(t,a.fileExchangeID,18593); verifyEqual(t,a.version,'1.16.0');
verifyEqual(t,a.parameters.strategy,7); verifyEqual(t,a.parameters.CR,1);
verifyEqual(t,a.parameters.saveHistory,0); verifyEqual(t,a.evaluations,7);
verifyEqual(t,a.stopReason,'budget_exhausted');
trace=[]; olg.fex_de(B,c.search,7,1,@visit); verifyEqual(t,trace,first);
verifyEqual(t,pwd,oldDir); verifyEqual(t,path,oldPath); verifyEqual(t,rng,oldRng);
trace=[]; a=olg.fex_de(B,c.search,1,1,@visit);
verifyEqual(t,a.evaluations,1); verifyEqual(t,size(trace,1),1);

    function [score,candidate]=visit(b,generation)
        stack=dbstack;
        native=native || any(strcmp({stack.name},'differentialevolution'));
        trace(end+1,:)=[b,generation];
        score=0; candidate=false;
    end
end

function testNativeEngineCandidateAndErrors(t)
c=olg_config; c.search.population=4;
B=(1.0001:0.0001:1.002)'; oldDir=pwd; oldPath=path; oldRng=rng;
calls=0;
a=olg.fex_de(B,c.search,20,1,@visit);
verifyEqual(t,a.evaluations,2); verifyEqual(t,a.stopReason,'candidate_found');
verifyError(t,@()olg.fex_de(B,c.search,20,1,@fail),'OLG:DeliberateTest');
verifyEqual(t,pwd,oldDir); verifyEqual(t,path,oldPath); verifyEqual(t,rng,oldRng);
    function [score,candidate]=visit(~,~)
        calls=calls+1; score=0; candidate=calls==2;
    end
    function [score,candidate]=fail(~,~) %#ok<STOUT>
        error('OLG:DeliberateTest','An evaluator failure must propagate.');
    end
end

function testStateBlocksCoverEveryPoint(t)
c=olg_config; c.search.stateOrder='lex'; c.search.Q=[0 0.0002;0 0.0003];
[~,U]=olg.grids(c); [C,L]=ndgrid(U.C,U.L); expected=[C(:) L(:)];
actual=[olg.state_block(U,1,5);olg.state_block(U,6,U.count)];
verifyEqual(t,actual,expected); verifySize(t,actual,[12 2]);
c.search.Q(1,2)=0.00025;
verifyError(t,@()olg.grids(c),'OLG:PhaseGrid');
end

function testPositiveTraversalOptionAndNegativeFullScan(t)
c=olg_config; c.parallel.enabled=false; c.output.enabled=false;
c.search.Q=[.49 .51;.99 1.01]; c.search.stateStep=[.01 .01];
c.search.stateOrder='lex'; c.search.stateChunkSize=2; c.search.stateBatchSize=4;
c.search.diagnostics=false; c.rosenstein.neighborMethod='brute';
[~,U]=olg.grids(c);
a=olg.evaluate(1.54,U,c); verifyTrue(t,a.candidate);
verifyLessThan(t,a.trajectories,U.count); verifyFalse(t,a.exhaustedPhasePool);
c.search.phaseScan='full'; c.output.enabled=true; c.output.directory=tempname;
b=olg.evaluate(1.54,U,c,[tempname '.mat']); verifyTrue(t,b.candidate); verifyEqual(t,b.trajectories,U.count);
verifyTrue(t,b.exhaustedPhasePool);
c.search.Q=[0 .0001;0 .0001]; c.search.stateStep=[.0001 .0001];
c.search.phaseScan='first_hit'; [~,U]=olg.grids(c);
e=olg.evaluate(1,U,c); verifyFalse(t,e.candidate); verifyTrue(t,e.exhaustedPhasePool);
verifyEqual(t,e.trajectories,U.count);
end

function testUpstreamFilesUnmodified(t)
root=fileparts(fileparts(mfilename('fullpath')));
manifest=jsondecode(fileread(fullfile(root,'vendor','fex18593_manifest.json')));
files=dir(fullfile(root,'vendor','fex18593','*')); files=files(~[files.isdir]);
verifyEqual(t,numel(files),38);
for k=1:numel(files)
    fid=fopen(fullfile(files(k).folder,files(k).name),'rb');
    cleanup=onCleanup(@()fclose(fid));
    bytes=fread(fid,Inf,'*uint8'); clear cleanup;
    md=java.security.MessageDigest.getInstance('SHA-256');
    md.update(typecast(bytes,'int8'));
    digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
    key=matlab.lang.makeValidName(files(k).name);
    verifyEqual(t,digest,manifest.filesSHA256.(key),files(k).name);
end
end
