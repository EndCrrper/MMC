%% 问题2：品类销量预测与定价优化
% 2023 CUMCM C题
% 功能：预测7/1-7/7日销量，优化定价与补货量，最大化利润

%% 初始化
clc;
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1', 'T_daily', 'T_cat_daily', 'T3', 'T4_cat', 'cats');
fprintf('数据已加载\n');

%% 2.1 构建品类日销量预测模型
fprintf('\n====== 2.1 品类销量预测模型 ======\n');

cat_list = unique(T_cat_daily.cat_name);
n_cats = length(cat_list);

% 预测日期: 2023-07-01 至 2023-07-07
pred_dates = datetime(2023, 7, 1:7)';
n_pred = length(pred_dates);

% 存储结果
pred_results = table();
pred_results.date = pred_dates;
pred_results.day_of_week = weekday(pred_dates);

% 对每个品类建模
pred_cat_map = cell(1, n_cats);
for c = 1:n_cats
    cat_name = char(cat_list(c));
    cat_mask = strcmp(T_cat_daily.cat_name, cat_name);
    cat_data = T_cat_daily(cat_mask, :);
    cat_data = sortrows(cat_data, 'date');

    % 提取日销量序列
    sales_ts = cat_data.cat_total_kg;
    dates_ts = cat_data.date;

    % 使用最近4周的加权移动平均 + 星期效应
    % 先计算星期几的平均系数
    dow_sales = zeros(7, 1);
    dow_counts = zeros(7, 1);
    for i = 1:height(cat_data)
        d = weekday(dates_ts(i));
        dow_sales(d) = dow_sales(d) + sales_ts(i);
        dow_counts(d) = dow_counts(d) + 1;
    end
    dow_avg = dow_sales ./ max(dow_counts, 1);
    dow_factor = dow_avg / mean(dow_avg);  % 星期系数

    % 计算近4周日均销量趋势
    recent_cutoff = max(dates_ts) - days(28);
    recent_mask = dates_ts >= recent_cutoff;
    recent_sales = sales_ts(recent_mask);
    base_daily = mean(recent_sales);  % 近4周日均

    % 线性趋势修正
    if length(recent_sales) >= 14
        t = (1:length(recent_sales))';
        trend_mdl = fitlm(t, recent_sales);
        trend_slope = trend_mdl.Coefficients.Estimate(2);
    else
        trend_slope = 0;
    end

    % 预测每日销量
    pred_sales = zeros(n_pred, 1);
    for d = 1:n_pred
        dow = pred_results.day_of_week(d);
        trend_adj = trend_slope * (height(sales_ts) + d) / 365;  % 年化趋势
        pred_sales(d) = base_daily * dow_factor(dow) + trend_adj;
        pred_sales(d) = max(pred_sales(d), 0);  % 不能为负
    end

    % 存储（使用品类索引避免中文列名冲突）
    col_name = sprintf('pred_cat%d', c);
    pred_results.(col_name) = pred_sales;
    pred_cat_map{c} = col_name;  % 列名映射

    fprintf('  %s: 近4周日均=%.1f kg, 周系数范围=%.2f-%.2f\n', ...
        cat_name, base_daily, min(dow_factor), max(dow_factor));
end

%% 2.2 定价优化模型
fprintf('\n====== 2.2 定价优化 ======\n');

