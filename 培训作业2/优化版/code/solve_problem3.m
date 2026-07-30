%% 问题3：未知玻璃文物类型鉴别
% 2022 CUMCM C题：古代玻璃制品的成分分析与鉴别
% 可独立运行：solve_problem3
%
% 方法一：基于问题2的决策树模型（风化/未风化分别预测）
% 方法二：基于问题2的PLS-DA模型（VIP筛选后预测）
% 敏感性分析：对两种方法分别进行扰动测试

%% 初始化
clc;

% 路径设置
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');

% 加载预处理数据和模型
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1_proc', 'T2_proc', 'T3_proc', ...
    'X2_clr', 'X2_norm', 'X3_clr', 'X3_norm', 'X3_raw', ...
    'comp_names');

% 加载决策树模型
load(fullfile(result_dir, 'decision_tree_models.mat'), ...
    'tree_unweathered', 'tree_weathered', 'tree_all');

% 加载PLS-DA模型
load(fullfile(result_dir, 'plsda_vip_results.mat'), ...
    'beta', 'selected', 'VIP', 'idx_sort', 'ncomp');

fprintf('数据与模型加载完成\n');
fprintf('未知样本数: %d\n', height(T3_proc));

% 检查beta维度
fprintf('\n调试信息:\n');
fprintf('  beta维度: %d × %d\n', size(beta, 1), size(beta, 2));
fprintf('  VIP筛选变量数: %d\n', length(selected));
fprintf('  X3_clr维度: %d × %d\n', size(X3_clr, 1), size(X3_clr, 2));

% 成分名称（简化用于显示）
comp_labels = {'SiO_2', 'Na_2O', 'K_2O', 'CaO', 'MgO', 'Al_2O_3', ...
    'Fe_2O_3', 'CuO', 'PbO', 'BaO', 'P_2O_5', 'SrO', 'SnO_2', 'SO_2'};

