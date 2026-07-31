%% 问题1：风化关联分析与化学成分统计规律
% 2022 CUMCM C题：古代玻璃制品的成分分析与鉴别
% 可独立运行：solve_problem1
%
% 子问题：
%   1.1 风化与类型/纹饰/颜色的关联性 —— RC交叉表 + 卡方检验
%   1.2 化学成分统计规律 —— CLR变换后描述性统计 + 箱线图
%   1.3 预测风化前化学成分 —— 总体抽样预测 + CLR逆变换

%% 初始化
clc;  % 不使用clear以保持load/save共享数据

% 路径设置
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');

% 加载预处理数据
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1_proc', 'T2_merged', 'X2_clr', 'X2_norm', 'X2_raw', 'comp_names', 'T2_proc');
fprintf('预处理数据已加载\n');

%% 1.1 风化与类型/纹饰/颜色的关联性分析 %%
fprintf('\n%%\n');

% 构建列联表
% 风化 vs 类型
CT_weat_type = crosstab(T1_proc.WEAT_num, T1_proc.TYPE_num);
% 风化 vs 纹饰
CT_weat_orna = crosstab(T1_proc.WEAT_num, T1_proc.ORNA_num);
% 风化 vs 颜色
CT_weat_color = crosstab(T1_proc.WEAT_num, T1_proc.COLOR_num);

fprintf('\n风化 vs 类型 列联表:\n');
disp(CT_weat_type);
fprintf('风化 vs 纹饰 列联表:\n');
disp(CT_weat_orna);
fprintf('风化 vs 颜色 列联表:\n');
disp(CT_weat_color);

% 卡方检验（根据条件自动选择Pearson/Yates/Fisher）
fprintf('\n--- 风化 vs 类型 检验 ---\n');
[stat_WT, p_WT, method_WT] = chi2test(CT_weat_type);
fprintf('%s: 统计量=%.4f, p值=%.4f\n', method_WT, stat_WT, p_WT);

fprintf('\n--- 风化 vs 纹饰 检验 ---\n');
[stat_WO, p_WO, method_WO] = chi2test(CT_weat_orna);
fprintf('%s: 统计量=%.4f, p值=%.4f\n', method_WO, stat_WO, p_WO);

fprintf('\n--- 风化 vs 颜色 检验 ---\n');
[stat_WC, p_WC, method_WC] = chi2test(CT_weat_color);
fprintf('%s: 统计量=%.4f, p值=%.4f\n', method_WC, stat_WC, p_WC);

% 结论
fprintf('\n%%\n');
alpha = 0.05;
if p_WT < alpha
    fprintf('风化与玻璃类型显著相关 (p=%.4f < 0.05)\n', p_WT);
else
    fprintf('风化与玻璃类型无显著相关 (p=%.4f >= 0.05)\n', p_WT);
end
if p_WO < alpha
    fprintf('风化与纹饰显著相关 (p=%.4f < 0.05)\n', p_WO);
else
    fprintf('风化与纹饰无显著相关 (p=%.4f >= 0.05)\n', p_WO);
end
if p_WC < alpha
    fprintf('风化与颜色显著相关 (p=%.4f < 0.05)\n', p_WC);
else
    fprintf('风化与颜色无显著相关 (p=%.4f >= 0.05)\n', p_WC);
end

%% 1.2 化学成分统计规律 %%
fprintf('\n%%\n');

% 将数据按类型+风化为四组
groups = {
    '高钾-无风化', T2_proc.TYPE_num == 0 & T2_proc.WEAT_num == 0;
    '高钾-风化',   T2_proc.TYPE_num == 0 & T2_proc.WEAT_num == 1;
    '铅钡-无风化', T2_proc.TYPE_num == 1 & T2_proc.WEAT_num == 0;
    '铅钡-风化',   T2_proc.TYPE_num == 1 & T2_proc.WEAT_num == 1;
};

fprintf('\n各组样本量:\n');
for g = 1:4
    fprintf('  %s: %d\n', groups{g, 1}, sum(groups{g, 2}));
end

% 对每组计算统计量（CLR变换后的数据）
stat_names = {'均值', '最小值', '最大值', '标准差', '变异系数(%)', '偏度', '峰度'};
all_stats = cell(4, 1);

