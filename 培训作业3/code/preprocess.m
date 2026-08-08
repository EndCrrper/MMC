%% 蔬菜商品自动定价与补货决策 —— 数据预处理
% 2023 CUMCM C题
% 功能：读取4个附件，数据清洗、合并、特征工程
% 可独立运行：preprocess

%% 初始化
clc;
fprintf('蔬菜商品数据预处理...\n');

base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');
if ~exist(result_dir, 'dir'), mkdir(result_dir); end
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

data_dir = fullfile(base_dir, '..', '题目');

%% 一、读取附件1：商品信息
fprintf('\n--- 读取附件1：商品信息 ---\n');
T1 = readtable(fullfile(data_dir, '附件1.xlsx'), 'VariableNamingRule', 'preserve');
T1.Properties.VariableNames = {'item_id', 'item_name', 'cat_code', 'cat_name'};
fprintf('单品数: %d, 品类数: %d\n', height(T1), length(unique(T1.cat_code)));
cats = categories(categorical(T1.cat_name));
fprintf('品类: %s\n', strjoin(cats, ', '));

%% 二、读取附件2：销售流水
fprintf('\n--- 读取附件2：销售流水 ---\n');
T2 = readtable(fullfile(data_dir, '附件2.xlsx'), 'VariableNamingRule', 'preserve');
T2.Properties.VariableNames = {'sale_date', 'scan_time', 'item_id', 'sales_kg', ...
    'unit_price', 'sale_type', 'is_discount'};
fprintf('销售记录: %d 条\n', height(T2));
fprintf('日期范围: %s ~ %s\n', datestr(min(T2.sale_date)), datestr(max(T2.sale_date)));

% 转换日期
T2.sale_date = dateshift(T2.sale_date, 'start', 'day');
T2.day_of_week = weekday(T2.sale_date);

% 标记是否打折
T2.is_disc = double(string(T2.is_discount) == '是');

%% 三、读取附件3：批发价格
fprintf('\n--- 读取附件3：批发价格 ---\n');
T3 = readtable(fullfile(data_dir, '附件3.xlsx'), 'VariableNamingRule', 'preserve');
T3.Properties.VariableNames = {'date', 'item_id', 'wholesale_price'};
T3.date = dateshift(T3.date, 'start', 'day');
fprintf('批发价记录: %d 条\n', height(T3));
fprintf('日期范围: %s ~ %s\n', datestr(min(T3.date)), datestr(max(T3.date)));

%% 四、读取附件4：损耗率
fprintf('\n--- 读取附件4：损耗率 ---\n');
% Sheet1: 单品损耗率
T4_item = readtable(fullfile(data_dir, '附件4.xlsx'), 'Sheet', 1, ...
    'VariableNamingRule', 'preserve');
T4_item.Properties.VariableNames = {'item_id', 'item_name', 'loss_rate'};
% Sheet2: 品类平均损耗率
T4_cat = readtable(fullfile(data_dir, '附件4.xlsx'), 'Sheet', 2, ...
    'VariableNamingRule', 'preserve');
T4_cat.Properties.VariableNames = {'cat_code', 'cat_name', 'avg_loss_rate'};
fprintf('单品损耗率: %d 条, 品类损耗率: %d 条\n', ...
    height(T4_item), height(T4_cat));

%% 五、数据合并：为每条销售记录附加商品信息
fprintf('\n--- 五、数据整合 ---\n');

% 构建单品→品类映射
item_to_cat = containers.Map('KeyType', 'char', 'ValueType', 'char');
item_to_catcode = containers.Map('KeyType', 'char', 'ValueType', 'char');
for i = 1:height(T1)
    key = char(T1.item_id(i));
    item_to_cat(key) = char(T1.cat_name(i));
    item_to_catcode(key) = char(T1.cat_code(i));
end

% 构建单品→损耗率映射
item_to_loss = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:height(T4_item)
    key = char(T4_item.item_id(i));
    item_to_loss(key) = T4_item.loss_rate(i) / 100;  % 转为小数
end

% 对未匹配的单品使用品类平均损耗率
cat_loss_map = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:height(T4_cat)
    cat_loss_map(char(T4_cat.cat_code(i))) = T4_cat.avg_loss_rate(i) / 100;
end

%% 六、按日期+单品汇总日销售数据
fprintf('\n--- 六、汇总日销售数据 ---\n');

% 批量附加品类和损耗率信息
T2.cat_name = repmat({''}, height(T2), 1);
T2.loss_rate = zeros(height(T2), 1);

% 转换 item_id 为 char 以加速查找
item_ids = cellstr(T2.item_id);
unique_items = unique(item_ids);
fprintf('在售单品数: %d\n', length(unique_items));

% 计算每条记录的品类和损耗率（分块处理）
n = height(T2);
chunk_size = 50000;
n_chunks = ceil(n / chunk_size);

