function [value, details] = indicator(name, path, cfg, b)
% path is x_transient,...,x_N; scalar signals are x_(transient+1),...,x_N.
details=struct;
switch name
    case 'zero_one'
        [value,details.correlations]=olg.zero_one(path(2:end,1),cfg.zeroOne);
    case 'sali'
        value=olg.sali(path,cfg.model,b);
    case 'condn'
        [value,details]=olg.condn(path(2:end,1),cfg.condn);
    case 'ftle'
        [value,details]=olg.rosenstein(path(2:end,1),cfg.rosenstein);
    otherwise
        error('OLG:Indicator','Unknown indicator: %s',name);
end
end
