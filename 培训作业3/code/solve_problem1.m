%% 问题1：蔬菜品类销量分布规律与关联关系
% 2023 CUMCM C题
% 功能：品类/单品销量分布、时间规律、关联关系分析

%% 初始化
clc;
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1', 'T_daily', 'T_cat_daily', 'cats');
fprintf('数据已加载\n');

%% 1.1 品类层面分析
fprintf('\n====== 1.1 品类销量分布 ======\n');

% 各品类总销量和占比
cat_stats = grpstats(T_daily, 'cat_name', {'sum', 'mean', 'std'}, ...
    'DataVars', 'daily_sales_kg');
cat_total = cat_stats.sum_daily_sales_kg;
[cat_total_sorted, cat_order] = sort(cat_total, 'descend');
cat_names_sorted = cat_stats.cat_name(cat_order);

fprintf('\n品类总销量排名:\n');
for i = 1:length(cat_names_sorted)
    pct = 100 * cat_total_sorted(i) / sum(cat_total);
    fprintf('  %d. %s: %.1f kg (%.1f%%)\n', i, ...
        cat_names_sorted{i}, cat_total_sorted(i), pct);
end

%% 1.2 单品层面分析
fprintf('\n====== 1.2 单品销量分布 ======\n');

item_stats = grpstats(T_daily, {'item_id', 'cat_name'}, {'sum', 'mean'}, ...
    'DataVars', 'daily_sales_kg');
item_total = item_stats.sum_daily_sales_kg;
[item_total_sorted, item_order] = sort(item_total, 'descend');

fprintf('Top-10 单品:\n');
for i = 1:min(10, length(item_order))
    idx = item_order(i);
    fprintf('  %d. %s (%s): %.1f kg\n', i, ...
        char(item_stats.item_id(idx)), char(item_stats.cat_name(idx)), ...
        item_total_sorted(i));
end

% 集中度分析：Top-N单品贡献了多少销量
cumsum_pct = cumsum(item_total_sorted) / sum(item_total) * 100;
top20_pct = cumsum_pct(min(20, length(cumsum_pct)));
top50_pct = cumsum_pct(min(50, length(cumsum_pct)));
fprintf('\n销量集中度: Top20=%.1f%%, Top50=%.1f%%\n', top20_pct, top50_pct);

%% 1.3 时间规律分析
fprintf('\n====== 1.3 时间规律 ======\n');

% 按月份聚合
T_daily.month = month(T_daily.date);
T_daily.year = year(T_daily.date);
monthly_sales = grpstats(T_daily, {'year', 'month'}, {'sum'}, ...
    'DataVars', 'daily_sales_kg');

% 星期效应
dow_sales = grpstats(T_daily, 'day_of_week', {'mean', 'std'}, ...
    'DataVars', 'daily_sales_kg');
fprintf('星期几效应 (日均销量, kg):\n');
dow_names = {'日', '一', '二', '三', '四', '五', '六'};
for d = 1:7
    row = find(dow_sales.day_of_week == d, 1);
    if ~isempty(row)
        fprintf('  周%s: %.1f +/- %.1f\n', dow_names{d}, ...
            dow_sales.mean_daily_sales_kg(row), ...
            dow_sales.std_daily_sales_kg(row));
    end
end

%% 1.4 品类间关联关系
fprintf('\n====== 1.4 品类间关联分析 ======\n');

% 构建品类日销量矩阵
cat_list = unique(T_cat_daily.cat_name);
date_list = unique(T_cat_daily.date);
n_dates = length(date_list);
n_cats = length(cat_list);

cat_matrix = zeros(n_dates, n_cats);
for i = 1:n_dates
    for j = 1:n_cats
        mask = T_cat_daily.date == date_list(i) & ...
               strcmp(T_cat_daily.cat_name, cat_list{j});
        if any(mask)
            cat_matrix(i, j) = T_cat_daily.cat_total_kg(mask);
        end
    end
end

% Pearson相关系数
R_cat = corr(cat_matrix);
fprintf('\n品类间相关系数矩阵:\n');
for i = 1:n_cats
    for j = 1:n_cats
        fprintf('%8.3f ', R_cat(i,j));
    end
    fprintf('  | %s\n', char(cat_list(i)));
end

