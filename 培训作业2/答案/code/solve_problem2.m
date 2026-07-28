%% 问题2：玻璃类型分类规律与亚类划分
% 2022 CUMCM C题：古代玻璃制品的成分分析与鉴别
% 可独立运行：solve_problem2
%
% 子问题：
%   2.1 高钾/铅钡类型分类 —— 自适应决策树（风化/未风化分别建模）
%   2.2 亚类划分 —— 层次聚类（Q型+R型）
%   2.3 分类合理性验证 —— 敏感性分析（微小扰动）

%% 初始化
clc;  % 不使用clear以保持load/save共享数据
fprintf('=============================================================\n');
fprintf('[2/4] 问题2：类型分类与亚类划分\n');
fprintf('=============================================================\n');

% 路径设置
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');

% 加载预处理数据
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1_proc', 'T2_merged', 'X2_clr', 'X2_norm', 'X2_raw', 'comp_names', 'T2_proc');
fprintf('预处理数据已加载\n');

% 成分名称（简化用于显示）
comp_labels = {'SiO_2', 'Na_2O', 'K_2O', 'CaO', 'MgO', 'Al_2O_3', ...
    'Fe_2O_3', 'CuO', 'PbO', 'BaO', 'P_2O_5', 'SrO', 'SnO_2', 'SO_2'};

%% ========== 2.1 决策树分类：高钾 vs 铅钡 ==========
fprintf('\n========== 2.1 决策树分类 ==========\n');

% 分别对未风化和风化样本建立决策树
rng(42);  % 固定随机种子

for weat_state = 0:1
    if weat_state == 0
        state_name = '未风化';
    else
        state_name = '风化';
    end

    fprintf('\n--- %s样本决策树 ---\n', state_name);

    % 筛选对应风化状态的样本
    idx = T2_proc.WEAT_num == weat_state;
    X = X2_norm(idx, :);  % 使用归一化数据（保留成分绝对丰度信号）
    y = T2_proc.TYPE_num(idx);

    if length(unique(y)) < 2
        fprintf('%s样本仅有一类，跳过\n', state_name);
        continue;
    end

    % 划分训练/测试集
    n = size(X, 1);
    cv = cvpartition(y, 'Holdout', 0.25);
    X_train = X(training(cv), :);
    y_train = y(training(cv), :);
    X_test = X(test(cv), :);
    y_test = y(test(cv), :);

    fprintf('样本量: 训练%d, 测试%d\n', sum(training(cv)), sum(test(cv)));
    fprintf('类别分布: 高钾=%d, 铅钡=%d\n', sum(y==0), sum(y==1));

    % 自适应超参数优化的决策树
    fprintf('正在优化决策树超参数...\n');
    tree_model = fitctree(X_train, y_train, ...
        'PredictorNames', comp_labels, ...
        'OptimizeHyperparameters', 'auto', ...
        'HyperparameterOptimizationOptions', ...
        struct('AcquisitionFunctionName', 'expected-improvement-plus', ...
               'MaxObjectiveEvaluations', 30, ...
               'ShowPlots', false, ...
               'Verbose', 0));

    % 预测与评估
    y_pred = predict(tree_model, X_test);

    % 评估指标
    accuracy = sum(y_pred == y_test) / length(y_test);
    cm = confusionmat(y_test, y_pred);

    % 精确率、召回率、F1（使用标准定义：TP/(TP+FP), TP/(TP+FN)）
    if size(cm, 1) == 2
        n_classes = size(cm, 1);
        precision = zeros(1, n_classes);
        recall = zeros(1, n_classes);
        f1 = zeros(1, n_classes);
        for c = 1:n_classes
            tp = cm(c, c);
            fp = sum(cm(:, c)) - tp;
            fn = sum(cm(c, :)) - tp;
            precision(c) = tp / max(tp + fp, 1);
            recall(c) = tp / max(tp + fn, 1);
            f1(c) = 2 * precision(c) * recall(c) / max(precision(c) + recall(c), eps);
        end
        fprintf('准确率: %.2f%%\n', accuracy * 100);
        fprintf('高钾: 精确率=%.2f%%, 召回率=%.2f%%, F1=%.4f\n', ...
            precision(1)*100, recall(1)*100, f1(1));
        if n_classes >= 2
            fprintf('铅钡: 精确率=%.2f%%, 召回率=%.2f%%, F1=%.4f\n', ...
                precision(2)*100, recall(2)*100, f1(2));
        end
    else
        fprintf('准确率: %.2f%%\n', accuracy * 100);
    end

    % 输出特征重要性
    imp = predictorImportance(tree_model);
    [~, imp_order] = sort(imp, 'descend');
    fprintf('\n特征重要性排名 (前6):\n');
    for k = 1:min(6, length(comp_names))
        fprintf('  %2d. %-10s: %.4f\n', k, comp_names{imp_order(k)}, imp(imp_order(k)));
    end

    % 保存模型
    if weat_state == 0
        tree_unweathered = tree_model;
        acc_unweathered = accuracy;
        y_test_un = y_test;
        y_pred_un = y_pred;
    else
        tree_weathered = tree_model;
        acc_weathered = accuracy;
        y_test_w = y_test;
        y_pred_w = y_pred;
    end
