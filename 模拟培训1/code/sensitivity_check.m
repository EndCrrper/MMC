function stat = sensitivity_check(n)
if nargin<1, n=100; end
base = fileparts(mfilename('fullpath'));
out = fullfile(base,'..','result');
S = load(fullfile(out,'problem5.mat'));
D = data_a(24,5);
rng(825);

sample = zeros(n,3);
for h = 1:n
    r = S.routes;
    b = S.bombs;
    for k = 1:5
        r(k,1) = mod(r(k,1) + .4*rand-.2,360);
        r(k,2) = min(140,max(70,r(k,2)*(1+.02*rand-.01)));
        id = find(b(:,1)==k);
        shift = .1*rand-.05;
        shift = max(shift,-min(b(id,2)));
        b(id,2) = b(id,2)+shift;
    end
    b(:,3) = max(0,b(:,3)+.1*rand(size(b,1),1)-.05);
    sample(h,:) = coverage_time(r,b,1:3,D,.04,true)';
end

total = sum(sample,2);
stat.base = coverage_time(S.routes,S.bombs,1:3,D,.04,true)';
stat.mean = mean(sample,1);
stat.std = std(sample,0,1);
stat.min = min(sample,[],1);
stat.max = max(sample,[],1);
stat.total = [sum(stat.base),mean(total),std(total),min(total),max(total)];
stat.n = n;
save(fullfile(out,'sensitivity.mat'),'stat','sample');
fprintf('Sensitivity total: base %.3f, mean %.3f, std %.3f, min %.3f\n',stat.total(1:4));
end
