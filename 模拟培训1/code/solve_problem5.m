base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir,'..','result');
if ~exist(result_dir,'dir'), mkdir(result_dir); end
D = data_a();

cand = repmat(struct('x',[],'route',[],'bombs',[]),5,3);
for k = 1:5
    for j = 1:3
        tm = sqrt(2*D.u0(k,3)/D.g);
        lb = [0 70 0 0 0 0 0 0];
        ub = [360 140 32 13 13 tm tm tm];
        f = @(x) cost_uav(x,k,j,D,0.1);
        [x,~] = de_search(f,lb,ub,30,42,500+10*k+j);
        [x,~] = local_search(f,x,lb,ub,[10 8 1 1 1 0.8 0.8 0.8],2);
        [r,b] = decode_uav(x,k);
        cand(k,j).x = x;
        cand(k,j).route = r(k,:);
        cand(k,j).bombs = b;
    end
end

combo_assign = zeros(243,5);
combo_score = zeros(243,3);
for code = 0:242
    a = mod(floor(code./(3.^(0:4))),3)+1;
    [routes,bombs] = join_plan(cand,a);
    combo_assign(code+1,:) = a;
    combo_score(code+1,:) = coverage_time(routes,bombs,1:3,D,0.1,true)';
end

total = sum(combo_score,2);
best_sum = max(total);
near = find(total >= best_sum-0.05);
worst = min(combo_score(near,:),[],2);
top = near(worst == max(worst));
[~,id] = max(total(top));
assign = combo_assign(top(id),:);
candidate_assign = assign;

xs = cell(5,1);
for k = 1:5, xs{k} = cand(k,assign(k)).x; end
[r0,b0] = join_xs(xs);
xs0 = xs;
sum_floor = sum(coverage_time(r0,b0,1:3,D,0.08,true))-0.05;
for k = 1:5
    tm = sqrt(2*D.u0(k,3)/D.g);
    lb = [0 70 0 0 0 0 0 0];
    ub = [360 140 32 13 13 tm tm tm];
    f = @(z) cost_context(z,k,xs,D,sum_floor);
    [xs{k},~] = local_search(f,xs{k},lb,ub,[6 5 0.7 0.7 0.7 0.5 0.5 0.5],2);
end
[routes,bombs] = join_xs(xs);
f0 = coverage_time(r0,b0,1:3,D,0.02,true);
f1 = coverage_time(routes,bombs,1:3,D,0.02,true);
if sum(f0)>sum(f1)+0.05 || (sum(f0)>=sum(f1)-0.05 && min(f0)>min(f1))
    xs=xs0; routes=r0; bombs=b0;
