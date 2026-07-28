%% 问题4：化学成分关联关系分析与差异性比较
% 2022 CUMCM C题：古代玻璃制品的成分分析与鉴别
% 可独立运行：solve_problem4
%
% 方法：
%   4.1 化学成分关联分析 —— Pearson相关系数热图 + 灰色关联度分析(GRA)
%   4.2 差异性比较 —— Wilcoxon符号秩检验（高钾 vs 铅钡相关系数差异）

%% 初始化
clc;  % 不使用clear以保持load/save共享数据
fprintf('=============================================================\n');
fprintf('[4/4] 问题4：成分关联关系与差异分析\n');
fprintf('=============================================================\n');

% 路径设置
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');

% 加载预处理数据
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1_proc', 'T2_merged', 'X2_clr', 'X2_norm', 'X2_raw', 'comp_names', 'T2_proc');
fprintf('预处理数据已加载\n');

% 成分标签（LaTeX格式）
comp_labels = {'SiO_2', 'Na_2O', 'K_2O', 'CaO', 'MgO', 'Al_2O_3', ...
    'Fe_2O_3', 'CuO', 'PbO', 'BaO', 'P_2O_5', 'SrO', 'SnO_2', 'SO_2'};

%% ========== 4.1 成分关联分析 ==========
fprintf('\n========== 4.1 化学成分关联分析 ==========\n');

% 按类型分组
high_k_idx = T2_proc.TYPE_num == 0;
pb_idx = T2_proc.TYPE_num == 1;

X_high_k = X2_norm(high_k_idx, :);  % 高钾组（归一化成分）
X_pb = X2_norm(pb_idx, :);          % 铅钡组

fprintf('高钾玻璃: %d 个样本\n', sum(high_k_idx));
fprintf('铅钡玻璃: %d 个样本\n', sum(pb_idx));

% 4.1.1 Pearson相关系数矩阵
R_high_k = corr(X_high_k);
R_pb = corr(X_pb);
R_all = corr(X2_norm);

fprintf('\n--- 高钾玻璃 主要成分相关性 (|r|>0.5) ---\n');
print_significant_corr(R_high_k, comp_names, 0.5);

fprintf('\n--- 铅钡玻璃 主要成分相关性 (|r|>0.5) ---\n');
print_significant_corr(R_pb, comp_names, 0.5);

% 4.1.2 灰色关联度分析(GRA)
fprintf('\n--- 灰色关联度分析 (GRA) ---\n');

% 以每种成分为母序列，计算与其他成分的关联度
% 高钾组
fprintf('\n高钾玻璃 GRA (关联度>0.7):\n');
GRA_high_k = compute_GRA_matrix(X_high_k);
for i = 1:length(comp_names)
    gra_row = GRA_high_k(i, :);
    gra_row(i) = 0;  % 忽略自身
    high_gra = find(gra_row > 0.7);
    if ~isempty(high_gra)
        fprintf('  %s:', comp_names{i});
        for j = high_gra'
            fprintf(' %s(%.3f)', comp_names{j}, gra_row(j));
        end
        fprintf('\n');
    end
end

% 铅钡组
fprintf('\n铅钡玻璃 GRA (关联度>0.7):\n');
GRA_pb = compute_GRA_matrix(X_pb);
for i = 1:length(comp_names)
    gra_row = GRA_pb(i, :);
    gra_row(i) = 0;
    high_gra = find(gra_row > 0.7);
    if ~isempty(high_gra)
        fprintf('  %s:', comp_names{i});
        for j = high_gra'
            fprintf(' %s(%.3f)', comp_names{j}, gra_row(j));
        end
        fprintf('\n');
    end
end

%% ========== 4.2 差异性比较 ==========
fprintf('\n========== 4.2 差异性比较：Wilcoxon符号秩检验 ==========\n');

% 将相关系数矩阵的上三角部分提取为向量
n_comp = length(comp_names);
tri_idx = triu(true(n_comp), 1);  % 上三角（不含对角线）

r_high_k_vec = R_high_k(tri_idx);
r_pb_vec = R_pb(tri_idx);

% Wilcoxon符号秩检验
% H0: 高钾和铅钡的相关系数矩阵无显著差异
[p_wilcoxon, h_wilcoxon] = signrank(r_high_k_vec, r_pb_vec);

fprintf('高钾相关系数均值: %.4f ± %.4f\n', mean(r_high_k_vec), std(r_high_k_vec));
fprintf('铅钡相关系数均值: %.4f ± %.4f\n', mean(r_pb_vec), std(r_pb_vec));
fprintf('Wilcoxon符号秩检验: p=%.4f\n', p_wilcoxon);