end

% 用全部数据重新训练最终分类器（用于问题3预测）
% 注意：归一化数据保留成分绝对丰度，克服CLR对稀疏成分的扭曲
fprintf('\n--- 重新训练全数据分类器（用于问题3）---\n');

% 风化状态已知时使用分组模型，否则用全数据模型
for weat_state = 0:1
    if weat_state == 0
        state_name = '未风化';
    else
        state_name = '风化';
    end
    idx_all = T2_proc.WEAT_num == weat_state;
    if sum(idx_all) >= 3 && length(unique(T2_proc.TYPE_num(idx_all))) >= 2
        X_all = X2_norm(idx_all, :);
        y_all = T2_proc.TYPE_num(idx_all);
        tree_full = fitctree(X_all, y_all, ...
            'PredictorNames', comp_labels, ...
            'OptimizeHyperparameters', 'auto', ...
            'HyperparameterOptimizationOptions', ...
            struct('AcquisitionFunctionName', 'expected-improvement-plus', ...
                   'MaxObjectiveEvaluations', 30, ...
                   'ShowPlots', false, ...
                   'Verbose', 0));
        if weat_state == 0
            tree_unweathered = tree_full;
        else
            tree_weathered = tree_full;
        end
        fprintf('  %s 全数据决策树训练完成 (n=%d)\n', state_name, sum(idx_all));
    end
end

% 同时训练不分组的全数据模型（作为备选，适用于化学特征跨风化的样本）
tree_all = fitctree(X2_norm, T2_proc.TYPE_num, ...
    'PredictorNames', comp_labels, ...
    'OptimizeHyperparameters', 'auto', ...
    'HyperparameterOptimizationOptions', ...
    struct('AcquisitionFunctionName', 'expected-improvement-plus', ...
           'MaxObjectiveEvaluations', 30, ...
           'ShowPlots', false, ...
           'Verbose', 0));
fprintf('  全数据(不分风化)决策树训练完成 (n=%d)\n', size(X2_norm, 1));

% 保存决策树模型
save(fullfile(result_dir, 'decision_tree_models.mat'), ...
    'tree_unweathered', 'tree_weathered', 'tree_all', ...
    'acc_unweathered', 'acc_weathered');

%% ========== 2.2 亚类划分：层次聚类 ==========
fprintf('\n========== 2.2 亚类划分（层次聚类）==========\n');

% 先分四组，再在每组内进行聚类
groups_p2 = {
    '高钾-未风化', T2_proc.TYPE_num == 0 & T2_proc.WEAT_num == 0;
    '高钾-风化',   T2_proc.TYPE_num == 0 & T2_proc.WEAT_num == 1;
    '铅钡-未风化', T2_proc.TYPE_num == 1 & T2_proc.WEAT_num == 0;
    '铅钡-风化',   T2_proc.TYPE_num == 1 & T2_proc.WEAT_num == 1;
};