for c = 1:n_chunks
    idx_start = (c-1)*chunk_size + 1;
    idx_end = min(c*chunk_size, n);
    chunk_ids = item_ids(idx_start:idx_end);

    cat_chunk = cell(length(chunk_ids), 1);
    loss_chunk = zeros(length(chunk_ids), 1);

    for i = 1:length(chunk_ids)
        if item_to_cat.isKey(chunk_ids{i})
            cat_chunk{i} = item_to_cat(chunk_ids{i});
        end
        if item_to_loss.isKey(chunk_ids{i})
            loss_chunk(i) = item_to_loss(chunk_ids{i});
        end
    end
    T2.cat_name(idx_start:idx_end) = cat_chunk;
    T2.loss_rate(idx_start:idx_end) = loss_chunk;

    if mod(c, 10) == 0
        fprintf('  处理进度: %d/%d\n', c, n_chunks);
    end
end

% 按日期+单品+品类汇总
fprintf('汇总日销售数据...\n');
[G, date_id, item_id, cat] = findgroups(T2.sale_date, T2.item_id, T2.cat_name);
daily_sales_kg = splitapply(@sum, T2.sales_kg, G);
avg_price = splitapply(@mean, T2.unit_price, G);
disc_count = splitapply(@sum, T2.is_disc, G);
trans_count = splitapply(@numel, T2.sales_kg, G);

T_daily = table(date_id, item_id, cat, trans_count, daily_sales_kg, ...
    avg_price, disc_count);
T_daily.Properties.VariableNames = {'date', 'item_id', 'cat_name', ...
    'trans_count', 'daily_sales_kg', 'avg_price', 'disc_count'};

% 计算打折比例
T_daily.disc_ratio = T_daily.disc_count ./ T_daily.trans_count;

% 附加损耗率（优先单品损耗率，缺失时回退到品类平均损耗率）
daily_loss = zeros(height(T_daily), 1);
daily_items = cellstr(T_daily.item_id);
loss_fallback_count = 0;
for i = 1:height(T_daily)
    if item_to_loss.isKey(daily_items{i})
        daily_loss(i) = item_to_loss(daily_items{i});
    elseif isKey(item_to_catcode, daily_items{i})
        % 回退到品类平均损耗率
        cat_code = item_to_catcode(daily_items{i});
        if cat_loss_map.isKey(cat_code)
            daily_loss(i) = cat_loss_map(cat_code);
            loss_fallback_count = loss_fallback_count + 1;
        end
    end
end
if loss_fallback_count > 0
    fprintf('  使用品类平均损耗率回退: %d 条记录\n', loss_fallback_count);
end
T_daily.loss_rate = daily_loss;

% 附加星期几
T_daily.day_of_week = weekday(T_daily.date);

fprintf('日汇总完成: %d 行\n', height(T_daily));

%% 七、按日期+品类汇总
fprintf('\n--- 七、汇总品类日数据 ---\n');
[G_cat, cat_date, cat_name_g] = findgroups(T_daily.date, T_daily.cat_name);
cat_total_kg = splitapply(@sum, T_daily.daily_sales_kg, G_cat);
cat_trans = splitapply(@sum, T_daily.trans_count, G_cat);
T_cat_daily = table(cat_date, cat_name_g, cat_total_kg, cat_trans);
T_cat_daily.Properties.VariableNames = {'date', 'cat_name', ...
    'cat_total_kg', 'cat_transactions'};

%% 八、与批发价关联
fprintf('\n--- 八、关联批发价格 ---\n');
% 构建 (日期,单品) → 批发价 映射
wp_map = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:height(T3)
    key = sprintf('%s_%s', datestr(T3.date(i), 'yyyymmdd'), char(T3.item_id(i)));
    wp_map(key) = T3.wholesale_price(i);
end

T_daily.wholesale_price = zeros(height(T_daily), 1);
daily_dates = T_daily.date;
daily_items_cell = cellstr(T_daily.item_id);
for i = 1:height(T_daily)
    key = sprintf('%s_%s', datestr(daily_dates(i), 'yyyymmdd'), daily_items_cell{i});
    if wp_map.isKey(key)
        T_daily.wholesale_price(i) = wp_map(key);
    end
end

% 统计批发价缺失情况（实际数据覆盖完整，缺失率约0%）
no_wp = T_daily.wholesale_price == 0;
fprintf('无批发价记录: %d/%d (%.1f%%)\n', sum(no_wp), height(T_daily), ...
    100*sum(no_wp)/height(T_daily));

%% 九、计算毛利相关指标
fprintf('\n--- 九、计算毛利指标 ---\n');
% 毛利率 = (售价 - 进价) / 售价
valid_wp = T_daily.wholesale_price > 0;
T_daily.gross_margin = zeros(height(T_daily), 1);
T_daily.gross_margin(valid_wp) = (T_daily.avg_price(valid_wp) - ...
    T_daily.wholesale_price(valid_wp)) ./ T_daily.avg_price(valid_wp);

% 加价率 = 售价 / 进价 - 1
T_daily.markup_rate = zeros(height(T_daily), 1);
T_daily.markup_rate(valid_wp) = T_daily.avg_price(valid_wp) ./ ...
    T_daily.wholesale_price(valid_wp) - 1;

%% 十、保存预处理结果
fprintf('\n--- 十、保存结果 ---\n');

% 只保存关键变量
save(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1', 'T2', 'T3', 'T4_item', 'T4_cat', ...
    'T_daily', 'T_cat_daily', 'item_to_cat', 'item_to_loss', 'cats');

fprintf('预处理数据已保存到 preprocessed_data.mat\n');
fprintf('数据预处理完成!\n');