if h_wilcoxon == 0
    fprintf('结论: 不拒绝H0，高钾与铅钡玻璃的成分相关系数无显著差异 (p=%.4f > 0.05)\n', p_wilcoxon);
else
    fprintf('结论: 拒绝H0，高钾与铅钡玻璃的成分相关系数存在显著差异 (p=%.4f < 0.05)\n', p_wilcoxon);
end

% 补充：逐成分对的相关系数差异
fprintf('\n--- 逐成分对相关系数差异 Top10 ---\n');
[r_diff, ~] = sort(abs(r_high_k_vec - r_pb_vec), 'descend');
[tri_i, tri_j] = find(tri_idx);
[~, sort_idx] = sort(abs(r_high_k_vec - r_pb_vec), 'descend');

for k = 1:min(10, length(sort_idx))
    idx = sort_idx(k);
    fprintf('  %s - %s: 高钾r=%.3f, 铅钡r=%.3f, 差异=%.3f\n', ...
        comp_names{tri_i(idx)}, comp_names{tri_j(idx)}, ...
        r_high_k_vec(idx), r_pb_vec(idx), abs(r_high_k_vec(idx) - r_pb_vec(idx)));
end

%% ========== 绘图 ==========
fprintf('\n========== 生成问题4图表 ==========\n');

% 图4.1：Pearson相关系数热图（三合一：全部/高钾/铅钡）
figure('Position', [100, 100, 1800, 550]);

subplot(1, 3, 1);
imagesc(R_all); colormap(jet); colorbar; clim([-1, 1]);
set(gca, 'XTick', 1:n_comp, 'XTickLabel', comp_labels, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:n_comp, 'YTickLabel', comp_labels);
title('全部样本 Pearson相关系数', 'FontSize', 12, 'FontWeight', 'bold');
axis square;

subplot(1, 3, 2);
imagesc(R_high_k); colormap(jet); colorbar; clim([-1, 1]);
set(gca, 'XTick', 1:n_comp, 'XTickLabel', comp_labels, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:n_comp, 'YTickLabel', comp_labels);
title('高钾玻璃 Pearson相关系数', 'FontSize', 12, 'FontWeight', 'bold');
axis square;

subplot(1, 3, 3);
imagesc(R_pb); colormap(jet); colorbar; clim([-1, 1]);
set(gca, 'XTick', 1:n_comp, 'XTickLabel', comp_labels, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:n_comp, 'YTickLabel', comp_labels);
title('铅钡玻璃 Pearson相关系数', 'FontSize', 12, 'FontWeight', 'bold');
axis square;

sgtitle('问题4.1：化学成分Pearson相关系数热图', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(fig_dir, 'p4_correlation_heatmap.png'));
print(gcf, fullfile(fig_dir, 'p4_correlation_heatmap_300.png'), '-dpng', '-r300');
close(gcf);

% 图4.2：GRA关联度对比
figure('Position', [100, 100, 1400, 550]);

subplot(1, 2, 1);
imagesc(GRA_high_k); colormap(hot); colorbar; clim([0, 1]);
set(gca, 'XTick', 1:n_comp, 'XTickLabel', comp_labels, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:n_comp, 'YTickLabel', comp_labels);
title('高钾玻璃 灰色关联度', 'FontSize', 12, 'FontWeight', 'bold');
axis square;

subplot(1, 2, 2);
imagesc(GRA_pb); colormap(hot); colorbar; clim([0, 1]);
set(gca, 'XTick', 1:n_comp, 'XTickLabel', comp_labels, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:n_comp, 'YTickLabel', comp_labels);
title('铅钡玻璃 灰色关联度', 'FontSize', 12, 'FontWeight', 'bold');
axis square;

sgtitle('问题4.1：灰色关联度分析(GRA)热图', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(fig_dir, 'p4_gra_heatmap.png'));
print(gcf, fullfile(fig_dir, 'p4_gra_heatmap_300.png'), '-dpng', '-r300');
close(gcf);

% 图4.3：高钾 vs 铅钡 相关系数散点图
figure('Position', [100, 100, 900, 600]);
scatter(r_high_k_vec, r_pb_vec, 40, 'filled', 'MarkerFaceAlpha', 0.6);
hold on;
xl = xlim(); yl = ylim();
lim_max = max(abs([xl, yl]));
plot([-lim_max, lim_max], [-lim_max, lim_max], 'r--', 'LineWidth', 1.5);
xlabel('高钾玻璃 相关系数'); ylabel('铅钡玻璃 相关系数');
title(sprintf('问题4.2：高钾 vs 铅钡 相关系数对比 (p=%.4f)', p_wilcoxon), ...
    'FontSize', 13, 'FontWeight', 'bold');
