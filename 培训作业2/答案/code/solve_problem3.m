%% 问题3：未知玻璃样本的类型鉴别
% 2022 CUMCM C题：古代玻璃制品的成分分析与鉴别
% 可独立运行：solve_problem3
%
% 使用问题2训练好的决策树模型，对表单3的8个未知样本（A1-A8）进行类型预测
% 并分析预测结果的敏感性

%% 初始化
clc;  % 不使用clear以保持load/save共享数据
fprintf('=============================================================\n');
fprintf('[3/4] 问题3：未知样本类型鉴别\n');
fprintf('=============================================================\n');

% 路径设置
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');

% 加载预处理数据和决策树模型
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T3_proc', 'X3_clr', 'X3_norm', 'comp_names');
load(fullfile(result_dir, 'decision_tree_models.mat'), ...
    'tree_unweathered', 'tree_weathered', 'tree_all');

fprintf('预处理数据和决策树模型已加载\n');

if ~exist('tree_unweathered', 'var') || ~exist('tree_weathered', 'var')
    error('请先运行 solve_problem2.m 训练决策树模型');
end
has_tree_all = exist('tree_all', 'var') && ~isempty(tree_all);

%% ========== 3.1 类型鉴别 ==========
fprintf('\n========== 3.1 未知样本分类预测 ==========\n');

% 成分标签（与训练时一致）
comp_labels = {'SiO_2', 'Na_2O', 'K_2O', 'CaO', 'MgO', 'Al_2O_3', ...
    'Fe_2O_3', 'CuO', 'PbO', 'BaO', 'P_2O_5', 'SrO', 'SnO_2', 'SO_2'};

% 8个未知样本信息
sample_ids = cellstr(T3_proc.SAMPLE_ID);
weat_status = T3_proc.WEAT_num;  % 0=未风化, 1=风化

fprintf('\n未知样本信息:\n');
fprintf('  %-8s  %-12s  %-10s\n', '样本', '风化状态', '预测类型');
fprintf('  %s\n', repmat('-', 1, 40));

predictions = cell(length(sample_ids), 1);
pred_probs = zeros(length(sample_ids), 2);  % [高钾概率, 铅钡概率]

for i = 1:length(sample_ids)
    xi = X3_norm(i, :);  % 使用归一化数据（与训练数据一致）

    if weat_status(i) == 0
        [pred_label, prob] = predict(tree_unweathered, xi);
        tree_used = '未风化决策树';
    else
        [pred_label, prob] = predict(tree_weathered, xi);
        tree_used = '风化决策树';
    end

    predictions{i} = pred_label;
    pred_probs(i, :) = prob;

    if pred_label == 0
        type_str = '高钾';
    else
        type_str = '铅钡';
    end

    if weat_status(i) == 0
        weat_str = '未风化';
    else
        weat_str = '风化';
    end

    fprintf('  %-8s  %-12s  %-10s  (%.1f%%置信度, %s)\n', ...
        sample_ids{i}, weat_str, type_str, max(prob) * 100, tree_used);
end

% 汇总结果
fprintf('\n===== 3.1 分类结果汇总 =====\n');
fprintf('高钾玻璃: ');
high_k_samples = sample_ids(strcmp(predictions, 0) | cellfun(@(x) x == 0, predictions));
fprintf('%s\n', strjoin(high_k_samples, ', '));
fprintf('铅钡玻璃: ');
pb_samples = sample_ids(strcmp(predictions, 1) | cellfun(@(x) x == 1, predictions));
fprintf('%s\n', strjoin(pb_samples, ', '));

%% ========== 3.2 敏感性分析 ==========
fprintf('\n========== 3.2 敏感性分析 ==========\n');

% 对CLR数据加入扰动，观察预测稳定性
perturbation_levels = [0.01, 0.05, 0.10, 0.20];
n_samples = length(sample_ids);
sensitivity_results = cell(length(perturbation_levels), 1);

rng(456);

for p_idx = 1:length(perturbation_levels)
    delta = perturbation_levels(p_idx);
    fprintf('\n扰动 delta = %.2f:\n', delta);

    n_changed = 0;
    n_trials = 20;  % 每个样本重复20次
    change_matrix = zeros(n_samples, n_trials);

    for trial = 1:n_trials
        noise = delta * randn(size(X3_norm));
        X3_pert = X3_norm + noise;

        for i = 1:n_samples
            if weat_status(i) == 0
                pred_pert = predict(tree_unweathered, X3_pert(i, :));
            else
                pred_pert = predict(tree_weathered, X3_pert(i, :));
            end
            if pred_pert ~= predictions{i}
                change_matrix(i, trial) = 1;
            end
        end
    end

    for i = 1:n_samples
        change_rate = sum(change_matrix(i, :)) / n_trials * 100;
        fprintf('  %s: 变化率=%.1f%% (%d/%d次)\n', ...
            sample_ids{i}, change_rate, sum(change_matrix(i, :)), n_trials);
        if change_rate > 0
            n_changed = n_changed + 1;
        end
    end

    sensitivity_results{p_idx} = struct('delta', delta, ...
        'change_matrix', change_matrix, 'n_trials', n_trials);

    fprintf('  受影响的样本数: %d/%d\n', n_changed, n_samples);
end

