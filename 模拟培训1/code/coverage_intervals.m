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
d=diff([false;x;false]);
a=[t(d(1:end-1)==1),t(d(2:end)==-1)];
end
