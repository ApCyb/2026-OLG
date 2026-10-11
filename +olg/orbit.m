function [path, status, steps] = orbit(path, target, model, b, maxState)
% Extend x_0,...,x_k to x_target. No tangent calculation or clipping.
% steps includes an attempted step that leaves Pi; path contains valid states.
k0 = size(path,1)-1;
assert(target>=k0,'OLG:Horizon','Cannot shorten an orbit when extending it.');
x = path(end,:);
if target>k0, path(target+1,:) = 0; end
status = 'survived'; steps = 0;
for k = k0+1:target
    x = olg.step(x,model,b); steps = steps+1;
    if ~isreal(x) || any(~isfinite(x))
        status = 'numerical_failure'; path = path(1:k,:); return;
    elseif any(x<0)
        status = 'left_Pi'; path = path(1:k,:); return;
    elseif any(x>maxState)
        status = 'state_limit'; path = path(1:k,:); return;
    end
    path(k+1,:) = x;
end
end