% 计算各品类的历史平均批发价和加价率
cat_pricing = table();
for c = 1:n_cats
    cat_name = char(cat_list(c));
    cat_mask = strcmp(T_daily.cat_name, cat_name) & T_daily.wholesale_price > 0;
    cat_data = T_daily(cat_mask, :);

    % 最近的批发价
    recent_wp = T3.date >= datetime(2023, 6, 24) & T3.date <= datetime(2023, 6, 30);
    wp_recent = T3(recent_wp, :);

    % 按单品汇总最近批发价
    wp_items = unique(wp_recent.item_id);
    all_wp = [];
    for ii = 1:length(wp_items)
        item_mask = strcmp(cat_data.item_id, wp_items{ii});
        if any(item_mask)
            all_wp = [all_wp; cat_data.wholesale_price(item_mask)];
        end
    end

    if isempty(all_wp)
        avg_wp = mean(cat_data.wholesale_price);
    else
        avg_wp = mean(all_wp);
    end

    % 历史加价率
    avg_markup = mean(cat_data.markup_rate(cat_data.markup_rate > 0 & ...
        cat_data.markup_rate < 5));  % 剔除异常值(加价率>500%)

    % 价格弹性（从问题1）
    valid = cat_data.daily_sales_kg > 0 & cat_data.avg_price > 0;
    if sum(valid) > 10
        X = log(cat_data.avg_price(valid));
        y = log(cat_data.daily_sales_kg(valid));
        mdl = fitlm(X, y);
        elasticity = mdl.Coefficients.Estimate(2);
    else
        elasticity = -1;  % 默认弹性
    end

    cat_pricing.cat_name{c} = cat_name;
    cat_pricing.avg_wholesale{c} = avg_wp;
    cat_pricing.avg_markup{c} = avg_markup;
    cat_pricing.elasticity{c} = elasticity;

    fprintf('  %s: 批发价=%.2f, 加价率=%.1f%%, 弹性=%.3f\n', ...
        cat_name, avg_wp, avg_markup*100, elasticity);
end

%% 2.3 利润最大化：最优定价
fprintf('\n====== 2.3 利润优化 ======\n');

% 损耗率（从附件4的品类平均）
loss_rates = zeros(n_cats, 1);
for c = 1:n_cats
    cat_name = char(cat_list(c));
    loss_row = find(strcmp(T4_cat.cat_name, cat_name), 1);
    if ~isempty(loss_row)
        loss_rates(c) = T4_cat.avg_loss_rate(loss_row) / 100;
    else
        loss_rates(c) = 0.1;  % 默认10%
    end
end

% 优化每个品类的定价
opt_results = table();
opt_results.cat_name = cat_list;
opt_results.opt_price = zeros(n_cats, 1);
opt_results.opt_markup = zeros(n_cats, 1);
opt_results.opt_replenish = zeros(n_cats, n_pred);
opt_results.opt_profit = zeros(n_cats, 1);

for c = 1:n_cats
    pred_sales_vec = pred_results.(pred_cat_map{c});

    wp = cat_pricing.avg_wholesale{c};
    elasticity = cat_pricing.elasticity{c};
    loss_rate = loss_rates(c);

    % 当前定价下的利润基准
    current_markup = cat_pricing.avg_markup{c};
    current_price = wp * (1 + current_markup);

    % 网格搜索最优加价率（品类特化搜索区间）
    % 以历史加价率为中心 ±40pp，限制在 [0.05, 1.50]
    markup_lower = max(0.05, current_markup - 0.40);
    markup_upper = min(1.50, current_markup + 0.40);
    markup_grid = markup_lower:0.005:markup_upper;
    best_profit = -inf;
    best_markup = current_markup;

    for m = 1:length(markup_grid)
        markup = markup_grid(m);
        price = wp * (1 + markup);

        % 弹性调整销量
        price_ratio = price / current_price;
        adjusted_sales = pred_sales_vec .* (price_ratio .^ elasticity);

        % 补货量 = 预测销量 / (1 - 损耗率)
        replenish = adjusted_sales / (1 - loss_rate);

        % 利润 = 售价*销量 - 进价*补货量
        revenue = sum(price * adjusted_sales);
        cost = sum(wp * replenish);
        profit = revenue - cost;

        if profit > best_profit
            best_profit = profit;
            best_markup = markup;
        end
    end

    % 判断是否触及搜索边界并记录
    hit_boundary = (best_markup <= markup_lower + 1e-6) || ...
                   (best_markup >= markup_upper - 1e-6);
    if hit_boundary
        fprintf('    [搜索触及边界: %.1f%%-%.1f%%]\n', ...
            markup_lower*100, markup_upper*100);
    end

    best_price = wp * (1 + best_markup);
    price_ratio_final = best_price / current_price;

    % 最终补货量
    final_sales = pred_sales_vec .* (price_ratio_final .^ elasticity);
    final_replenish = final_sales / (1 - loss_rate);

    opt_results.opt_price(c) = best_price;
    opt_results.opt_markup(c) = best_markup;
    opt_results.opt_replenish(c, :) = final_replenish';
    opt_results.opt_profit(c) = best_profit;

    fprintf('  %s: 最优价格=%.2f (加价%.0f%%), 日补货=%.1f kg, 周利润=%.1f元\n', ...
        char(cat_list(c)), best_price, best_markup*100, ...
        mean(final_replenish), best_profit);
