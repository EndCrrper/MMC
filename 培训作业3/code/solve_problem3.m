%% 问题3：选品优化与补货计划
% 2023 CUMCM C题
% 功能：在27-33单品约束下选择最优商品组合，确定定价与补货

%% 初始化
clc;
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1', 'T_daily', 'T3', 'T4_item', 'cats');
load(fullfile(result_dir, 'problem2_results.mat'), ...
    'pred_results', 'cat_pricing', 'loss_rates');
fprintf('数据已加载\n');

%% 3.1 筛选候选商品（6月24-30日有销售记录的单品）
fprintf('\n====== 3.1 筛选候选商品 ======\n');

ref_start = datetime(2023, 6, 24);
ref_end = datetime(2023, 6, 30);
ref_mask = T_daily.date >= ref_start & T_daily.date <= ref_end;
ref_data = T_daily(ref_mask, :);

% 在参考周有销售的单品
candidate_items = unique(ref_data.item_id);
fprintf('参考周在售单品: %d\n', length(candidate_items));

%% 3.2 评估每个候选单品的指标
fprintf('\n====== 3.2 评估候选单品 ======\n');

n_cand = length(candidate_items);
cand_scores = table();
cand_scores.item_id = candidate_items;

% 指标初始化
cand_scores.avg_daily_sales = zeros(n_cand, 1);   % 参考周日均销量
cand_scores.profit_margin = zeros(n_cand, 1);      % 毛利率
cand_scores.sales_stability = zeros(n_cand, 1);    % 销量稳定性(CV倒数)
cand_scores.avg_price = zeros(n_cand, 1);          % 平均售价
cand_scores.wholesale = zeros(n_cand, 1);          % 批发价
cand_scores.cat_name = repmat({''}, n_cand, 1);    % 品类名
cand_scores.loss_rate = zeros(n_cand, 1);          % 损耗率
cand_scores.disc_ratio = zeros(n_cand, 1);         % 打折比例

for i = 1:n_cand
    item = candidate_items(i);
    item_mask = strcmp(ref_data.item_id, item);

    % 参考周数据
    item_ref = ref_data(item_mask, :);

    cand_scores.avg_daily_sales(i) = mean(item_ref.daily_sales_kg);
    cand_scores.avg_price(i) = mean(item_ref.avg_price);
    cand_scores.disc_ratio(i) = mean(item_ref.disc_ratio);

    % 历史全部数据（用于稳定性分析）
    hist_mask = strcmp(T_daily.item_id, item);
    hist_data = T_daily(hist_mask, :);
    if height(hist_data) > 5
        cand_scores.sales_stability(i) = 1 / max(std(hist_data.daily_sales_kg) / ...
            mean(hist_data.daily_sales_kg), 0.01);
    end

    % 毛利
    wp_mask = hist_data.wholesale_price > 0;
    if sum(wp_mask) > 0
        cand_scores.wholesale(i) = mean(hist_data.wholesale_price(wp_mask));
        avg_price_hist = mean(hist_data.avg_price(wp_mask));
        if avg_price_hist > 0
            cand_scores.profit_margin(i) = (avg_price_hist - ...
                cand_scores.wholesale(i)) / avg_price_hist;
        end
    end

    % 品类
    cat_mask = strcmp(T1.item_id, item);
    if any(cat_mask)
        cand_scores.cat_name{i} = char(T1.cat_name(find(cat_mask, 1)));
    end

    % 损耗率
    loss_mask = strcmp(cellstr(T4_item.item_id), char(item));
    if any(loss_mask)
        cand_scores.loss_rate(i) = T4_item.loss_rate(find(loss_mask, 1)) / 100;
    end
end

% 计算综合评分：日利润 = 日均销量 * 售价 * 毛利率 * (1 - 损耗率)
cand_scores.daily_profit = cand_scores.avg_daily_sales .* ...
    cand_scores.avg_price .* cand_scores.profit_margin .* (1 - cand_scores.loss_rate);
cand_scores.daily_profit(isnan(cand_scores.daily_profit)) = 0;

% 综合评分 = 利润 * 稳定性 * (1 - 打折率)
cand_scores.composite_score = cand_scores.daily_profit .* ...
    cand_scores.sales_stability ./ (1 + cand_scores.disc_ratio);

% 排序
[~, score_order] = sort(cand_scores.composite_score, 'descend');
cand_scores = cand_scores(score_order, :);

fprintf('Top-5 单品:\n');
for i = 1:5
    fprintf('  %d. %s (%s): 日利润=%.1f, 评分=%.1f\n', i, ...
        char(cand_scores.item_id(i)), cand_scores.cat_name{i}, ...
        cand_scores.daily_profit(i), cand_scores.composite_score(i));
end

%% 3.3 选品优化：在27-33约束下最大化总利润
fprintf('\n====== 3.3 选品优化 ======\n');

% 约束
N_min = 27;
N_max = 33;
min_replenish = 2.5;  % 每单品最低补货量(kg)

% 遍历不同选择数量，找最优
best_total_profit = -inf;
best_n = 27;
best_selection = [];

