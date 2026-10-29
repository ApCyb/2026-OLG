function count=phase_tasks(f,n)
% Cap workers by actual first-batch tasks, including adaptive chunk sizes.
batch=f.phaseBatchSize;
if strcmp(f.phaseScan,'first_hit'), batch=min(batch,f.firstHitBatchSize); end
nominal=max(1,ceil(f.phaseBatchSize/f.phaseChunkSize));
chunk=min(f.phaseChunkSize,max(1,ceil(batch/nominal)));
count=max(1,ceil(min(n,batch)/chunk));
end
