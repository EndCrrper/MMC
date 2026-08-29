base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir,'..','result');
if ~exist(result_dir,'dir'), mkdir(result_dir); end

D = data_a();
routes = zeros(5,2);
routes(1,:) = [180 120];
bombs = [1 1.5 3.6];
C = make_clouds(routes,bombs,D);

t_center = coverage_time(routes,bombs,1,D,0.002,false);
t_full = coverage_time(routes,bombs,1,D,0.01,true);
save(fullfile(result_dir,'problem1.mat'),'routes','bombs','C','t_center','t_full');
fprintf('P1: %.3f s, full %.3f s\n',t_center,t_full);