end
[bombs,removed,kept] = prune_bombs(routes,bombs,D,.02);
[routes,bombs] = refine_plan(routes,bombs,D);
[bombs,removed2,kept] = prune_bombs(routes,bombs,D,.02,kept);
removed = [removed; removed2];
added_seed=zeros(0,3);
bomb_id=kept;
next_id=16;
for cycle=1:9
    [r_keep,b_keep] = deal(routes,bombs);
    keep_score = coverage_time(routes,bombs,1:3,D,.02,true);
    [b_try,a_try] = add_bombs(routes,bombs,D);
    [r_try,b_try] = refine_plan(routes,b_try,D);
    new_score = coverage_time(r_try,b_try,1:3,D,.02,true);
    gain_sum=sum(new_score)-sum(keep_score);
    gain_min=min(new_score)-min(keep_score);
    if gain_sum>.01 || (gain_sum>=-.02 && gain_min>.01)
        routes=r_try; bombs=b_try;
        added_seed=[added_seed;a_try]; %#ok<AGROW>
        nadd=size(a_try,1);
        bomb_id=[bomb_id;(next_id:next_id+nadd-1)']; %#ok<AGROW>
        next_id=next_id+nadd;
    else
        routes=r_keep; bombs=b_keep; break
    end
end
[bombs,removed_final,bomb_id] = prune_bombs(routes,bombs,D,.02,bomb_id);
[bombs,ord] = sortrows(bombs,[1 2]);
bomb_id=bomb_id(ord);
C = make_clouds(routes,bombs,D);
t_center = coverage_time(routes,bombs,1:3,D,0.01,false);
t_full = coverage_time(routes,bombs,1:3,D,0.02,true);

primary = zeros(size(bombs,1),1);
marginal_time = zeros(size(bombs,1),1);
independent_time = zeros(size(bombs,1),1);
for i = 1:size(bombs,1)
    keep = true(size(bombs,1),1); keep(i)=false;
    d = max(0,t_full-coverage_time(routes,bombs(keep,:),1:3,D,.02,true));
    [marginal_time(i),primary(i)] = max(d);
    independent_time(i) = coverage_time(routes,bombs(i,:),primary(i),D,.02,true);
end

save(fullfile(result_dir,'problem5.mat'),'cand','combo_assign','combo_score', ...
    'candidate_assign','routes','bombs','C','t_center','t_full','primary', ...
    'marginal_time','independent_time','bomb_id','removed','removed_final','added_seed');
fprintf('P5: %.3f s, full %.3f s\n',sum(t_center),sum(t_full));

function [b,removed,original_id] = prune_bombs(r,b,D,tol,original_id)
base = coverage_time(r,b,1:3,D,.02,true);
floor_sum = sum(base)-tol;
floor_min = min(base)-tol;
removed = zeros(0,1);
if nargin<5, original_id = (1:size(b,1))'; end
while size(b,1)>1
    best=-inf; pick=0;
    for i=1:size(b,1)
        keep=true(size(b,1),1); keep(i)=false;
        s=coverage_time(r,b(keep,:),1:3,D,.02,true);
        if sum(s)>=floor_sum && min(s)>=floor_min && sum(s)>best
            best=sum(s); pick=i;
        end
    end
    if pick==0, break; end
    removed(end+1,1)=original_id(pick); %#ok<AGROW>
    original_id(pick)=[];
    b(pick,:)=[];
end
end

function [r,b] = refine_plan(r,b,D)
base = coverage_time(r,b,1:3,D,.02,true);
for pass = 1:2
    for k = unique(b(:,1))'
        id=find(b(:,1)==k); n=numel(id);
        z=[r(k,:),reshape(b(id,2:3)',1,[])];
        tm=sqrt(2*D.u0(k,3)/D.g);
        lb=[0 70,repmat([0 0],1,n)];
        ub=[360 140,repmat([max(D.T) tm],1,n)];
        f=@(x) block_cost(x,k,id,r,b,D);
        [z,~]=local_search(f,z,lb,ub,[4 4,repmat([1 .5],1,n)],4);
        [rt,bt]=put_block(z,k,id,r,b);
        s=coverage_time(rt,bt,1:3,D,.02,true);
        if sum(s)>sum(base)+.01 || (sum(s)>=sum(base)-.02 && min(s)>min(base)+.01)
            r=rt; b=bt; base=s;
        end
    end
end
end

function y = block_cost(z,k,id,r,b,D)
[r,b]=put_block(z,k,id,r,b);
C=make_clouds(r,b,D);
td=sort(b(id,2));
if ~C.ok || any(C.tb>max(D.T)) || (numel(td)>1 && min(diff(td))<1)
    y=1e4; return
end
s=coverage_time(r,b,1:3,D,.05,true);
y=-sum(s)-1e-3*min(s);
end

function [r,b] = put_block(z,k,id,r,b)
r(k,:)=z(1:2);
b(id,2:3)=reshape(z(3:end),2,[])';
end

function y = cost_uav(x,k,j,D,dt)
[routes,bombs] = decode_uav(x,k);
C = make_clouds(routes,bombs,D);
if ~C.ok || any(C.tb>D.T(j)), y = 1e4; return; end
y = -coverage_score(routes,bombs,j,D,dt);
end

function y = cost_context(z,k,xs,D,sum_floor)
tmp = xs;
tmp{k} = z;
[routes,bombs] = join_xs(tmp);
C = make_clouds(routes,bombs,D);
if ~C.ok || any(C.tb>max(D.T)), y = 1e4; return; end
s = coverage_time(routes,bombs,1:3,D,0.08,true);
if sum(s) < sum_floor
    y = 100 + 100*(sum_floor-sum(s));
else
    y = -min(s) - 1e-3*sum(s);
end
end

function [routes,bombs] = decode_uav(x,k)
routes = zeros(5,2);
routes(k,:) = x(1:2);
td = [x(3), x(3)+1+x(4), x(3)+2+x(4)+x(5)]';
bombs = [k*ones(3,1), td, x(6:8)'];
end

function [routes,bombs] = join_plan(cand,a)
routes = zeros(5,2);
bombs = zeros(0,3);
for k = 1:5
    routes(k,:) = cand(k,a(k)).route;
    bombs = [bombs; cand(k,a(k)).bombs]; %#ok<AGROW>
end
end

function [routes,bombs] = join_xs(xs)
routes = zeros(5,2);
bombs = zeros(0,3);
for k = 1:5
    [r,b] = decode_uav(xs{k},k);
    routes(k,:) = r(k,:);
    bombs = [bombs; b]; %#ok<AGROW>
end
end