% Q型聚类：对样本聚类
% R型聚类：对成分特征聚类
cluster_results = cell(4, 1);

for g = 1:4
    idx = groups_p2{g, 2};
    n_group = sum(idx);

    fprintf('\n【%s】n=%d\n', groups_p2{g, 1}, n_group);

    if n_group < 3
        fprintf('  样本量不足，跳过聚类\n');
        continue;
    end

    Xg = X2_clr(idx, :);

    % Q型聚类（样本聚类）
    D_sample = pdist(Xg, 'correlation');  % 基于相关系数的距离
    Z_sample = linkage(D_sample, 'average');  % 平均距离法
    c_cophenet = cophenet(Z_sample, D_sample);
    fprintf('  Q型聚类Cophenetic系数: %.4f\n', c_cophenet);

    % 确定聚类数（轮廓系数优化）
    max_k = min(5, n_group - 1);
    sil_scores = zeros(max_k - 1, 1);
    for k = 2:max_k
        T_clust = cluster(Z_sample, 'maxclust', k);
        if length(unique(T_clust)) > 1
            sil_scores(k - 1) = mean(silhouette(Xg, T_clust, 'correlation'));
        end
    end
    [~, best_k] = max(sil_scores);
    best_k = best_k + 1;

    T_q = cluster(Z_sample, 'maxclust', best_k);
    fprintf('  Q型聚类: 最优聚类数=%d\n', best_k);

    % R型聚类（成分特征聚类）
    D_feature = pdist(Xg', 'correlation');
    Z_feature = linkage(D_feature, 'average');
    % 分为3类成分群
    T_r = cluster(Z_feature, 'maxclust', 3);

    cluster_results{g} = struct('group_name', groups_p2{g, 1}, ...
        'T_q', T_q, 'T_r', T_r, 'best_k', best_k, 'n', n_group);

    % 输出R型聚类结果
    fprintf('  R型聚类：成分分为3类\n');
    for c = 1:3
        members = comp_names(T_r == c);
        fprintf('    类%d: %s\n', c, strjoin(members, ', '));
    end
end

%% ========== 2.3 合理性与敏感性分析 ==========
fprintf('\n========== 2.3 分类合理性验证与敏感性分析 ==========\n');

% 敏感性分析：对CLR数据加入微小扰动，观察分类结果变化
perturbation = 0.01;
rng(123);  % 固定随机种子，保证可重复

fprintf('扰动幅度: delta=%.2f\n', perturbation);

for weat_state = 0:1
    if weat_state == 0
        state_name = '未风化';
        tree_m = tree_unweathered;
    else
        state_name = '风化';
        tree_m = tree_weathered;
    end

    idx = T2_proc.WEAT_num == weat_state;
    if sum(idx) == 0, continue; end

    X_orig = X2_norm(idx, :);  % 使用归一化数据
    y_orig = T2_proc.TYPE_num(idx);

    % 加入随机扰动
    noise = perturbation * randn(size(X_orig));
    X_perturbed = X_orig + noise;

    % 扰动前后预测对比
    y_pred_orig = predict(tree_m, X_orig);
    y_pred_pert = predict(tree_m, X_perturbed);

    % 统计变化
    n_changed = sum(y_pred_orig ~= y_pred_pert);
    accuracy_pert = sum(y_pred_pert == y_orig) / length(y_orig);
    accuracy_orig = sum(y_pred_orig == y_orig) / length(y_orig);

    fprintf('\n%s样本敏感性 (n=%d):\n', state_name, sum(idx));
    fprintf('  原始准确率: %.2f%%\n', accuracy_orig * 100);
    fprintf('  扰动后准确率: %.2f%%\n', accuracy_pert * 100);
    fprintf('  预测变化数: %d/%d (%.1f%%)\n', n_changed, sum(idx), ...
        100 * n_changed / sum(idx));
    fprintf('  结论: %s\n', iif(n_changed == 0, ...
        '分类结果稳定（扰动后无变化）', '分类结果对微小扰动敏感'));
end

%% ========== 绘图 ==========
fprintf('\n========== 生成问题2图表 ==========\n');

% 图2.1：决策树可视化（未风化样本）
figure('Position', [100, 100, 1400, 600]);
if exist('tree_unweathered', 'var')
    subplot(1, 2, 1);
    view(tree_unweathered, 'Mode', 'graph');
    title(sprintf('未风化样本决策树 (Acc=%.2f%%)', acc_unweathered * 100), ...
        'FontSize', 12, 'FontWeight', 'bold');
end
saveas(gcf, fullfile(fig_dir, 'p2_decision_tree.png'));
print(gcf, fullfile(fig_dir, 'p2_decision_tree_300.png'), '-dpng', '-r300');
close(gcf);

% 图2.2：混淆矩阵（使用imagesc代替confusionchart以兼容批处理模式）
figure('Position', [100, 100, 1000, 450]);
subplot(1, 2, 1);
if exist('y_test_un', 'var') && exist('y_pred_un', 'var')
    cm_un = confusionmat(y_test_un, y_pred_un);
    imagesc(cm_un); colormap(flipud(gray));
    set(gca, 'XTick', 1:2, 'XTickLabel', {'高钾', '铅钡'});
    set(gca, 'YTick', 1:2, 'YTickLabel', {'高钾', '铅钡'});
    colorbar;
    for r = 1:2
        for c = 1:2
            text(c, r, num2str(cm_un(r, c)), 'HorizontalAlignment', 'center', ...
                'FontSize', 14, 'FontWeight', 'bold');
        end
    end
    title(sprintf('未风化混淆矩阵 (Acc=%.1f%%)', acc_unweathered * 100), ...
        'FontSize', 11, 'FontWeight', 'bold');
end
subplot(1, 2, 2);
if exist('y_test_w', 'var') && exist('y_pred_w', 'var')
    cm_w = confusionmat(y_test_w, y_pred_w);
    imagesc(cm_w); colormap(flipud(gray));
    set(gca, 'XTick', 1:2, 'XTickLabel', {'高钾', '铅钡'});
    set(gca, 'YTick', 1:2, 'YTickLabel', {'高钾', '铅钡'});
    colorbar;
    for r = 1:2
        for c = 1:2
            text(c, r, num2str(cm_w(r, c)), 'HorizontalAlignment', 'center', ...
                'FontSize', 14, 'FontWeight', 'bold');
        end
    end
    title(sprintf('风化混淆矩阵 (Acc=%.1f%%)', acc_weathered * 100), ...
        'FontSize', 11, 'FontWeight', 'bold');
end
saveas(gcf, fullfile(fig_dir, 'p2_confusion_matrix.png'));
print(gcf, fullfile(fig_dir, 'p2_confusion_matrix_300.png'), '-dpng', '-r300');
close(gcf);

% 图2.3：特征重要性
figure('Position', [100, 100, 1200, 500]);
subplot(1, 2, 1);
if exist('tree_unweathered', 'var')
    imp_uw = predictorImportance(tree_unweathered);
    [imp_uw_sorted, order_uw] = sort(imp_uw, 'descend');
    barh(imp_uw_sorted(1:min(8, end)), 'FaceColor', [0.3 0.6 0.9]);
    set(gca, 'YTickLabel', comp_names(order_uw(1:min(8, end))));
    title('未风化：特征重要性', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('重要性'); set(gca, 'YDir', 'reverse'); grid on;
end
subplot(1, 2, 2);
if exist('tree_weathered', 'var')
    imp_wt = predictorImportance(tree_weathered);
    [imp_wt_sorted, order_wt] = sort(imp_wt, 'descend');
    barh(imp_wt_sorted(1:min(8, end)), 'FaceColor', [0.9 0.4 0.3]);
    set(gca, 'YTickLabel', comp_names(order_wt(1:min(8, end))));
    title('风化：特征重要性', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('重要性'); set(gca, 'YDir', 'reverse'); grid on;
end
sgtitle('问题2.1：决策树特征重要性排名', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(fig_dir, 'p2_feature_importance.png'));
print(gcf, fullfile(fig_dir, 'p2_feature_importance_300.png'), '-dpng', '-r300');
close(gcf);

% 图2.4：亚类聚类树状图
for g = 1:4
    idx = groups_p2{g, 2};
    if sum(idx) < 3, continue; end
    figure('Position', [100, 100, 800, 500]);
    Xg = X2_clr(idx, :);
    D_sample = pdist(Xg, 'correlation');
    Z_sample = linkage(D_sample, 'average');
    dendrogram(Z_sample, 'Orientation', 'top', 'Labels', ...
        arrayfun(@(x) sprintf('%d', x), find(idx), 'UniformOutput', false));
    title(sprintf('问题2.2：%s 样本聚类树状图', groups_p2{g, 1}), ...
        'FontSize', 13, 'FontWeight', 'bold');
    xlabel('样本'); ylabel('距离');
    saveas(gcf, fullfile(fig_dir, sprintf('p2_dendrogram_g%d.png', g)));
    close(gcf);
end

% 图2.5：轮廓系数对比（敏感性分析）
figure('Position', [100, 100, 800, 500]);
bar_data = [acc_unweathered * 100, acc_weathered * 100];
bar(bar_data, 'FaceColor', [0.3 0.7 0.5]);
set(gca, 'XTickLabel', {'未风化', '风化'});
ylabel('准确率 (%)');
title('问题2.1：决策树分类准确率', 'FontSize', 14, 'FontWeight', 'bold');
ylim([0, 105]);
text(1:2, bar_data + 2, arrayfun(@(x) sprintf('%.1f%%', x), bar_data, 'UniformOutput', false), ...
    'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
saveas(gcf, fullfile(fig_dir, 'p2_accuracy_summary.png'));
print(gcf, fullfile(fig_dir, 'p2_accuracy_summary_300.png'), '-dpng', '-r300');
close(gcf);

%% ========== 模型检验 ==========
fprintf('\n========== 模型检验 ==========\n');

% 检验1：交叉验证
fprintf('\n1. 5折交叉验证:\n');
for weat_state = 0:1
    if weat_state == 0
        state_name = '未风化';
    else
        state_name = '风化';
    end
    idx = T2_proc.WEAT_num == weat_state;
    if sum(idx) < 5, continue; end
    X_cv = X2_norm(idx, :);  % 使用归一化数据
    y_cv = T2_proc.TYPE_num(idx);

    cv_model = fitctree(X_cv, y_cv, 'KFold', 5);
    cv_loss = kfoldLoss(cv_model);
    fprintf('  %s: CV错误率=%.4f, CV准确率=%.2f%%\n', ...
        state_name, cv_loss, (1 - cv_loss) * 100);
end

% 检验2：聚类合理性
fprintf('\n2. 聚类合理性验证 (Cophenetic相关系数):\n');
for g = 1:4
    idx = groups_p2{g, 2};
    if sum(idx) >= 3
        Xg = X2_clr(idx, :);
        D = pdist(Xg, 'correlation');
        Z = linkage(D, 'average');
        cp = cophenet(Z, D);
        fprintf('  %s: Cophenetic=%.4f (%s)\n', groups_p2{g, 1}, cp, ...
            iif(cp > 0.7, '良好', iif(cp > 0.5, '可接受', '偏差较大')));
    end
end

fprintf('\n=============================================================\n');
fprintf('问题2完成!\n');
fprintf('=============================================================\n');

%% ==================== 辅助函数 ====================

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