for g = 1:4
    idx = groups{g, 2};
    if sum(idx) == 0
        fprintf('\n%s: 无样本\n', groups{g, 1});
        continue;
    end
    Xg = X2_clr(idx, :);
    [avg_g, min_g, max_g, std_g, cv_g, skew_g, kurt_g] = StatAll(Xg);

    fprintf('\n【%s】(n=%d)\n', groups{g, 1}, sum(idx));
    fprintf('  %-12s', '成分');
    for s = 1:length(stat_names)
        fprintf('%10s', stat_names{s});
    end
    fprintf('\n');
    for j = 1:length(comp_names)
        fprintf('  %-12s%10.3f%10.3f%10.3f%10.3f%10.1f%10.3f%10.3f\n', ...
            comp_names{j}, avg_g(j), min_g(j), max_g(j), std_g(j), ...
            cv_g(j), skew_g(j), kurt_g(j));
    end
    all_stats{g} = struct('avg', avg_g, 'min', min_g, 'max', max_g, ...
        'std', std_g, 'cv', cv_g, 'skew', skew_g, 'kurt', kurt_g);
end

%% 1.3 预测风化前化学成分 %%
fprintf('\n%%\n');

% 总体抽样预测模型：
% 假设未风化数据 ~ N(mu_X, sigma_X^2), 风化数据 ~ N(mu_Y, sigma_Y^2)
% 预测公式: Pred = mu_X + (sigma_X/sigma_Y) * (Y - mu_Y)
% 使用高钾组进行预测（样本量较大，有配对逻辑）

% 按类型分别进行预测
pred_results = struct();

for type_idx = 0:1
    if type_idx == 0
        type_name = '高钾';
    else
        type_name = '铅钡';
    end

    % 风化样本
    weat_idx = T2_proc.TYPE_num == type_idx & T2_proc.WEAT_num == 1;
    % 未风化样本
    unweat_idx = T2_proc.TYPE_num == type_idx & T2_proc.WEAT_num == 0;

    if sum(weat_idx) == 0 || sum(unweat_idx) == 0
        fprintf('%s: 缺乏风化/未风化配对样本，跳过\n', type_name);
        continue;
    end

    X_weat = X2_clr(weat_idx, :);
    X_unweat = X2_clr(unweat_idx, :);

    mu_X = mean(X_unweat, 1);   % 未风化组均值
    sigma_X = std(X_unweat, 0, 1);  % 未风化组标准差
    mu_Y = mean(X_weat, 1);     % 风化组均值
    sigma_Y = std(X_weat, 0, 1);    % 风化组标准差

    % 预测每个风化样本的风化前CLR值
    n_weat = sum(weat_idx);
    Y_weat = X2_clr(weat_idx, :);
    Pred_clr = zeros(n_weat, size(X2_clr, 2));

    for i = 1:n_weat
        for j = 1:size(X2_clr, 2)
            if sigma_Y(j) > eps
                Pred_clr(i, j) = mu_X(j) + (sigma_X(j) / sigma_Y(j)) * (Y_weat(i, j) - mu_Y(j));
            else
                Pred_clr(i, j) = mu_X(j);
            end
        end
    end

    % CLR逆变换 → 归一化百分比
    % z_i = log(x_i / g(x)) → x_i = exp(z_i) * g(x)
    % 约束: sum(x_i) = 100
    Pred_norm = zeros(size(Pred_clr));
    for i = 1:n_weat
        exp_z = exp(Pred_clr(i, :));
        Pred_norm(i, :) = 100 * exp_z / sum(exp_z);
    end

    fprintf('\n%s 风化前成分预测（均值）:\n', type_name);
    fprintf('  %-12s  %10s  %10s  %10s\n', '成分', '风化后', '预测风化前', '变化');
    Y_mean = mean(Y_weat, 1);
    Pred_mean = mean(Pred_norm, 1);

    % 选取主要成分展示
    show_idx = [1, 3, 9, 10];  % SiO2, K2O, PbO, BaO
    for j = show_idx
        fprintf('  %-12s  %10.3f  %10.3f  %10.3f\n', ...
            comp_names{j}, Y_mean(j), Pred_mean(j), Pred_mean(j) - Y_mean(j));
    end

    pred_results.(genvarname(type_name)) = struct(...
        'Pred_clr', Pred_clr, 'Pred_norm', Pred_norm, ...
        'weat_idx', weat_idx, 'unweat_idx', unweat_idx);
end

%% 绘图 %%
fprintf('\n%%\n');

