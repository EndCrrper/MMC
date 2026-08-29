function [best, fbest] = de_search(fun, lb, ub, np, ng, seed)
rng(seed);
d = numel(lb);
pop = lb + rand(np,d).*(ub-lb);
fit = zeros(np,1);
for i = 1:np, fit(i) = fun(pop(i,:)); end

for g = 1:ng
    for i = 1:np
        ids = randperm(np,3);
        while any(ids == i), ids = randperm(np,3); end
        y = pop(ids(1),:) + 0.75*(pop(ids(2),:)-pop(ids(3),:));
        y = min(ub,max(lb,y));
        take = rand(1,d) < 0.85;
        take(randi(d)) = true;
        z = pop(i,:);
        z(take) = y(take);
        fz = fun(z);
        if fz < fit(i), pop(i,:) = z; fit(i) = fz; end
    end
end
[fbest,k] = min(fit);
best = pop(k,:);
end
