base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir,'..','result');
if ~exist(result_dir,'dir'), mkdir(result_dir); end

D = data_a();
uav = 1; mid = 1;
tau_max = sqrt(2*D.u0(uav,3)/D.g);
lb = [0 70 0 0];
ub = [360 140 D.T(mid) tau_max];
f = @(x) cost_one(x,uav,mid,D,0.05,false);
[x,~] = de_search(f,lb,ub,44,65,102);
ff = @(z) cost_one(z,uav,mid,D,0.03,true);
[x,~] = local_search(ff,x,lb,ub,[8 6 1 0.8],5);
[routes,bombs] = decode_one(x,uav);
C = make_clouds(routes,bombs,D);
t_center = coverage_time(routes,bombs,mid,D,0.005,false);
t_full = coverage_time(routes,bombs,mid,D,0.01,true);
save(fullfile(result_dir,'problem2.mat'),'x','routes','bombs','C','t_center','t_full');
fprintf('P2: %.3f s, full %.3f s\n',t_center,t_full);

function y = cost_one(x,uav,mid,D,dt,full_target)
[routes,bombs] = decode_one(x,uav);
C = make_clouds(routes,bombs,D);
if ~C.ok || C.tb > D.T(mid), y = 1e4; return; end
y = -coverage_time(routes,bombs,mid,D,dt,full_target);
end

function [routes,bombs] = decode_one(x,uav)
routes = zeros(5,2);
routes(uav,:) = x(1:2);
bombs = [uav x(3) x(4)];
end
