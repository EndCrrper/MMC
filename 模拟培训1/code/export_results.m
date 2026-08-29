function export_results()
base_dir = fileparts(mfilename('fullpath'));
root = fullfile(base_dir,'..');
src = fullfile(root,'题目','附件');
out = fullfile(root,'result');
if ~exist(out,'dir'), mkdir(out); end

S = load(fullfile(out,'problem3.mat'));
dst = fullfile(out,'result1.xlsx');
copyfile(fullfile(src,'result1.xlsx'),dst,'f');
A = [repmat(S.routes(1,:),3,1), (1:3)', S.C.drop, S.C.burst, S.single_time];
writematrix(A,dst,'Range','A2');

S = load(fullfile(out,'problem4.mat'));
dst = fullfile(out,'result2.xlsx');
copyfile(fullfile(src,'result2.xlsx'),dst,'f');
A = cell(3,10);
for i = 1:3
    A(i,:) = [{sprintf('FY%d',i)}, num2cell([S.routes(i,:),S.C.drop(i,:), ...
        S.C.burst(i,:),S.single_time(i)])];
end
writecell(A,dst,'Range','A2');

S = load(fullfile(out,'problem5.mat'));
dst = fullfile(out,'result3.xlsx');
copyfile(fullfile(src,'result3.xlsx'),dst,'f');
A = cell(15,12);
for k = 1:5
    rows = (k-1)*3+(1:3);
    A(rows,1) = repmat({sprintf('FY%d',k)},3,1);
    A(rows,4) = num2cell((1:3)');
    id = find(S.bombs(:,1)==k);
    for q = 1:numel(id)
        i = id(q); row = rows(q);
        A(row,:) = [{sprintf('FY%d',k)},num2cell(S.routes(k,:)),{q}, ...
            num2cell(S.C.drop(i,:)),num2cell(S.C.burst(i,:)), ...
            {S.independent_time(i)},{sprintf('M%d',S.primary(i))}];
    end
end
writecell(A,dst,'Range','A2');
end
