function [dur,trace] = coverage_time(routes, bombs, mids, D, dt, full_target)
C = make_clouds(routes, bombs, D);
dur = zeros(numel(mids),1);
trace = struct('mid',{},'t',{},'hit',{});
if ~C.ok, dur(:) = -1; return; end

for h = 1:numel(mids)
    j = mids(h);
    t = (0:dt:D.T(j))';
    e = -D.m0(j,:) / norm(D.m0(j,:));
    M = D.m0(j,:) + D.vm*t.*e;
    hit = false(numel(t),1);

    if ~full_target
        q = D.tc;
        for i = 1:numel(C.tb)
            id = find(t >= C.tb(i) & t <= C.te(i));
            if isempty(id), continue; end
            cc = C.burst(i,:) - [zeros(numel(id),2), D.vs*(t(id)-C.tb(i))];
            hit(id) = hit(id) | line_hit(M(id,:), q, cc, D.rs);
        end
    else
        for n = 1:numel(t)
            active = find(t(n) >= C.tb & t(n) <= C.te);
            if isempty(active), continue; end
            m = M(n,:);
            vis = sum(D.normal .* (m-D.side), 2) >= 0;
            if m(3) > 10
                q = [D.side(vis,:); D.top];
            else
                q = D.side(vis,:);
            end
            covered = false(size(q,1),1);
            for i = active'
                cc = C.burst(i,:) - [0 0 D.vs*(t(n)-C.tb(i))];
                covered = covered | line_hit(repmat(m,size(q,1),1), q, ...
                    repmat(cc,size(q,1),1), D.rs);
            end
            hit(n) = all(covered);
        end
    end
    dur(h) = trapz(t, double(hit));
    if nargout>1
        trace(h).mid = j;
        trace(h).t = t;
        trace(h).hit = hit;
    end
end
end

function yes = line_hit(m, q, c, r)
if size(q,1) == 1, q = repmat(q,size(m,1),1); end
v = q-m;
w = c-m;
u = sum(w.*v,2) ./ max(sum(v.^2,2), eps);
u = min(1,max(0,u));
d2 = sum((c-(m+u.*v)).^2,2);
yes = d2 <= r^2;
end