% 敏感性结论
fprintf('\n===== 3.2 敏感性结论 =====\n');
fprintf('扰动幅度从0.01到0.20，观察分类结果稳定性。\n');
overall_stable = true;
for p_idx = 1:length(perturbation_levels)
    delta = perturbation_levels(p_idx);
    changes = sum(sensitivity_results{p_idx}.change_matrix, 2);
    if any(changes > 0)
        overall_stable = false;
    end
end
fprintf('结论: %s\n', iif(overall_stable, ...
    '分类结果对数据扰动高度稳定', ...
    '部分样本对较大扰动的响应需关注'));

%% ========== 绘图 ==========
fprintf('\n========== 生成问题3图表 ==========\n');

% 图3.1：未知样本预测置信度
figure('Position', [100, 100, 1100, 500]);
subplot(1, 2, 1);
x_labels = sample_ids;
confidence = max(pred_probs, [], 2) * 100;
b = bar(confidence, 'FaceColor', [0.3 0.6 0.9]);
set(gca, 'XTickLabel', x_labels);
ylabel('预测置信度 (%)'); ylim([0, 110]);
title('问题3.1：未知样本决策树预测置信度', 'FontSize', 13, 'FontWeight', 'bold');
for k = 1:length(confidence)
    text(k, confidence(k) + 2, sprintf('%.0f%%', confidence(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end
grid on;

subplot(1, 2, 2);
% 显示主要成分对比
show_idx = [1, 3, 9, 10];
show_names = comp_names(show_idx);
bar_data = X3_norm(:, show_idx);
bar(bar_data);
set(gca, 'XTickLabel', x_labels);
legend(show_names, 'Location', 'best');
ylabel('归一化含量 (%)');
title('问题3：未知样本主要成分含量', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
saveas(gcf, fullfile(fig_dir, 'p3_prediction_confidence.png'));
print(gcf, fullfile(fig_dir, 'p3_prediction_confidence_300.png'), '-dpng', '-r300');
close(gcf);

% 图3.2：敏感性分析热图
figure('Position', [100, 100, 1200, 500]);
n_rows = length(sample_ids);
change_rate_matrix = zeros(n_rows, length(perturbation_levels));
for p_idx = 1:length(perturbation_levels)
    change_rate_matrix(:, p_idx) = sum(sensitivity_results{p_idx}.change_matrix, 2) / ...
        sensitivity_results{p_idx}.n_trials * 100;
end
imagesc(change_rate_matrix);
colormap(flipud(hot));
colorbar;
set(gca, 'XTick', 1:length(perturbation_levels), ...
    'XTickLabel', arrayfun(@(x) sprintf('δ=%.2f', x), perturbation_levels, 'UniformOutput', false));
set(gca, 'YTick', 1:length(sample_ids), 'YTickLabel', sample_ids);
title('问题3.2：敏感性分析 — 预测变化率(%)', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('扰动幅度'); ylabel('样本');
% 添加文本标注
for i = 1:n_rows
    for j = 1:length(perturbation_levels)
        if change_rate_matrix(i, j) > 0
            text(j, i, sprintf('%.0f', change_rate_matrix(i, j)), ...
                'HorizontalAlignment', 'center', 'Color', 'white', 'FontSize', 8, 'FontWeight', 'bold');
        end
    end
end
saveas(gcf, fullfile(fig_dir, 'p3_sensitivity_heatmap.png'));
print(gcf, fullfile(fig_dir, 'p3_sensitivity_heatmap_300.png'), '-dpng', '-r300');
close(gcf);

%% ========== 模型检验 ==========
fprintf('\n========== 模型检验 ==========\n');

% 检验1：预测结果合理性
fprintf('\n1. 预测合理性检验:\n');
for i = 1:length(sample_ids)
    xi_norm = X3_norm(i, :);
    % 高钾玻璃典型特征：K2O含量高, PbO/BaO含量低
    % 铅钡玻璃典型特征：PbO/BaO含量高, K2O含量低
    K2O = xi_norm(3);
    PbO = xi_norm(9);
    BaO = xi_norm(10);

    if K2O > 5 && PbO < 5 && BaO < 5
        chem_type = '高钾';
    elseif PbO > 10 || BaO > 5
        chem_type = '铅钡';
    else
        chem_type = '不确定';
    end

    pred_type = iif(predictions{i} == 0, '高钾', '铅钡');
    fprintf('  %s: 化学特征→%s, 决策树→%s, %s\n', sample_ids{i}, ...
        chem_type, pred_type, iif(strcmp(chem_type, pred_type), '✓一致', '需关注'));
end

% 保存预测结果
pred_table = table(string(sample_ids), ...
    categorical(cellfun(@(x) iif(x==0, '高钾', '铅钡'), predictions, 'UniformOutput', false)), ...
    pred_probs(:, 1), pred_probs(:, 2), ...
    'VariableNames', {'样本编号', '预测类型', '高钾概率', '铅钡概率'});
writetable(pred_table, fullfile(result_dir, 'problem3_predictions.csv'));
fprintf('\n预测结果已保存: problem3_predictions.csv\n');

fprintf('\n=============================================================\n');
fprintf('问题3完成!\n');
fprintf('=============================================================\n');

%% ==================== 辅助函数 ====================

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
