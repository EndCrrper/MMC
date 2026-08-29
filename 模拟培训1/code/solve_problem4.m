base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir,'..','result');
if ~exist(result_dir,'dir'), mkdir(result_dir); end

D = data_a();
mid = 1;
lb = repmat([0 70 0 0],1,3);
ub = zeros(1,12);
x = zeros(1,12);
for k = 1:3
    q = (k-1)*4+(1:4);
    ub(q) = [360 140 D.T(mid) sqrt(2*D.u0(k,3)/D.g)];
    fk = @(z) cost_seed(z,k,mid,D);
    [x(q),~] = de_search(fk,lb(q),ub(q),46,75,400+k);
end
S2 = load(fullfile(result_dir,'problem2.mat'),'x');
x(1:4) = S2.x;
f = @(z) cost_multi3(z,mid,D,0.05,false);
[x,~] = local_search(f,x,lb,ub,repmat([10 8 2 1],1,3),5);
ff = @(z) cost_multi3(z,mid,D,0.05,true);
[x,~] = local_search(ff,x,lb,ub,repmat([8 6 1 0.7],1,3),3);
[routes,bombs] = decode_multi3(x);
C = make_clouds(routes,bombs,D);
t_center = coverage_time(routes,bombs,mid,D,0.005,false);
t_full = coverage_time(routes,bombs,mid,D,0.01,true);
single_time = zeros(3,1);
for i = 1:3
    single_time(i) = coverage_time(routes,bombs(i,:),mid,D,0.01,true);
end
save(fullfile(result_dir,'problem4.mat'),'x','routes','bombs','C', ...
    't_center','t_full','single_time');
fprintf('P4: %.3f s, full %.3f s\n',t_center,t_full);

function y = cost_seed(x,uav,mid,D)
routes = zeros(5,2);
routes(uav,:) = x(1:2);
bombs = [uav x(3:4)];
C = make_clouds(routes,bombs,D);
if ~C.ok || C.tb>D.T(mid), y = 1e4; return; end
y = -coverage_score(routes,bombs,mid,D,0.1);
end

function y = cost_multi3(x,mid,D,dt,full_target)
[routes,bombs] = decode_multi3(x);
C = make_clouds(routes,bombs,D);
if ~C.ok || any(C.tb > D.T(mid)), y = 1e4; return; end
y = -coverage_time(routes,bombs,mid,D,dt,full_target);
end

function [routes,bombs] = decode_multi3(x)
routes = zeros(5,2);
bombs = zeros(3,3);
for k = 1:3
    q = (k-1)*4+(1:4);
    routes(k,:) = x(q(1:2));
    bombs(k,:) = [k x(q(3:4))];
end
end
