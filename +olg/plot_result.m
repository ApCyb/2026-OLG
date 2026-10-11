function f = plot_result(result)
cfg=result.cfg; visibility='off';
if cfg.output.visible, visibility='on'; end
f=figure('Name',cfg.mode,'Visible',visibility,'Color','w','Position',[100 100 1200 450]);
if strcmp(cfg.mode,'compare_chaos_indicators')
    labels=result.summary.Indicator;
    labels(labels=="zero_one")="0-1 test"; labels(labels=="sali")="SALI";
    labels(labels=="condn")="ConDN"; labels(labels=="rosenstein_lle")="Rosenstein LLE";
    labels(labels=="cheap_total")="Cheap total";
    cats=reordercats(categorical(labels),cellstr(labels));
    bar(cats,result.summary.MedianSeconds);
    ylabel('Median seconds'); title('Sequential indicator timing'); grid on;
    set(gca,'TickLabelInterpreter','none');
else
    tiledlayout(1,3);
    if isstruct(result.initialStates)
        shape=result.initialStates.shape;
        sgtitle(sprintf('%s horizons; Q grid %d x %d; full Q traversal per parameter', ...
            cfg.profile,shape(1),shape(2)));
    end
    nexttile; hold on;
    for k=1:numel(result.runs)
        r=result.runs(k); T=r.ledger;
        plot(T.Evaluation,T.B,'.-','DisplayName',sprintf('%s, rep %d',r.method,r.repetition));
        hit=find(T.Candidate,1);
        if ~isempty(hit), plot(T.Evaluation(hit),T.B(hit),'ko','HandleVisibility','off'); end
    end
    yline(result.criticalB,'--','1 / beta','HandleVisibility','off');
    xlabel('Parameter evaluations'); ylabel('b_L'); legend('Location','best','Interpreter','none'); grid on;
    set(gca,'XScale','log');
    labels=replace(result.summary.Method,"full_scan","grid")+" "+string(result.summary.Repetition);
    cats=reordercats(categorical(labels),cellstr(labels));
    nexttile; bar(cats,result.summary.Evaluations);
    ylabel('Evaluations to candidate or budget'); grid on;
    text(cats,result.summary.Evaluations,string(result.summary.Evaluations), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
    seconds=result.summary.ElapsedSeconds; found=result.summary.CandidateFound;
    seconds(found)=result.summary.FirstCandidateSeconds(found);
    nexttile; bar(cats,seconds);
    ylabel('Seconds to candidate or budget'); grid on;
    text(cats,seconds,compose('%.2f',seconds), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
end
if cfg.output.enabled
    exportgraphics(f,fullfile(cfg.output.directory,'comparison.png'),'Resolution',180);
    savefig(f,fullfile(cfg.output.directory,'comparison.fig'));
end
if ~cfg.output.visible, close(f); end
end
