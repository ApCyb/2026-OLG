function result=benchmark_olg_fast(outputDir,chunkSize,repetitions)
% Matched settings: 1000+4000, same 32 c-values, same nodes and stopping rule.
% This measures representative chunks, NOT an exhaustive Q or five DE trials.
if nargin<1, outputDir=fullfile(fileparts(mfilename('fullpath')),'results','benchmark'); end
if nargin<2, chunkSize=1024; end
if nargin<3, repetitions=3; end
if ~isfolder(outputDir), mkdir(outputDir); end
assert(olg.has_native('olg_integrate_mex') && olg.has_native('olg_nearest_mex') ...
    && olg.has_native('olg_zero_one_native_mex'),'OLG:Build','Run build_olg_fast first.');
cfg=olg.fast_config(olg_config('compare_DE_vs_full_scan','paper')); cfg.useParallel=false; cfg.diagnostics=false;
cfg.phaseProgressSeconds=0; grid=olg.fast.olg_phase_grid(cfg); [U,ids]=olg.fast.olg_phase_points(grid,1:chunkSize);
engines={'reference','matlab','native'}; bValues=[1 1.01 1.25 1.44 1.5069 1.54]; rows=struct([]);
for b=bValues
    theta=[cfg.lambda cfg.sigma b];
    for j=1:numel(engines)
        engine=engines{j}; current=cfg;
        if strcmp(engine,'reference'), evaluate=@olg.fast.olg_batch_reference;
        else
            current.integrator=engine; evaluate=@olg.fast.olg_staged_batch;
            current.zeroOneBackend=engine;
        end
        evaluate(theta,U,ids,current); times=zeros(repetitions,1);
        for rep=1:repetitions
            clock=tic; r=evaluate(theta,U,ids,current); times(rep)=toc(clock);
        end
        K=NaN; LE=NaN;
        if ~isempty(fieldnames(r.path)), K=r.path.K; LE=r.path.rosenstein; end
        rows=[rows;struct('b_L',b,'engine',string(engine),'nodes',size(U,1), ...
            'medianSeconds',median(times),'minSeconds',min(times),'maxSeconds',max(times), ...
            'stage1Steps',r.stage1Steps,'zeroOneCalls',r.zeroOneCalls, ...
            'rosensteinCalls',r.rosensteinCalls,'candidate',r.candidate,'witnessK',K,'witnessLE',LE)]; %#ok<AGROW>
        fprintf('b=%.4f | %s | %.5f s | candidate=%d\n',b,engine,median(times),r.candidate);
    end
end
chunks=struct2table(rows); chunks.speedup=zeros(height(chunks),1);
for j=1:height(chunks)
    ref=chunks.medianSeconds(chunks.b_L==chunks.b_L(j) & chunks.engine=="reference");
    chunks.speedup(j)=ref/chunks.medianSeconds(j);
end
% Indicator kernels receive the SAME signal, isolating arithmetic equivalence.
chunkConfig=cfg; cfg.integrator='matlab'; cfg.burn=0; cfg.sample=10000;
[signal,~,~,~,~,~]=olg.fast.olg_integrate([3.01 1.03 1.54],[.5 1],cfg);
y=signal(1001:5000); opt=cfg.rosenstein;
names={'0-1 old FFT','0-1 batched cached FFT','0-1 native FFT','Rosenstein brute','Rosenstein exact tree'};
call={@()olg.fast.olg_zero_one_fft_reference(y,cfg),@()olg.fast.olg_zero_one_fft(y,cfg), ...
    @()olg.fast.olg_zero_one_native(y,cfg),@()olg.fast.olg_rosenstein_reference(signal,opt),@()olg.fast.olg_rosenstein(signal,opt)};
med=zeros(numel(call),1); values=zeros(numel(call),1);
for j=1:numel(call)
    call{j}(); times=zeros(repetitions,1);
    for rep=1:repetitions, t=tic; value=call{j}(); times(rep)=toc(t); end
    med(j)=median(times); if isstruct(value), values(j)=value.lle; else, values(j)=value; end
end
components=table(string(names(:)),med,values,'VariableNames',{'component','medianSeconds','value'});
result=struct('chunks',chunks,'components',components,'repetitions',repetitions, ...
    'config',chunkConfig,'MATLAB',version,'computer',computer,'fullQExecuted',false);
writetable(chunks,fullfile(outputDir,'chunk_benchmark.csv'));
writetable(components,fullfile(outputDir,'component_benchmark.csv'));
save(fullfile(outputDir,'benchmark.mat'),'result'); disp(chunks); disp(components);
end
