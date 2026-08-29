function [x, fx] = local_search(fun, x, lb, ub, step, rounds)
fx = fun(x);
for r = 1:rounds
    changed = false;
    for j = 1:numel(x)
        for s = [-1 1]
            y = x;
            y(j) = min(ub(j),max(lb(j),x(j)+s*step(j)));
            fy = fun(y);
            if fy < fx, x = y; fx = fy; changed = true; end
        end
    end
    if ~changed, step = step/2; end
end
end