for n_select = N_min:N_max
    % 选Top-N
    selected = cand_scores(1:n_select, :);

    % 计算补货量（预测销量 + 缓冲，≥2.5kg）
    predicted_sales = selected.avg_daily_sales;
    replenish = max(predicted_sales ./ (1 - selected.loss_rate), min_replenish);

    % 计算总利润
    revenue = sum(selected.avg_price .* predicted_sales);
    cost = sum(selected.wholesale .* replenish);
    total_profit = revenue - cost;

    if total_profit > best_total_profit
        best_total_profit = total_profit;
        best_n = n_select;
        best_selection = selected;
    end

    fprintf('  N=%d: 总利润=%.1f元\n', n_select, total_profit);
end

fprintf('\n最优选择: N=%d, 总利润=%.1f元\n', best_n, best_total_profit);

%% 3.4 最终选品清单
fprintf('\n====== 3.4 7月1日选品清单 ======\n');

final_list = best_selection;
final_list.replenish_kg = max(final_list.avg_daily_sales ./ ...
    (1 - final_list.loss_rate), min_replenish);

% 计算品类分布
fprintf('\n品类分布:\n');
final_cats = unique(final_list.cat_name);
for c = 1:length(final_cats)
    cat_count = sum(strcmp(final_list.cat_name, final_cats{c}));
    fprintf('  %s: %d 个单品\n', final_cats{c}, cat_count);
end

fprintf('\nTop-10 选品详情:\n');
fprintf('%-20s %-10s %8s %8s %8s\n', '单品编码', '品类', '日销量', '补货量', '日利润');
for i = 1:min(10, height(final_list))
    fprintf('%-20s %-10s %8.1f %8.1f %8.1f\n', ...
        char(final_list.item_id(i)), final_list.cat_name{i}, ...
        final_list.avg_daily_sales(i), final_list.replenish_kg(i), ...
        final_list.daily_profit(i));
end

%% 3.5 品类平衡约束（可选优化）
fprintf('\n====== 3.5 品类平衡优化 ======\n');

% 确保每个品类至少有1个单品
balanced_list = [];
used_cats = {};
current_n = 0;

% 先各品类选1个
for c = 1:length(final_cats)
    cat_mask = strcmp(cand_scores.cat_name, final_cats{c});
    cat_candidates = cand_scores(cat_mask, :);
    if ~isempty(cat_candidates)
        balanced_list = [balanced_list; cat_candidates(1, :)];
        used_cats{end+1} = final_cats{c};
        current_n = current_n + 1;
    end
end

% 补齐到27个
if current_n < N_min
    remaining = cand_scores(~ismember(cand_scores.item_id, balanced_list.item_id), :);
    n_add = min(N_max - current_n, N_min - current_n + 6);  % 补到27-33
    balanced_list = [balanced_list; remaining(1:n_add, :)];
    current_n = current_n + n_add;
end

% 计算平衡方案的补货和利润
balanced_list.replenish_kg = max(balanced_list.avg_daily_sales ./ ...
    (1 - balanced_list.loss_rate), min_replenish);

balanced_revenue = sum(balanced_list.avg_price .* balanced_list.avg_daily_sales);
balanced_cost = sum(balanced_list.wholesale .* balanced_list.replenish_kg);
balanced_profit = balanced_revenue - balanced_cost;

fprintf('品类平衡方案: N=%d, 总利润=%.1f元\n', ...
    height(balanced_list), balanced_profit);
for c = 1:length(final_cats)
    cat_count = sum(strcmp(balanced_list.cat_name, final_cats{c}));
    fprintf('  %s: %d 个\n', final_cats{c}, cat_count);
end

%% 绘图
fprintf('\n====== 生成图表 ======\n');

% 图3.1：选品利润贡献
figure('Position', [100, 100, 1200, 500]);
subplot(1, 2, 1);
pareto_data = final_list.daily_profit(1:min(20, height(final_list)));
bar(pareto_data, 'FaceColor', [0.3 0.6 0.9]);
xlabel('单品排名'); ylabel('日利润 (元)');
title('Top-20 单品日利润', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(1, 2, 2);
cat_counts = zeros(length(final_cats), 1);
cat_profits = zeros(length(final_cats), 1);
for c = 1:length(final_cats)
    cat_mask = strcmp(final_list.cat_name, final_cats{c});
    cat_counts(c) = sum(cat_mask);
    cat_profits(c) = sum(final_list.daily_profit(cat_mask));
end
yyaxis left;
bar(cat_counts, 'FaceColor', [0.3 0.6 0.9]);
ylabel('单品数');
yyaxis right;
plot(1:length(final_cats), cat_profits, 'ro-', 'LineWidth', 2);
ylabel('总日利润 (元)');
set(gca, 'XTickLabel', final_cats, 'XTickLabelRotation', 30);
title('品类分布与利润', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

sgtitle('问题3：选品优化结果', 'FontSize', 14, 'FontWeight', 'bold');
print(gcf, fullfile(fig_dir, 'p3_selection_300.png'), '-dpng', '-r300');
close(gcf);

%% 保存结果
fprintf('\n保存结果...\n');
save(fullfile(result_dir, 'problem3_results.mat'), ...
    'cand_scores', 'final_list', 'balanced_list', 'best_n');

% 导出选品清单CSV
output_table = final_list(:, {'item_id', 'cat_name', 'avg_daily_sales', ...
    'replenish_kg', 'avg_price', 'daily_profit'});
writetable(output_table, fullfile(result_dir, 'p3_product_list.csv'));

fprintf('问题3完成!\n');