end

%% 2.4 汇总预测结果
fprintf('\n====== 2.4 预测汇总 (2023/7/1-7/7) ======\n');

pred_table = table(pred_dates);
[~, day_names] = weekday(pred_dates, 'short');
pred_table.day_name = day_names;
for c = 1:n_cats
    col_s = sprintf('sales_cat%d', c);
    col_r = sprintf('repl_cat%d', c);

    price_ratio = opt_results.opt_price(c) / (cat_pricing.avg_wholesale{c} * ...
        (1 + cat_pricing.avg_markup{c}));
    adj_sales = pred_results.(pred_cat_map{c}) ...
        .* (price_ratio .^ cat_pricing.elasticity{c});

    pred_table.(col_s) = round(adj_sales, 1);
    pred_table.(col_r) = round(adj_sales / (1 - loss_rates(c)), 1);
end

disp(pred_table(:, 1:min(6, width(pred_table))));

%% 绘图
fprintf('\n====== 生成图表 ======\n');

% 图2.1：各品类周销量预测
figure('Position', [100, 100, 1200, 500]);
colors = lines(n_cats);
hold on;
for c = 1:n_cats
    plot(pred_dates, pred_results.(pred_cat_map{c}), 'o-', 'Color', colors(c,:), ...
        'LineWidth', 1.5, 'DisplayName', char(cat_list(c)));
end
xlabel('日期'); ylabel('预测日销量 (kg)');
title('问题2：各品类7日销量预测', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best'); grid on;
print(gcf, fullfile(fig_dir, 'p2_pred_sales_300.png'), '-dpng', '-r300');
close(gcf);

% 图2.2：最优定价 vs 当前定价
figure('Position', [100, 100, 1000, 500]);
subplot(1, 2, 1);
bar_data = [cat_pricing.avg_markup{:}]' * 100;
opt_markup_pct = opt_results.opt_markup * 100;
bar([bar_data, opt_markup_pct]);
set(gca, 'XTickLabel', cat_list, 'XTickLabelRotation', 30);
ylabel('加价率 (%)');
legend('当前', '最优', 'Location', 'best');
title('加价率对比', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(1, 2, 2);
bar_data_p = zeros(n_cats, 2);
for c = 1:n_cats
    bar_data_p(c, 1) = cat_pricing.avg_wholesale{c} * (1 + cat_pricing.avg_markup{c});
    bar_data_p(c, 2) = opt_results.opt_price(c);
end
bar(bar_data_p);
set(gca, 'XTickLabel', cat_list, 'XTickLabelRotation', 30);
ylabel('价格 (元/kg)');
legend('当前', '最优', 'Location', 'best');
title('定价对比', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
sgtitle('问题2.2：定价优化结果', 'FontSize', 14, 'FontWeight', 'bold');
print(gcf, fullfile(fig_dir, 'p2_pricing_opt_300.png'), '-dpng', '-r300');
close(gcf);

%% 保存结果
fprintf('\n保存结果...\n');
save(fullfile(result_dir, 'problem2_results.mat'), ...
    'pred_results', 'opt_results', 'pred_table', 'cat_pricing', 'loss_rates');
writetable(pred_table, fullfile(result_dir, 'p2_predictions.csv'));

fprintf('问题2完成!\n');
