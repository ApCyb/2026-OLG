function f=plot_result(result)
cfg=result.cfg; visibility='off'; if cfg.output.visible, visibility='on'; end
f=figure('Name',cfg.mode,'Visible',visibility,'Color','w','Position',[100 100 1200 470]);
if strcmp(cfg.mode,'compare_chaos_indicators')
    labels=result.summary.Indicator+" ("+string(result.summary.EndIteration)+")";
    bar(categorical(labels,labels),result.summary.MedianSeconds);
    ylabel('Median seconds'); title('Sequential timing: optimized indicators / Rosenstein'); grid on;
    set(gca,'TickLabelInterpreter','none'); xtickangle(20);
elseif isfield(result,'gridEstimates')
    tiledlayout(1,2); S=result.deSummary; E=result.gridEstimates;
    labels=["DE measured mean";"Grid prefix estimate";"Grid regime estimate"];
    nexttile; estimate_bars(labels,[S.meanUniqueEvaluations;E.assumedEvaluations]);
    ylabel('New parameter evaluations'); grid on;
    nexttile; estimate_bars(labels,[S.meanSearchSecondsUsed;E.estimatedSearchSeconds]);
    ylabel('Committed search seconds'); grid on;
    sgtitle('Measured DE / EXTRAPOLATED grid cost; grid search not completed');
else
    tiledlayout(1,3); nexttile; hold on;
    for k=1:numel(result.runs)
        r=result.runs(k); T=r.ledger;
        plot(T.Evaluation,T.B,'.-','DisplayName',sprintf('%s, rep %d',r.method,r.repetition));
    end
    yline(result.criticalB,'--','1 / beta','HandleVisibility','off');
    xlabel('Parameter requests'); ylabel('b_L'); legend('Location','best','Interpreter','none'); grid on;
    set(gca,'XScale','log');
    labels=result.summary.Method+" "+string(result.summary.Repetition);
    cats=categorical(labels,unique(labels,'stable'));
    nexttile; bar(cats,result.summary.UniqueEvaluations); ylabel('New parameter evaluations'); grid on;
    nexttile; bar(cats,result.summary.ElapsedSeconds); ylabel('Committed search seconds'); grid on;
    sgtitle(sprintf('%s; Q: %.0f states; measured DE and full scan',cfg.profile,result.initialStates.count));
end
if cfg.output.enabled
    exportgraphics(f,fullfile(cfg.output.directory,'comparison.png'),'Resolution',180);
    savefig(f,fullfile(cfg.output.directory,'comparison.fig'));
end
if ~cfg.output.visible, close(f); end
end

function estimate_bars(labels,values)
cats=categorical(labels,labels); h=bar(cats,values); h.FaceColor='flat';
h.CData=[.1 .4 .7;.9 .6 .1;.9 .6 .1]; set(gca,'YScale','log');
valid=values(isfinite(values) & values>0);
if ~isempty(valid), ylim([min(valid)*.65,max(valid)*1.4]); end
text(cats,values,compose('%.3g',values),'HorizontalAlignment','center','VerticalAlignment','bottom');
end