%%
fprintf('\n%%
fprintf('方法一：决策树分类（风化/未风化分别建模）\n');

% 获取表单3的风化状态
weat3 = T3_proc.WEAT_num;  % 0=未风化, 1=风化

% 决策树使用归一化数据预测
X3_pred = X3_norm;

% 初始化预测结果
y_pred_tree = zeros(height(T3_proc), 1);
y_pred_tree_proba = zeros(height(T3_proc), 2);  % [高钾概率, 铅钡概率]

for i = 1:height(T3_proc)
    sample_name = T3_proc.SAMPLE_ID(i);
    x_i = X3_pred(i, :);
    
    if weat3(i) == 0
        % 未风化样本 → 使用未风化模型
        [label, score] = predict(tree_unweathered, x_i);
        model_used = '未风化决策树';
    else
        % 风化样本 → 使用风化模型
        [label, score] = predict(tree_weathered, x_i);
        model_used = '风化决策树';
    end
    
    y_pred_tree(i) = label;
    
    % 获取两类概率（处理score可能的不同格式）
    score_vec = score(1, :);  % 确保是一维行向量
    if length(score_vec) == 2
        y_pred_tree_proba(i, :) = score_vec;
    elseif length(score_vec) == 1
        % 只有一类的概率
        if label == 0
            y_pred_tree_proba(i, :) = [score_vec, 1 - score_vec];
        else
            y_pred_tree_proba(i, :) = [1 - score_vec, score_vec];
        end
    else
        y_pred_tree_proba(i, :) = [NaN, NaN];
    end
    
    type_name = iif(label == 0, '高钾玻璃', '铅钡玻璃');
    fprintf('  %s (风化=%d): %s (模型: %s)\n', ...
        sample_name, weat3(i), type_name, model_used);
end

% 汇总决策树结果
fprintf('\n--- 决策树预测汇总 ---\n');
fprintf('%-10s %-6s %-10s %-12s %-12s\n', '样本编号', '风化', '预测类型', '高钾概率', '铅钡概率');
fprintf('%-10s %-6s %-10s %-12s %-12s\n', '--------', '----', '--------', '----------', '----------');
for i = 1:height(T3_proc)
    type_name = iif(y_pred_tree(i) == 0, '高钾', '铅钡');
    fprintf('%-10s %-6d %-10s %-12.4f %-12.4f\n', ...
        char(T3_proc.SAMPLE_ID(i)), weat3(i), type_name, ...
        y_pred_tree_proba(i, 1), y_pred_tree_proba(i, 2));
end

%%
fprintf('\n%%
fprintf('方法二：PLS-DA分类\n');

% PLS-DA的beta系数结构：
% beta(1) = 截距项
% beta(2:15) = 14个变量的系数（对应X2_clr的14列）
% 因此预测公式：y = beta(1) + X * beta(2:end)

fprintf('VIP筛选变量 (%d个):\n', length(selected));
for i = 1:length(selected)
    fprintf('  %s (VIP=%.3f, beta系数=%.4f)\n', ...
        comp_labels{selected(i)}, VIP(selected(i)), beta(selected(i)+1));
end

% 方法2a：使用全部14个变量预测（原始PLS-DA模型使用全部变量）
y_pred_pls_full = beta(1) + X3_clr * beta(2:end);
y_pred_pls_full_round = round(max(0, min(1, y_pred_pls_full)));

% 方法2b：仅使用VIP>1的变量预测（重新计算beta）
fprintf('\n--- 仅使用VIP>1变量重新拟合PLS-DA ---\n');
X2_select = X2_clr(:, selected);
y2 = T2_proc.TYPE_num;
ncomp_select = min(ncomp, size(X2_select, 2));
[~, ~, ~, ~, beta_select, ~, ~, ~] = plsregress(X2_select, y2, ncomp_select);
fprintf('简化模型成分数: %d, beta维度: %d × 1\n', ncomp_select, length(beta_select));
X3_select = X3_clr(:, selected);
y_pred_pls_select = beta_select(1) + X3_select * beta_select(2:end);
y_pred_pls_select_round = round(max(0, min(1, y_pred_pls_select)));

% 编码已修正为 高钾→0, 铅钡→1，无需翻转


% 使用简化模型的预测结果作为PLS-DA的最终预测
y_pred_pls_raw = y_pred_pls_select;
y_pred_pls = y_pred_pls_select_round;

fprintf('\n--- PLS-DA预测结果 ---\n');
fprintf('%-10s %-16s %-16s %-10s %-10s\n', ...
    '样本编号', '全模型得分', 'VIP模型得分', '预测类型', '置信度');
fprintf('%-10s %-16s %-16s %-10s %-10s\n', ...
    '--------', '------------', '------------', '--------', '------');
for i = 1:height(T3_proc)
    score_full = y_pred_pls_full(i);
    score_select = y_pred_pls_select(i);
    confidence = abs(score_select - 0.5) * 2;
    type_name = iif(y_pred_pls(i) == 0, '高钾', '铅钡');
    fprintf('%-10s %-16.4f %-16.4f %-10s %-10.4f\n', ...
        char(T3_proc.SAMPLE_ID(i)), score_full, score_select, type_name, confidence);
end

% 检查全模型和VIP模型的一致性
n_agree = sum(y_pred_pls_full_round == y_pred_pls_select_round);
fprintf('\n全模型与VIP简化模型一致性: %d/%d\n', n_agree, height(T3_proc));


%%
fprintf('\n%%
fprintf('两种方法预测结果对比\n');

fprintf('\n%-10s %-6s %-14s %-14s %-10s\n', ...
    '样本编号', '风化', '决策树预测', 'PLS-DA预测', '是否一致');
fprintf('%-10s %-6s %-14s %-14s %-10s\n', ...
    '--------', '----', '----------', '----------', '--------');

n_consistent = 0;
for i = 1:height(T3_proc)
    type_tree = iif(y_pred_tree(i) == 0, '高钾', '铅钡');
    type_pls = iif(y_pred_pls(i) == 0, '高钾', '铅钡');
    consistent = strcmp(type_tree, type_pls);
    if consistent, n_consistent = n_consistent + 1; end
    fprintf('%-10s %-6d %-14s %-14s %-10s\n', ...
        char(T3_proc.SAMPLE_ID(i)), weat3(i), type_tree, type_pls, ...
        iif(consistent, '是', '否'));
end
fprintf('\n两种方法一致率: %d/%d (%.1f%%)\n', ...
    n_consistent, height(T3_proc), 100 * n_consistent / height(T3_proc));

%%
fprintf('\n%%
fprintf('敏感性分析\n');

% 扰动幅度
perturbation = 0.01;
n_trials = 100;
rng(42);

fprintf('扰动幅度: delta=%.2f, 蒙特卡洛次数: %d\n', perturbation, n_trials);

% --- 决策树敏感性 ---
fprintf('\n--- 决策树敏感性 ---\n');
tree_stability = zeros(height(T3_proc), n_trials);

for trial = 1:n_trials
    noise = perturbation * randn(size(X3_norm));
    X3_perturbed = X3_norm + noise;
    
    for i = 1:height(T3_proc)
        if weat3(i) == 0
            label = predict(tree_unweathered, X3_perturbed(i, :));
        else
            label = predict(tree_weathered, X3_perturbed(i, :));
        end
        tree_stability(i, trial) = label;
    end
end

% 计算每个样本的预测稳定性
fprintf('%-10s %-10s %-14s %-10s\n', '样本编号', '原始预测', '稳定率', '评估');
fprintf('%-10s %-10s %-14s %-10s\n', '--------', '--------', '----------', '----');
for i = 1:height(T3_proc)
    orig_label = y_pred_tree(i);
    stable_rate = sum(tree_stability(i, :) == orig_label) / n_trials;
    type_name = iif(orig_label == 0, '高钾', '铅钡');
    stability_eval = iif(stable_rate > 0.95, '非常稳定', ...
        iif(stable_rate > 0.85, '稳定', ...
        iif(stable_rate > 0.70, '一般', '敏感')));
    fprintf('%-10s %-10s %-14.2f %-10s\n', ...
        char(T3_proc.SAMPLE_ID(i)), type_name, stable_rate, stability_eval);
end

% --- PLS-DA敏感性 ---
fprintf('\n--- PLS-DA敏感性 ---\n');
pls_stability = zeros(height(T3_proc), n_trials);

for trial = 1:n_trials
    noise = perturbation * randn(size(X3_select));
    X3_perturbed = X3_select + noise;
    y_pert = round(max(0, min(1, beta_select(1) + X3_perturbed * beta_select(2:end))));
    pls_stability(:, trial) = y_pert;
end

fprintf('%-10s %-10s %-14s %-10s\n', '样本编号', '原始预测', '稳定率', '评估');
fprintf('%-10s %-10s %-14s %-10s\n', '--------', '--------', '----------', '----');
for i = 1:height(T3_proc)
    orig_label = y_pred_pls(i);
    stable_rate = sum(pls_stability(i, :) == orig_label) / n_trials;
    type_name = iif(orig_label == 0, '高钾', '铅钡');
    stability_eval = iif(stable_rate > 0.95, '非常稳定', ...
        iif(stable_rate > 0.85, '稳定', ...
        iif(stable_rate > 0.70, '一般', '敏感')));
    fprintf('%-10s %-10s %-14.2f %-10s\n', ...
        char(T3_proc.SAMPLE_ID(i)), type_name, stable_rate, stability_eval);
end

%%
fprintf('\n%%
fprintf('最终预测结果汇总\n');

% 综合两种方法给出最终预测
fprintf('\n综合两种方法的结果:\n');
fprintf('%-10s %-6s %-14s %-14s %-14s %-20s\n', ...
    '样本编号', '风化', '决策树', 'PLS-DA', '最终预测', '备注');
fprintf('%-10s %-6s %-14s %-14s %-14s %-20s\n', ...
    '--------', '----', '------', '------', '--------', '----');

% 保存结果的结构
prediction_results = table();
prediction_results.SampleID = T3_proc.SAMPLE_ID;
prediction_results.Weathering = weat3;
prediction_results.Tree_Pred = y_pred_tree;
prediction_results.Tree_Prob_HighK = y_pred_tree_proba(:, 1);
prediction_results.Tree_Prob_PbBa = y_pred_tree_proba(:, 2);
prediction_results.PLS_Score = y_pred_pls_raw;
prediction_results.PLS_Pred = y_pred_pls;

final_pred = zeros(height(T3_proc), 1);
final_confidence = zeros(height(T3_proc), 1);

for i = 1:height(T3_proc)
    tree_type = iif(y_pred_tree(i) == 0, '高钾', '铅钡');
    pls_type = iif(y_pred_pls(i) == 0, '高钾', '铅钡');
    
    if strcmp(tree_type, pls_type)
        % 两种方法一致
        final_pred(i) = y_pred_tree(i);
        final_confidence(i) = max(y_pred_tree_proba(i, :));
        note = '一致';
    else
        % 不一致：比较置信度
        tree_conf = max(y_pred_tree_proba(i, :));
        pls_conf = abs(y_pred_pls_raw(i) - 0.5) * 2;
        
        if tree_conf >= pls_conf
            final_pred(i) = y_pred_tree(i);
            final_confidence(i) = tree_conf;
            note = sprintf('不一致，选决策树(%.2f>%.2f)', tree_conf, pls_conf);
        else
            final_pred(i) = y_pred_pls(i);
            final_confidence(i) = pls_conf;
            note = sprintf('不一致，选PLS-DA(%.2f>%.2f)', pls_conf, tree_conf);
        end
    end
    
    final_type = iif(final_pred(i) == 0, '高钾', '铅钡');
    fprintf('%-10s %-6d %-14s %-14s %-14s %-20s\n', ...
        char(T3_proc.SAMPLE_ID(i)), weat3(i), tree_type, pls_type, ...
        final_type, note);
end

prediction_results.Final_Pred = final_pred;
prediction_results.Final_Confidence = final_confidence;

%%
fprintf('\n%%

% 图3.1：两种方法预测概率对比
figure('Position', [100, 100, 1200, 500]);

subplot(1, 2, 1);
% 决策树：高钾概率
bar_data_tree = y_pred_tree_proba(:, 1);
b1 = bar(1:height(T3_proc), bar_data_tree);
set(gca, 'XTick', 1:height(T3_proc), 'XTickLabel', cellstr(T3_proc.SAMPLE_ID));
ylabel('高钾概率'); ylim([0, 1]);
title('决策树预测', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(1, 2, 2);
% PLS-DA：得分
bar_data_pls = y_pred_pls_raw;
b2 = bar(1:height(T3_proc), bar_data_pls);
set(gca, 'XTick', 1:height(T3_proc), 'XTickLabel', cellstr(T3_proc.SAMPLE_ID));
ylabel('PLS-DA得分'); ylim([0, 1]);
title('PLS-DA预测', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

sgtitle('问题3：两种方法预测结果对比', 'FontSize', 14, 'FontWeight', 'bold');
print(gcf, fullfile(fig_dir, 'p3_prediction_comparison_300.png'), '-dpng', '-r300');
close(gcf);

% 图3.2：敏感性分析-稳定率
figure('Position', [100, 100, 1000, 500]);

subplot(1, 2, 1);
tree_stable_rate = zeros(height(T3_proc), 1);
for i = 1:height(T3_proc)
    tree_stable_rate(i) = sum(tree_stability(i, :) == y_pred_tree(i)) / n_trials;
end
barh(tree_stable_rate, 'FaceColor', [0.3 0.6 0.9]);
set(gca, 'YTick', 1:height(T3_proc), 'YTickLabel', cellstr(T3_proc.SAMPLE_ID));
xlabel('稳定率'); xlim([0, 1]);
title('决策树：扰动敏感性', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(1, 2, 2);
pls_stable_rate = zeros(height(T3_proc), 1);
for i = 1:height(T3_proc)
    pls_stable_rate(i) = sum(pls_stability(i, :) == y_pred_pls(i)) / n_trials;
end
barh(pls_stable_rate, 'FaceColor', [0.9 0.4 0.3]);
set(gca, 'YTick', 1:height(T3_proc), 'YTickLabel', cellstr(T3_proc.SAMPLE_ID));
xlabel('稳定率'); xlim([0, 1]);
title('PLS-DA：扰动敏感性', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

sgtitle('问题3：敏感性分析（蒙特卡洛100次，δ=0.01）', 'FontSize', 14, 'FontWeight', 'bold');
close(gcf);

% 图3.3：最终预测结果
figure('Position', [100, 100, 800, 500]);
final_colors = zeros(height(T3_proc), 3);
for i = 1:height(T3_proc)
    if final_pred(i) == 0
        final_colors(i, :) = [0.3 0.6 0.9];  % 蓝色-高钾
    else
        final_colors(i, :) = [0.9 0.4 0.3];  % 红色-铅钡
    end
end
b3 = bar(1:height(T3_proc), final_confidence, 'FaceColor', 'flat');
b3.CData = final_colors;
set(gca, 'XTick', 1:height(T3_proc), 'XTickLabel', cellstr(T3_proc.SAMPLE_ID));
ylabel('置信度'); ylim([0, 1.1]);
title('问题3：最终预测置信度（蓝=高钾，红=铅钡）', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
% 添加标签
for i = 1:height(T3_proc)
    type_name = iif(final_pred(i) == 0, '高钾', '铅钡');
    text(i, final_confidence(i) + 0.03, type_name, ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end
close(gcf);

%%
fprintf('\n--- 保存预测结果 ---\n');

% 保存MAT文件
save(fullfile(result_dir, 'problem3_results.mat'), ...
    'y_pred_tree', 'y_pred_tree_proba', 'y_pred_pls', 'y_pred_pls_raw', ...
    'final_pred', 'final_confidence', 'prediction_results', ...
    'tree_stability', 'pls_stability', 'tree_stable_rate', 'pls_stable_rate');

% 保存CSV文件
type_tree_str = cell(height(T3_proc), 1);
type_pls_str = cell(height(T3_proc), 1);
type_final_str = cell(height(T3_proc), 1);
for i = 1:height(T3_proc)
    type_tree_str{i} = iif(y_pred_tree(i) == 0, '高钾', '铅钡');
    type_pls_str{i} = iif(y_pred_pls(i) == 0, '高钾', '铅钡');
    type_final_str{i} = iif(final_pred(i) == 0, '高钾', '铅钡');
end

prediction_results_csv = table(T3_proc.SAMPLE_ID, weat3, ...
    type_tree_str, type_pls_str, type_final_str, ...
    'VariableNames', {'样本编号', '风化状态', '决策树预测', 'PLSDA预测', '最终预测'});
writetable(prediction_results_csv, fullfile(result_dir, 'form3_predictions.csv'));
fprintf('预测结果已保存到: %s\n', fullfile(result_dir, 'form3_predictions.csv'));

fprintf('\n%%
fprintf('问题3完成!\n');

%%
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end