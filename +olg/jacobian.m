function J = jacobian(x, model, b)
J = [-1, model.sigma*x(2)^(model.sigma-1); ...
    -b*model.lambda*x(1)^(model.lambda-1), b*model.beta];
end