% 最大正相关和负相关
R_tri = R_cat;
R_tri(1:n_cats+1:end) = 0;  % 去对角线
[max_corr, max_idx] = max(R_tri(:));
[min_corr, min_idx] = min(R_tri(:));
[mi, mj] = ind2sub([n_cats, n_cats], max_idx);
[ni, nj] = ind2sub([n_cats, n_cats], min_idx);
fprintf('\n最强正相关: %s vs %s (r=%.3f)\n', cat_list{mi}, cat_list{mj}, max_corr);
fprintf('最强负相关: %s vs %s (r=%.3f)\n', cat_list{ni}, cat_list{nj}, min_corr);

%% 1.5 价格-销量关系
fprintf('\n====== 1.5 价格-销量弹性分析 ======\n');
% 对每个品类计算平均价格与销量的关系
for j = 1:n_cats
    cat_mask = strcmp(T_daily.cat_name, cat_list{j});
    if sum(cat_mask) > 20
        cat_data = T_daily(cat_mask, :);
        % 对数-对数回归：log(Q) = a + b*log(P)
        valid = cat_data.daily_sales_kg > 0 & cat_data.avg_price > 0;
        if sum(valid) > 10
            X = log(cat_data.avg_price(valid));
            y = log(cat_data.daily_sales_kg(valid));
            mdl = fitlm(X, y);
            elasticity = mdl.Coefficients.Estimate(2);
            fprintf('  %s: 价格弹性=%.3f (p=%.3f)\n', ...
                char(cat_list(j)), elasticity, mdl.Coefficients.pValue(2));
        end
    end
end

%% 1.6 弹性估计稳健性检验
fprintf('\n====== 1.6 弹性估计稳健性检验 ======\n');

% 保存弹性估计结果供后续使用
elasticity_results = table();
elasticity_results.cat_name = cat_list;
elasticity_results.elasticity = zeros(n_cats, 1);
elasticity_results.p_value = zeros(n_cats, 1);
elasticity_results.R2 = zeros(n_cats, 1);

for j = 1:n_cats
    cat_mask = strcmp(T_daily.cat_name, cat_list{j});
    cat_data = T_daily(cat_mask, :);
    valid = cat_data.daily_sales_kg > 0 & cat_data.avg_price > 0;
    if sum(valid) > 10
        X = log(cat_data.avg_price(valid));
        y = log(cat_data.daily_sales_kg(valid));
        mdl = fitlm(X, y);
        elasticity_results.elasticity(j) = mdl.Coefficients.Estimate(2);
        elasticity_results.p_value(j) = mdl.Coefficients.pValue(2);
        elasticity_results.R2(j) = mdl.Rsquared.Ordinary;
    end
end

% --- 滚动窗口弹性估计（90天 / 180天） ---
fprintf('\n滚动窗口弹性估计（90天 / 180天窗口）:\n');
window_sizes = [90, 180];
for w = 1:length(window_sizes)
    win = window_sizes(w);
    fprintf('  %d天窗口:\n', win);
    for j = 1:n_cats
        cat_mask = strcmp(T_daily.cat_name, cat_list{j});
        cat_data = T_daily(cat_mask, :);
        cat_data = sortrows(cat_data, 'date');

        rolling_eta = [];
        valid_win = cat_data.daily_sales_kg > 0 & cat_data.avg_price > 0;
        n_valid = sum(valid_win);
        if n_valid > win
            for t = win:n_valid
                idx = find(valid_win);
                win_idx = idx(max(1, t-win+1):t);
                win_idx = win_idx(valid_win(win_idx));
                if length(win_idx) > win/2
                    Xw = log(cat_data.avg_price(win_idx));
                    yw = log(cat_data.daily_sales_kg(win_idx));
                    if length(Xw) > 10
                        mdl_w = fitlm(Xw, yw);
                        rolling_eta = [rolling_eta; mdl_w.Coefficients.Estimate(2)];
                    end
                end
            end
        end
        if ~isempty(rolling_eta)
            fprintf('    %s: 均值=%.3f, 标准差=%.3f, 范围=[%.3f, %.3f]\n', ...
                char(cat_list(j)), mean(rolling_eta), std(rolling_eta), ...
                min(rolling_eta), max(rolling_eta));
        end
    end
end

