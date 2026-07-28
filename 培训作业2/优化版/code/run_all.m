%% 古代玻璃成分分析与鉴别 —— 一键运行全部求解脚本
% 2022 CUMCM C题
% 主运行脚本 —— 依次运行数据预处理和四个问题的求解
% 耗时约 2-3 分钟

%% 初始化
clc;
% 注意：不使用 clear，因为子脚本会 save/load 共享数据

% 批处理模式下禁用图形显示
set(0, 'DefaultFigureVisible', 'off');

base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
if ~exist(result_dir, 'dir'), mkdir(result_dir); end

% 脚本列表
script_names = {'preprocess', 'solve_problem1', 'solve_problem2', ...
                'solve_problem3', 'solve_problem4'};
script_labels = {'数据预处理', '问题1：风化关联与统计规律', ...
    '问题2：类型分类与亚类划分', '问题3：未知样本类型鉴别', ...
    '问题4：成分关联与差异分析'};

fprintf('=============================================================\n');
fprintf('2022 CUMCM C题：古代玻璃制品的成分分析与鉴别\n');
fprintf('批量求解 —— 全部四问\n');
fprintf('=============================================================\n');

start_all = tic;

for k = 1:length(script_names)
    name = script_labels{k};
    script_name = script_names{k};

    fprintf('\n');
    fprintf('=============================================================\n');
    fprintf('>>> 运行: %s (%s.m)\n', name, script_name);
    fprintf('=============================================================\n');

    try
        % 使用 run() 函数，效果类似于直接调用脚本名但更明确
        run(script_name);
        fprintf('[OK] %s 完成\n', name);
    catch ME
        fprintf('[FAIL] %s 失败!\n', name);
        fprintf('  错误信息: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  错误位置: %s (第 %d 行)\n', ME.stack(1).name, ME.stack(1).line);
        end
        % 继续运行后续脚本
    end
end

total_time = toc(start_all);
fprintf('\n=============================================================\n');
fprintf('全部完成! 总耗时: %.1fs (%.1f分钟)\n', total_time, total_time/60);
fprintf('输出目录: %s\n', fullfile(base_dir, '..', 'result'));
fprintf('=============================================================\n');