% 图1.1：风化关联性卡方检验结果柱状图
figure('Position', [100, 100, 1000, 500]);
p_values = [p_WT, p_WO, p_WC];
bar(p_values, 'FaceColor', [0.3 0.6 0.9]);
hold on;
yline(0.05, 'r--', 'LineWidth', 2);
yline(0.01, 'r:', 'LineWidth', 1.5);
set(gca, 'XTickLabel', {'风化-类型', '风化-纹饰', '风化-颜色'});
ylabel('p值'); title('问题1.1：风化关联性检验 p值', 'FontSize', 14, 'FontWeight', 'bold');
legend('p值', '\alpha=0.05', '\alpha=0.01', 'Location', 'northwest');
text(1:3, p_values + 0.02, arrayfun(@(x) sprintf('p=%.4f', x), p_values, 'UniformOutput', false), ...
    'HorizontalAlignment', 'center', 'FontSize', 11);
grid on;
print(gcf, fullfile(fig_dir, 'p1_chi2_results_300.png'), '-dpng', '-r300');
close(gcf);

% 图1.2：四组统计规律箱线图（CLR空间）
figure('Position', [100, 100, 1800, 900]);
% 手动调小4个子图，为顶部总标题留出充足空间
% [left, bottom, width, height] — 4个子图的归一化位置
subplot_positions = { ...
    [0.05, 0.12, 0.21, 0.72]; ...  % 子图1：高钾-无风化
    [0.27, 0.12, 0.21, 0.72]; ...  % 子图2：高钾-风化
    [0.49, 0.12, 0.21, 0.72]; ...  % 子图3：铅钡-无风化
    [0.71, 0.12, 0.21, 0.72]};     % 子图4：铅钡-风化
