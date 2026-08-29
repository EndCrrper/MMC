function [t,A] = plan_point_cover(routes,bombs,j,D,dt)
C=make_clouds(routes,bombs,D);
t=(0:dt:D.T(j))';
q=[D.side;D.top];
A=false(numel(t),size(q,1));
e=-D.m0(j,:)/norm(D.m0(j,:));
M=D.m0(j,:)+D.vm*t.*e;
ns=size(D.side,1);
for n=1:numel(t)
    m=M(n,:);
    vis=[sum(D.normal.*(m-D.side),2)>=0;true(size(D.top,1),1)];
    if m(3)<=10, vis(ns+1:end)=false; end
    hit=~vis;
    active=find(t(n)>=C.tb & t(n)<=C.te);
    for i=active'
        cc=C.burst(i,:)-[0 0 D.vs*(t(n)-C.tb(i))];
        hit=hit|line_cover(m,q,cc,D.rs);
    end
    A(n,:)=hit;
end
end

function yes = line_cover(m,q,c,r)
v=q-m;
w=c-m;
u=sum(w.*v,2)./max(sum(v.^2,2),eps);
u=min(1,max(0,u));
yes=sum((c-(m+u.*v)).^2,2)<=r^2;
end
