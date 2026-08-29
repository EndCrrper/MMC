function conv = convergence_check()
base = fileparts(mfilename('fullpath'));
out = fullfile(base,'..','result');
cfg = [24 5;48 9;72 13];
dt = [0.04 0.02 0.01];
conv = cell(5,1);
for p = 1:5
    S = load(fullfile(out,sprintf('problem%d.mat',p)));
    mids = 1; if p==5, mids=1:3; end
    a = zeros(3,3,numel(mids));
    for i = 1:3
        D = data_a(cfg(i,1),cfg(i,2));
        for j = 1:3
            a(i,j,:) = coverage_time(S.routes,S.bombs,mids,D,dt(j),true);
        end
    end
    conv{p} = a;
    fprintf('P%d coarse %.3f fine %.3f\n',p,sum(a(1,1,:)),sum(a(3,3,:)));
end
save(fullfile(out,'convergence.mat'),'conv','cfg','dt');
end
