function solve_problem5_milp(dt)
if nargin<1, dt=.2; end
base=fileparts(mfilename('fullpath'));
out=fullfile(base,'..','result');
S=load(fullfile(out,'problem5.mat'));
D=data_a(12,3);

plans=struct('uav',{},'route',{},'bombs',{},'name',{});
for k=1:5
    r=zeros(5,2); r(k,:)=S.routes(k,:);
    b=S.bombs(S.bombs(:,1)==k,:);
    plans(end+1)=pack(k,r,b,'final'); %#ok<AGROW>
    for j=1:3
        r=zeros(5,2); r(k,:)=S.cand(k,j).route;
        plans(end+1)=pack(k,r,S.cand(k,j).bombs,sprintf('M%d',j)); %#ok<AGROW>
    end
end
np=numel(plans);

cov=cell(np,3); times=cell(3,1);
for p=1:np
    for j=1:3
        [times{j},cov{p,j}]=plan_point_cover(plans(p).route,plans(p).bombs,j,D,dt);
    end
end

ny=sum(cellfun(@numel,times));
nvar=np+ny;
f=zeros(nvar,1);
offset=np;
A=[]; bineq=[];
for j=1:3
    nt=numel(times{j}); nq=size(cov{1,j},2);
    C=false(nt*nq,np);
    for p=1:np, C(:,p)=reshape(cov{p,j}',[],1); end
    left=-sparse(C);
    q=(offset-np)+(1:nt);
    rr=(1:nt*nq)'; cc=repelem(q',nq);
    right=sparse(rr,cc,1,nt*nq,ny);
    A=[A;left,right]; %#ok<AGROW>
    bineq=[bineq;zeros(nt*nq,1)]; %#ok<AGROW>
    w=dt*ones(nt,1); w([1 end])=dt/2;
    f(offset+(1:nt))=-w;
    offset=offset+nt;
end

G=sparse([plans.uav],1:np,1,5,nvar);
A=[A;G]; bineq=[bineq;ones(5,1)];
opts=optimoptions('intlinprog','Display','final','RelativeGapTolerance',0,'MaxTime',300);
[z,val,flag,output]=intlinprog(f,1:nvar,A,bineq,[],[],zeros(nvar,1),ones(nvar,1),opts);
selected=find(z(1:np)>.5);

routes=zeros(5,2); bombs=zeros(0,3);
for p=selected'
    k=plans(p).uav;
    routes(k,:)=plans(p).route(k,:);
    bombs=[bombs;plans(p).bombs]; %#ok<AGROW>
end
bombs=sortrows(bombs,[1 2]);
t_full=coverage_time(routes,bombs,1:3,data_a(48,9),.01,true);
milp_time=-val;
save(fullfile(out,'problem5_milp.mat'),'plans','selected','routes','bombs', ...
    'milp_time','t_full','flag','output','dt');
fprintf('MILP %.3f s, strict %.3f s, flag %d\n',milp_time,sum(t_full),flag);
disp([selected,[plans(selected).uav]']);
end

function p = pack(k,r,b,name)
p=struct('uav',k,'route',r,'bombs',b,'name',name);
end
