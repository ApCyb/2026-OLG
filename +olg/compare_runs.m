function comparison = compare_runs(summary)
% Ratios are defined only for paired successful discoveries, never censoring.
repetitions=unique(summary.Repetition); ratios=nan(numel(repetitions),3);
for k=1:numel(repetitions)
    d=summary(summary.Repetition==repetitions(k) & summary.Method=="de",:);
    g=summary(summary.Repetition==repetitions(k) & summary.Method=="full_scan",:);
    if height(d)==1 && height(g)==1 && d.CandidateFound && g.CandidateFound
        ratios(k,:)=[g.Evaluations/d.Evaluations, ...
            g.FirstCandidateSeconds/d.FirstCandidateSeconds,g.ElapsedSeconds/d.ElapsedSeconds];
    end
end
comparison=table(repetitions,ratios(:,1),ratios(:,2),ratios(:,3), ...
    'VariableNames',{'Repetition','GridOverDEEvaluations', ...
    'GridOverDEDiscoveryTime','GridOverDEWallTime'});
end