% --- Bootstrap重采样（200次） ---
fprintf('\nBootstrap 200次重采样（95%%置信区间）:\n');
n_bootstrap = 200;
rng(42);  % 固定随机种子保证可复现
for j = 1:n_cats
    cat_mask = strcmp(T_daily.cat_name, cat_list{j});
    cat_data = T_daily(cat_mask, :);
    valid = cat_data.daily_sales_kg > 0 & cat_data.avg_price > 0;
    X_full = log(cat_data.avg_price(valid));
    y_full = log(cat_data.daily_sales_kg(valid));
    n_obs = length(X_full);

    boot_eta = zeros(n_bootstrap, 1);
    for b = 1:n_bootstrap
        boot_idx = randi(n_obs, n_obs, 1);
        X_boot = X_full(boot_idx);
        y_boot = y_full(boot_idx);
        mdl_boot = fitlm(X_boot, y_boot);
        boot_eta(b) = mdl_boot.Coefficients.Estimate(2);
    end
    ci_low = prctile(boot_eta, 2.5);
    ci_high = prctile(boot_eta, 97.5);
    fprintf('  %s: 估计值=%.3f, 95%%CI=[%.3f, %.3f], SE=%.3f\n', ...
        char(cat_list(j)), elasticity_results.elasticity(j), ...
        ci_low, ci_high, std(boot_eta));
end

% 保存弹性结果
save(fullfile(result_dir, 'elasticity_results.mat'), 'elasticity_results');

%% 绘图
fprintf('\n====== 生成图表 ======\n');

% 图1.1：品类总销量柱状图
figure('Position', [100, 100, 1000, 500]);
bar(cat_total_sorted / 1000, 'FaceColor', [0.3 0.6 0.9]);
set(gca, 'XTickLabel', cat_names_sorted, 'XTickLabelRotation', 30);
ylabel('总销量 (吨)'); title('问题1.1：各品类总销量排名', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
for i = 1:length(cat_total_sorted)
    text(i, cat_total_sorted(i)/1000 + 0.5, sprintf('%.1f%%', ...
        100*cat_total_sorted(i)/sum(cat_total)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end
print(gcf, fullfile(fig_dir, 'p1_cat_sales_300.png'), '-dpng', '-r300');
close(gcf);

% 图1.2：单品销量集中度（Lorenz曲线）
figure('Position', [100, 100, 800, 600]);
n_items = length(item_total_sorted);
plot((1:n_items)/n_items*100, cumsum_pct, 'b-', 'LineWidth', 2);
hold on;
plot([0 100], [0 100], 'k--');
xlabel('单品累计占比 (%)'); ylabel('销量累计占比 (%)');
title('问题1.2：单品销量集中度曲线', 'FontSize', 14, 'FontWeight', 'bold');
legend('实际分布', '完全均匀', 'Location', 'southeast');
grid on;
print(gcf, fullfile(fig_dir, 'p1_concentration_300.png'), '-dpng', '-r300');
close(gcf);

% 图1.3：品类间相关系数热图
figure('Position', [100, 100, 800, 600]);
imagesc(R_cat); colormap(jet); colorbar; clim([-1, 1]);
set(gca, 'XTick', 1:n_cats, 'XTickLabel', cat_list, 'XTickLabelRotation', 30);
set(gca, 'YTick', 1:n_cats, 'YTickLabel', cat_list);
axis square;
title('问题1.4：品类间销量相关系数', 'FontSize', 14, 'FontWeight', 'bold');
print(gcf, fullfile(fig_dir, 'p1_corr_heatmap_300.png'), '-dpng', '-r300');
close(gcf);

% 图1.4：月度销量趋势
figure('Position', [100, 100, 1200, 500]);
months_dt = datetime(monthly_sales.year, monthly_sales.month, 1);
[~, mo_sort] = sort(months_dt);
plot(months_dt(mo_sort), monthly_sales.sum_daily_sales_kg(mo_sort)/1000, ...
    'b-o', 'LineWidth', 1.5);
xlabel('月份'); ylabel('月总销量 (吨)');
title('问题1.3：月度总销量趋势', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
print(gcf, fullfile(fig_dir, 'p1_monthly_trend_300.png'), '-dpng', '-r300');
close(gcf);

fprintf('\n问题1完成!\n');