for g = 1:4
    subplot('Position', subplot_positions{g});
    idx = groups{g, 2};
    if sum(idx) > 0
        boxplot(X2_clr(idx, :), 'Labels', comp_names);
        title(groups{g, 1}, 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('CLR值'); xlabel('化学成分');
        xtickangle(45);
        grid on;
    end
end
annotation('textbox', [0.1, 0.90, 0.8, 0.06], ...
    'String', '问题1.2：四组玻璃化学成分CLR分布', ...
    'FontSize', 14, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', ...
    'EdgeColor', 'none');
print(gcf, fullfile(fig_dir, 'p1_four_groups_boxplot_300.png'), '-dpng', '-r300');
close(gcf);

% 图1.3：风化前后成分对比（高钾组主要成分）
figure('Position', [100, 100, 1200, 600]);
subplot(1, 2, 1);
if sum(T2_proc.TYPE_num == 0 & T2_proc.WEAT_num == 1) > 0
    hiK_weat_mean = mean(X2_norm(T2_proc.TYPE_num == 0 & T2_proc.WEAT_num == 1, :), 1);
    hiK_unweat_mean = mean(X2_norm(T2_proc.TYPE_num == 0 & T2_proc.WEAT_num == 0, :), 1);
    X_comp = categorical(comp_names);
    X_comp = reordercats(X_comp, comp_names);
    bar(X_comp, [hiK_unweat_mean; hiK_weat_mean]');
    legend('未风化', '风化', 'Location', 'best');
    title('高钾玻璃：风化成份对比（归一化%）', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('含量 (%)'); xtickangle(45); grid on;
end

subplot(1, 2, 2);
if sum(T2_proc.TYPE_num == 1 & T2_proc.WEAT_num == 1) > 0
    pb_weat_mean = mean(X2_norm(T2_proc.TYPE_num == 1 & T2_proc.WEAT_num == 1, :), 1);
    pb_unweat_mean = mean(X2_norm(T2_proc.TYPE_num == 1 & T2_proc.WEAT_num == 0, :), 1);
    X_comp = categorical(comp_names);
    X_comp = reordercats(X_comp, comp_names);
    bar(X_comp, [pb_unweat_mean; pb_weat_mean]');
    legend('未风化', '风化', 'Location', 'best');
    title('铅钡玻璃：风化成份对比（归一化%）', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('含量 (%)'); xtickangle(45); grid on;
end
sgtitle('问题1.3：风化前后成分对比', 'FontSize', 14, 'FontWeight', 'bold');
close(gcf);

%% 模型检验 %%
fprintf('\n%%\n');

% 检验1：卡方检验适用条件验证
fprintf('\n1. 卡方检验适用条件验证:\n');
fprintf('  风化-类型: 总样本%d, 最小期望频数将在代码中输出\n', sum(CT_weat_type(:)));
check_chi2_condition(CT_weat_type);
fprintf('  风化-纹饰: 总样本%d\n', sum(CT_weat_orna(:)));
check_chi2_condition(CT_weat_orna);
fprintf('  风化-颜色: 总样本%d\n', sum(CT_weat_color(:)));
check_chi2_condition(CT_weat_color);

% 检验2：预测模型的合理性
fprintf('\n2. 预测模型合理性验证:\n');
fprintf('  采用正态假设下的总体抽样预测，关键假设:\n');
fprintf('  (a) 成分数据经CLR变换后服从正态分布\n');
fprintf('  (b) 同类型玻璃的风化/未风化总体具有相同的变异模式\n');
fprintf('  (c) 风化前后成分变化满足线性关系\n');

% 对CLR变换数据进行正态性检验（偏度/峰度检查）
for g_idx = 1:4
    idx = groups{g_idx, 2};
    if sum(idx) >= 5
        Xg = X2_clr(idx, :);
        skew_vals = skewness(Xg, 0);
        kurt_vals = kurtosis(Xg, 0);
        n_abnormal = sum(abs(skew_vals) > 2 | abs(kurt_vals) > 7);
        fprintf('  %s: %d/%d 成分满足正态近似\n', groups{g_idx, 1}, ...
            length(comp_names) - n_abnormal, length(comp_names));
    end
end

fprintf('\n%%\n');
fprintf('问题1完成!\n');

%%

function [stat, pval, method] = chi2test(CT)
    % 根据卡方检验适用条件自动选择检验方法
    N = sum(CT(:));
    [nr, nc] = size(CT);
    % 计算期望频数
    row_sum = sum(CT, 2);
    col_sum = sum(CT, 1);
    expected = row_sum * col_sum / N;
    min_expected = min(expected(:));

    if N >= 40 && min_expected >= 5
        % Pearson卡方检验
        chi2 = sum((CT(:) - expected(:)).^2 ./ expected(:));
        df = (nr - 1) * (nc - 1);
        pval = 1 - chi2cdf(chi2, df);
        stat = chi2;
        method = 'Pearson卡方检验';
    elseif N >= 40 && min_expected >= 1
        % Yates校正卡方检验
        chi2_yates = sum((abs(CT(:) - expected(:)) - 0.5).^2 ./ expected(:));
        df = (nr - 1) * (nc - 1);
        pval = 1 - chi2cdf(chi2_yates, df);
        stat = chi2_yates;
        method = 'Yates校正卡方检验';
    else
        % Fisher确切检验：仅适用2x2表
        if nr == 2 && nc == 2
            [~, pval, stats] = fishertest(CT);
            stat = stats.OddsRatio;
            method = 'Fisher确切检验';
        else
            % 大表格用模拟p值（Monte Carlo）
            chi2 = sum((CT(:) - expected(:)).^2 ./ expected(:));
            df = (nr - 1) * (nc - 1);
            % 使用随机模拟估计p值
            n_sim = 10000;
            chi2_sim = zeros(n_sim, 1);
            for s = 1:n_sim
                CT_sim = reshape(random('Poisson', expected(:)), nr, nc);
                exp_sim = sum(CT_sim, 2) * sum(CT_sim, 1) / sum(CT_sim(:));
                chi2_sim(s) = sum((CT_sim(:) - exp_sim(:)).^2 ./ max(exp_sim(:), eps));
            end
            pval = sum(chi2_sim >= chi2) / n_sim;
            stat = chi2;
            method = sprintf('MonteCarlo模拟(基于卡方, N=%d)', n_sim);
        end
    end
end

function [avg, minv, maxv, stdv, cv, skewv, kurtv] = StatAll(A)
    % 提取矩阵A各列的统计规律
    avg = mean(A, 1);
    minv = min(A, [], 1);
    maxv = max(A, [], 1);
    stdv = std(A, 0, 1);
    cv = 100 * stdv ./ abs(avg);  % 变异系数(%)
    skewv = skewness(A, 0);
    kurtv = kurtosis(A, 0);
end

function check_chi2_condition(CT)
    % 检查卡方检验适用条件
    N = sum(CT(:));
    row_sum = sum(CT, 2);
    col_sum = sum(CT, 1);
    expected = row_sum * col_sum / N;
    min_exp = min(expected(:));
    fprintf('    总样本N=%d, 最小期望频数Tmin=%.2f\n', N, min_exp);
    if N >= 40 && min_exp >= 5
        fprintf('    → 适用Pearson卡方检验\n');
    elseif N >= 40 && min_exp >= 1
        fprintf('    → 适用Yates校正卡方检验\n');
    else
        fprintf('    → 适用Fisher确切检验\n');
    end
end
