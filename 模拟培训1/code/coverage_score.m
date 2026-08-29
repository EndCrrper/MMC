function s = coverage_score(routes,bombs,mids,D,dt)
C = make_clouds(routes,bombs,D);
if ~C.ok, s = -1; return; end
s = 0;
for j = mids
    t = (0:dt:D.T(j))';
    e = -D.m0(j,:)/norm(D.m0(j,:));
    M = D.m0(j,:) + D.vm*t.*e;
    best = zeros(size(t));
    for i = 1:numel(C.tb)
        id = find(t>=C.tb(i) & t<=C.te(i));
        if isempty(id), continue; end
        cc = C.burst(i,:) - [zeros(numel(id),2),D.vs*(t(id)-C.tb(i))];
        q = repmat(D.tc,numel(id),1);
        v = q-M(id,:);
        u = sum((cc-M(id,:)).*v,2)./sum(v.^2,2);
        u = min(1,max(0,u));
        d = vecnorm(cc-(M(id,:)+u.*v),2,2);
        best(id) = max(best(id),1./(1+exp((d-D.rs)/2)));
    end
    s = s + trapz(t,best);
end
end
