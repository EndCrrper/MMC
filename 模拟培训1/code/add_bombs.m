function [b,added] = add_bombs(r,b,D)
added=zeros(0,3);
base=coverage_time(r,b,1:3,D,.04,true);
trial=false;
while size(b,1)<15
    pool=zeros(0,4);
    for k=1:5
        if sum(b(:,1)==k)>=3, continue; end
        tm=sqrt(2*D.u0(k,3)/D.g);
        old=b(b(:,1)==k,2);
        for td=0:2:max(D.T)
            if any(abs(old-td)<1), continue; end
            for tau=0:1:tm
                bb=[b;k td tau];
                C=make_clouds(r,bb,D);
                if ~C.ok || C.tb(end)>max(D.T), continue; end
                sc=coverage_score(r,bb,1:3,D,.2);
                pool(end+1,:)=[k td tau sc]; %#ok<AGROW>
            end
        end
    end
    if isempty(pool), break; end
    [~,ix]=sort(pool(:,4),'descend');
    pool=pool(ix(1:min(12,end)),:);
    best=base; pick=[];
    for i=1:size(pool,1)
        bb=[b;pool(i,1:3)];
        s=coverage_time(r,bb,1:3,D,.04,true);
        if sum(s)>sum(best)+.01 || (sum(s)>=sum(best)-.02 && min(s)>min(best)+.01)
            best=s; pick=pool(i,1:3);
        end
    end
    if isempty(pick)
        if trial, break; end
        pick=pool(1,1:3); trial=true;
    end
    b=[b;pick]; %#ok<AGROW>
    added=[added;pick]; %#ok<AGROW>
    base=best;
    if trial, break; end
end
end