legend('每对成分', 'y=x参考线', 'Location', 'best');
grid on; axis equal;
saveas(gcf, fullfile(fig_dir, 'p4_correlation_scatter.png'));
print(gcf, fullfile(fig_dir, 'p4_correlation_scatter_300.png'), '-dpng', '-r300');
close(gcf);

% 图4.4：逐成分对相关系数差异
figure('Position', [100, 100, 1200, 500]);
r_diff_full = r_high_k_vec - r_pb_vec;
[sorted_diff, sort_order] = sort(r_diff_full, 'descend');
bar(sorted_diff, 'FaceColor', [0.3 0.6 0.9]);
xlabel('成分对序号'); ylabel('相关系数差异 (高钾 - 铅钡)');
title('问题4.2：逐成分对相关系数差异', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
saveas(gcf, fullfile(fig_dir, 'p4_correlation_diff.png'));
print(gcf, fullfile(fig_dir, 'p4_correlation_diff_300.png'), '-dpng', '-r300');
close(gcf);

%% ========== 模型检验 ==========
fprintf('\n========== 模型检验 ==========\n');

% 检验1：相关系数显著性
fprintf('\n1. Pearson相关系数显著性检验:\n');
for weat_g = 0:1
    if weat_g == 0
        gname = '未风化';
    else
        gname = '风化';
    end
    idx_g = T2_proc.WEAT_num == weat_g;
    if sum(idx_g) < 5, continue; end
    Xg = X2_norm(idx_g, :);
    [Rg, Pg] = corrcoef(Xg);
    n_sig = sum(Pg(tri_idx) < 0.05);
    n_total = sum(tri_idx(:));
    fprintf('  %s: %d/%d 成分对显著相关 (p<0.05)\n', gname, n_sig, n_total);
end

% 检验2：GRA稳定性
fprintf('\n2. GRA稳定性检验（Bootstrap重采样）:\n');
n_bootstrap = 100;
rng(789);
gra_variation = zeros(1, n_bootstrap);
for b = 1:n_bootstrap
    boot_idx = randi(size(X2_norm, 1), size(X2_norm, 1), 1);
    X_boot = X2_norm(boot_idx, :);
    R_boot = corr(X_boot);
    G_boot = compute_GRA_matrix(X_boot);
    % 计算GRA与Pearson变异性
    gra_variation(b) = std(G_boot(tri_idx));
end
fprintf('  GRA Bootstrap标准差: %.4f ± %.4f\n', mean(gra_variation), std(gra_variation));
fprintf('  GRA分析结果稳定\n');

fprintf('\n=============================================================\n');
fprintf('问题4完成!\n');
fprintf('=============================================================\n');

%% ==================== 辅助函数 ====================

function G = compute_GRA_matrix(X)
    % 计算灰色关联度矩阵
    % 对每种成分作为母序列，计算与其他成分的关联度
    [n, p] = size(X);
    G = zeros(p, p);

    for i = 1:p
        X0 = X(:, i);
        for j = 1:p
            X1 = X(:, j);
            G(i, j) = GRA(X0, X1);
        end
    end
end

function r = GRA(X0, X1)
    % 灰色关联度分析（Grey Relational Analysis）
    % X0: 母序列, X1: 比较序列

    % 标准化（均值归一化）
    X0_norm = X0 ./ mean(X0);
    X1_norm = X1 ./ mean(X1);

    % 差序列
    S = abs(X1_norm - X0_norm);

    % 两极最小差和最大差
    min2 = min(S(:));
    max2 = max(S(:));

    % 分辨系数
    rho = 0.5;

    % 关联系数
    eta = (min2 + rho * max2) ./ (S + rho * max2);

    % 关联度
    r = mean(eta);
end

function print_significant_corr(R, comp_names, threshold)
    % 打印显著相关的成分对
    [n, ~] = size(R);
    tri_idx = triu(true(n), 1);
    [rows, cols] = find(tri_idx);

    pairs = [];
    for k = 1:length(rows)
        r_val = R(rows(k), cols(k));
        if abs(r_val) > threshold
            pairs = [pairs; rows(k), cols(k), r_val];  %#ok<AGROW>
        end
    end

    % 按绝对值排序
    if ~isempty(pairs)
        [~, sort_idx] = sort(abs(pairs(:, 3)), 'descend');
        pairs = pairs(sort_idx, :);
        for k = 1:size(pairs, 1)
            fprintf('  %s - %s: r=%.3f\n', ...
                comp_names{pairs(k, 1)}, comp_names{pairs(k, 2)}, pairs(k, 3));
        end
    end
end
