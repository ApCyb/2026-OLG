function y = step(x, model, b)
% Exact OLG map; caller checks admissibility before the next evaluation.
y = [x(2)^model.sigma-x(1), b*(model.beta*x(2)-x(1)^model.lambda)];
end
