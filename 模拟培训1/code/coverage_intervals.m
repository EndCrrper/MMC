function info = coverage_intervals(routes,bombs,mids,D,dt)
[dur,tr] = coverage_time(routes,bombs,mids,D,dt,true);
info = struct([]);
for h = 1:numel(mids)
    t=tr(h).t; hit=tr(h).hit;
    info(h).mid=mids(h);
    info(h).duration=dur(h);
    info(h).covered=runs(t,hit);
    info(h).gaps=runs(t,~hit);
end
end

function a = runs(t,x)
d = diff([false;x;false]);
i1 = find(d(1:end-1)==1);
i2 = find(d(2:end)==-1);
left = t(i1); right = t(i2);
q = i1>1;
left(q) = (t(i1(q)-1)+t(i1(q)))/2;
q = i2<numel(t);
right(q) = (t(i2(q))+t(i2(q)+1))/2;
a = [left,right];
end
