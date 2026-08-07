%% 蔬菜商品自动定价与补货决策 —— 一键运行全部
% 2023 CUMCM C题
% 依次运行：预处理 → 问题1 → 问题2 → 问题3 → 问题4

%% 初始化
clc;
set(0, 'DefaultFigureVisible', 'off');

base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
if ~exist(result_dir, 'dir'), mkdir(result_dir); end

scripts = {'preprocess', 'solve_problem1', 'solve_problem2', ...
           'solve_problem3', 'solve_problem4'};
labels = {'数据预处理', '问题1：品类分布与关联', ...
    '问题2：销量预测与定价优化', '问题3：选品约束优化', ...
    '问题4：数据采集建议'};

fprintf('=============================================================\n');
fprintf('2023 CUMCM C题：蔬菜商品自动定价与补货决策\n');
fprintf('批量求解 —— 全部四问\n');
fprintf('=============================================================\n');

start_all = tic;

for k = 1:length(scripts)
    fprintf('\n=============================================================\n');
    fprintf('>>> 运行: %s (%s.m)\n', labels{k}, scripts{k});
    fprintf('=============================================================\n');

    try
        run(scripts{k});
        fprintf('[OK] %s 完成\n', labels{k});
    catch ME
        fprintf('[FAIL] %s 失败!\n', labels{k});
        fprintf('  错误: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  位置: %s (第 %d 行)\n', ME.stack(1).name, ME.stack(1).line);
        end
    end
end

total_time = toc(start_all);
fprintf('\n=============================================================\n');
fprintf('全部完成! 总耗时: %.1fs (%.1f分钟)\n', total_time, total_time/60);
fprintf('输出目录: %s\n', result_dir);
fprintf('=============================================================\n');
