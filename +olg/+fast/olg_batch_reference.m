function out=olg_batch_reference(theta,U,ids,cfg)
% Vectorized rejection and trajectory integration within one worker chunk.
% Only surviving paths reach the indicators; stop indicator calls on a hit.
H=cfg.burn+cfg.sample; origin=all(U==0,2); alive=find(~origin);
c=U(alive,1); l=U(alive,2); history=zeros(min(H,32),numel(alive));
out=struct('trajectories',size(U,1),'stage1Steps',0,'stage2Steps',0, ...
    'zeroOneCalls',0,'rosensteinCalls',0,'survivors',sum(origin), ...
    'nonzeroSurvivors',0,'candidate',false,'path',struct(), ...
    'phaseIndex',NaN,'score',-1,'screeningDeferred',0);
for t=1:H
    out.stage1Steps=out.stage1Steps+numel(alive);
    cn=l.^theta(2)-c; ln=theta(3)*(cfg.beta*l-c.^theta(1));
    good=cn>=0 & ln>=0 & isfinite(cn) & isfinite(ln) & ...
        cn<=cfg.maxState & ln<=cfg.maxState;
    if ~all(good), alive=alive(good); history=history(:,good); end
    c=cn(good); l=ln(good);
    if isempty(alive), break; end
    % Most invalid paths exit early. Allocate the long history only for
    % those still alive after 32 updates, keeping their earlier iterates.
    if t==33, history(H,numel(alive))=0; end
    history(t,:)=c';
end
out.survivors=out.survivors+numel(alive); out.nonzeroSurvivors=numel(alive);
for j=1:numel(alive)
    r=olg.fast.olg_finish_reference(theta,U(alive(j),:),history(:,j),[c(j) l(j)],cfg);
    out.stage2Steps=out.stage2Steps+r.stage2Steps;
    out.zeroOneCalls=out.zeroOneCalls+r.zeroOneCalls;
    out.rosensteinCalls=out.rosensteinCalls+r.rosensteinCalls;
    if ~r.survived
        out.survivors=out.survivors-1; out.nonzeroSurvivors=out.nonzeroSurvivors-1;
    end
    if r.survived && (isempty(fieldnames(out.path)) || r.score>out.score)
        out.path=r; out.score=r.score; out.phaseIndex=ids(alive(j));
    end
    if r.candidate
        out.candidate=true; out.screeningDeferred=numel(alive)-j; break;
    end
end
end
