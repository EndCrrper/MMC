function C = make_clouds(routes, bombs, D)
n = size(bombs,1);
C.drop = nan(n,3);
C.burst = nan(n,3);
C.tb = nan(n,1);
C.te = nan(n,1);
C.ok = true;

for i = 1:n
    k = bombs(i,1);
    td = bombs(i,2);
    tau = bombs(i,3);
    th = routes(k,1);
    v = routes(k,2);
    e = [cosd(th), sind(th), 0];
    tb = td + tau;
    C.drop(i,:) = D.u0(k,:) + v*td*e;
    C.burst(i,:) = D.u0(k,:) + v*tb*e - [0 0 0.5*D.g*tau^2];
    C.tb(i) = tb;
    C.te(i) = min(tb + D.life, tb + C.burst(i,3)/D.vs);
    C.ok = C.ok && td >= 0 && tau >= 0 && v >= 70 && v <= 140 ...
        && C.burst(i,3) >= 1 && all(isfinite(C.burst(i,:)));
end
end
