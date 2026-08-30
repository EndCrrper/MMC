function report = validate_results()
base = fileparts(mfilename('fullpath'));
out = fullfile(base,'..','result');
report = struct([]);
Dfine = data_a(48,9);

for p = 1:5
    S = load(fullfile(out,sprintf('problem%d.mat',p)));
    v = S.routes(:,2); v = v(v>0);
    gaps = inf;
    for k = unique(S.bombs(:,1))'
        td = sort(S.bombs(S.bombs(:,1)==k,2));
        if numel(td)>1, gaps = min(gaps,min(diff(td))); end
    end
    if isinf(gaps), gaps = nan; end
    mids = 1;
    if p==5, mids=1:3; end
    fine = coverage_time(S.routes,S.bombs,mids,Dfine,0.01,true);
    marginal = zeros(size(S.bombs,1),numel(mids));
    for i = 1:size(S.bombs,1)
        keep = true(size(S.bombs,1),1); keep(i)=false;
        marginal(i,:) = fine' - coverage_time(S.routes,S.bombs(keep,:),mids,Dfine,0.01,true)';
    end
    report(p).speed = [min(v),max(v)];
    report(p).min_height = min(S.C.burst(:,3));
    report(p).min_gap = gaps;
    report(p).fine_time = fine;
    report(p).marginal = marginal;
    report(p).valid = S.C.ok && all(v>=70 & v<=140) && ...
        (isnan(gaps) || gaps>=1-1e-8);
end

save(fullfile(out,'validation.mat'),'report');
for p = 1:5
    fprintf('P%d valid=%d fine=',p,report(p).valid);
    fprintf('%.3f ',report(p).fine_time);
    fprintf('marginal>0: %d/%d\n',sum(any(report(p).marginal>1e-6,2)),size(report(p).marginal,1));
end
end
