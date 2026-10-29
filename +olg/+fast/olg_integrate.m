function [history,last,alive,steps,origins,historyL,detail]=olg_integrate(theta,U,cfg,keepL)
% Same first-step expressions; reusable coordinate powers, no rounding of U.
if nargin<4, keepL=false; end
H=cfg.burn+cfg.sample;
cached=false;
if isfield(cfg,'phaseLookup') && theta(1)==cfg.lambda && theta(2)==cfg.sigma
    step=cfg.stateStep; if isscalar(step), step=[step step]; end
    ic=round((U(:,1)-cfg.Q(1,1))/step(1))+1;
    il=round((U(:,2)-cfg.Q(2,1))/step(2))+1; lookup=cfg.phaseLookup;
    cached=all(ic>=1 & ic<=numel(lookup.c) & il>=1 & il<=numel(lookup.l));
    if cached, cached=isequal(U(:,1),lookup.c(ic)) && isequal(U(:,2),lookup.l(il)); end
end
if cached
    first=[lookup.lPower(il)-U(:,1),theta(3)*(cfg.beta*U(:,2)-lookup.cPower(ic))];
else
    first=[U(:,2).^theta(2)-U(:,1),theta(3)*(cfg.beta*U(:,2)-U(:,1).^theta(1))];
end
if strcmp(cfg.integrator,'native')
    if nargout>=7
        [history,last,alive,steps,origins,historyL,detail]=olg.fast.olg_integrate_mex(U,first,theta,cfg.beta,double(H),cfg.maxState,double(keepL));
    else
        [history,last,alive,steps,origins,historyL]=olg.fast.olg_integrate_mex(U,first,theta,cfg.beta,double(H),cfg.maxState,double(keepL));
    end
    return;
end
% Fixed history slots: remove only state/index vectors after exits. Never copy
% a 5000-row history matrix every time a trajectory leaves the quadrant.
origin=all(U==0,2); origins=sum(origin); alive=find(~origin); steps=0;
detail=[];
if nargout>=7, detail=zeros(size(U,1),4); detail(origin,4)=1; end
c=U(alive,1); l=U(alive,2); history=zeros(min(H,32),numel(alive));
historyL=[]; if keepL, historyL=zeros(size(history)); end
slots=(1:numel(alive))';
for t=1:H
    steps=steps+numel(alive);
    if t==1, cn=first(alive,1); ln=first(alive,2);
    else, cn=l.^theta(2)-c; ln=theta(3)*(cfg.beta*l-c.^theta(1)); end
    good=cn>=0 & ln>=0 & isfinite(cn) & isfinite(ln) & cn<=cfg.maxState & ln<=cfg.maxState;
    if nargout>=7
        code=5*ones(numel(alive),1); code(cn>cfg.maxState | ln>cfg.maxState)=4;
        code(~isfinite(cn) | ~isfinite(ln))=3; code(cn<0 | ln<0)=2;
        detail(alive,:)=[cn ln repmat(t,numel(alive),1) code]; %#ok<AGROW>
    end
    alive=alive(good); slots=slots(good); c=cn(good); l=ln(good);
    if isempty(alive), break; end
    if t==33
        history=history(:,slots); history(H,numel(alive))=0;
        if keepL, historyL=historyL(:,slots); historyL(H,numel(alive))=0; end
        slots=(1:numel(alive))';
    end
    history(t,slots)=c'; if keepL, historyL(t,slots)=l'; end %#ok<AGROW>
end
if isempty(alive), history=zeros(H,0); historyL=zeros(H,0);
else, history=history(:,slots); if keepL, historyL=historyL(:,slots); end, end
last=[c l];
end
