base = fileparts(mfilename('fullpath'));
out = fullfile(base,'..','result');
if ~exist(out,'dir'), mkdir(out); end

D = data_a();
lb = [0 70 0 0 0 0 0 0];
tm = sqrt(2*D.u0(1,3)/D.g);
ub = [360 140 35 15 15 tm tm tm];
ub_wide = [360 140 D.T(1)-2 D.T(1)-2 D.T(1)-2 tm tm tm];

x_total = search_plan(false,lb,ub,D,203:207);
x_even = search_plan(true,lb,ub,D,303:305);
x_wide = search_plan(false,lb,ub_wide,D,403:405);
[~,~,~,t1,s1] = assess(x_total,D);
[~,~,~,t2,s2] = assess(x_even,D);
[~,~,~,t3,s3] = assess(x_wide,D);
x = x_total;
if t3>t1 || (t3>=t1-.05 && min(s3)>min(s1)), x=x_wide; t1=t3; s1=s3; end
if t2>=t1-.05 && min(s2)>min(s1), x=x_even; end

[routes,bombs,C,t_full,single_time,t_center,marginal_time] = assess(x,D);
save(fullfile(out,'problem3.mat'),'x','x_total','x_even','x_wide','routes','bombs', ...
    'C','t_center','t_full','single_time','marginal_time');
fprintf('P3: %.3f s, full %.3f s\n',t_center,t_full);

function x = search_plan(even,lb,ub,D,seeds)
f = @(z) score_cost(z,D,even);
[x,best] = de_search(f,lb,ub,56,90,seeds(1));
for seed = seeds(2:end)
    [z,fz] = de_search(f,lb,ub,56,90,seed);
    if fz<best, x=z; best=fz; end
end
g = @(z) exact_cost(z,D,false);
[x,~] = local_search(g,x,lb,ub,[8 6 1 1 1 .7 .7 .7],5);
h = @(z) exact_cost(z,D,true);
[x,~] = local_search(h,x,lb,ub,[8 6 1 1 1 .7 .7 .7],4);
end

function y = score_cost(x,D,even)
[r,b] = decode(x);
C = make_clouds(r,b,D);
if ~C.ok || any(C.tb>D.T(1)), y=1e4; return; end
s = coverage_score(r,b,1,D,.1);
if even
    one=zeros(3,1);
    for i=1:3, one(i)=coverage_score(r,b(i,:),1,D,.1); end
    s=s+.25*sum(one)+.15*min(one);
end
y=-s;
end

function y = exact_cost(x,D,full)
[r,b] = decode(x);
C = make_clouds(r,b,D);
if ~C.ok || any(C.tb>D.T(1)), y=1e4; return; end
y=-coverage_time(r,b,1,D,.04,full);
end

function [r,b,C,tf,one,tc,gain] = assess(x,D)
[r,b] = decode(x);
C = make_clouds(r,b,D);
tc = coverage_time(r,b,1,D,.005,false);
tf = coverage_time(r,b,1,D,.01,true);
one=zeros(3,1); gain=zeros(3,1);
for i=1:3
    one(i)=coverage_time(r,b(i,:),1,D,.01,true);
    keep=true(3,1); keep(i)=false;
    gain(i)=tf-coverage_time(r,b(keep,:),1,D,.01,true);
end
end

function [r,b] = decode(x)
r=zeros(5,2); r(1,:)=x(1:2);
td=[x(3),x(3)+1+x(4),x(3)+2+x(4)+x(5)]';
b=[ones(3,1),td,x(6:8)'];
end
