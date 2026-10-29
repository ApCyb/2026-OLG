function e=evaluate(b,U,cfg,checkpoint)
% Optimized staged evaluator; a negative requires complete Q coverage.
if nargin<4, checkpoint=''; end
if isfield(cfg,'preparedFast'), f=cfg.preparedFast; else, f=olg.fast_config(cfg); end
if ~isempty(checkpoint), f.evalCheckpoint=checkpoint; end
if isnumeric(U)
    raw=olg.fast.olg_staged_batch([f.lambda f.sigma b],U,(1:size(U,1))',f);
    % Explicit point sets are useful for positive controls, not production Q.
    e=raw; return;
end
e=olg.fast.olg_staged_evaluate([f.lambda f.sigma b],U,f);
end
