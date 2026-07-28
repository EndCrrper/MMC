%% 古代玻璃成分分析与鉴别 —— 数据预处理
% 2022 CUMCM C题
% 功能：读取附件.xlsx三张表单，进行数据清洗、编码、CLR变换
% 可独立运行：preprocess
%
% 输出：
%   cleaned_data.csv   —— 预处理后数据
%   预处理对比图（成分分布箱线图）

%% 初始化
clc;  % 不使用clear以保持load/save共享数据
fprintf('=============================================================\n');
fprintf('古代玻璃成分分析与鉴别 —— 数据预处理\n');
fprintf('=============================================================\n');

% 路径设置（相对路径）
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
fig_dir = fullfile(result_dir, 'figures');
if ~exist(result_dir, 'dir'), mkdir(result_dir); end
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% 附件路径
attach_path = fullfile(base_dir, '..', '..', 'cumcm2022c', '附件.xlsx');
if ~exist(attach_path, 'file')
    % 备选路径
    attach_path = fullfile(base_dir, '..', '..', '2022C参考', '附件.xlsx');
end
fprintf('数据源: %s\n', attach_path);

%% ==================== 一、读取原始数据 ====================
fprintf('\n--- 一、读取原始数据 ---\n');

% 表单1：文物表面信息
opts1 = spreadsheetImportOptions('NumVariables', 4);
opts1.Sheet = 1;
opts1.DataRange = 'B2:E59';
opts1.VariableNames = {'ORNA', 'TYPE', 'COLOR', 'WEAT'};
opts1.VariableTypes = {'string', 'string', 'string', 'string'};
opts1 = setvaropts(opts1, {'ORNA', 'TYPE', 'COLOR', 'WEAT'}, 'EmptyFieldRule', 'auto');
T1 = readtable(attach_path, opts1, 'UseExcel', false);
fprintf('表单1 读取完成: %d 行, 文物表面信息\n', height(T1));

% 表单2：化学成分数据（69个采样点）
opts2 = spreadsheetImportOptions('NumVariables', 15);
opts2.Sheet = 2;
opts2.DataRange = 'A2:O70';
opts2.VariableNames = {'SAMPLE_ID', 'SiO2', 'Na2O', 'K2O', 'CaO', 'MgO', ...
    'Al2O3', 'Fe2O3', 'CuO', 'PbO', 'BaO', 'P2O5', 'SrO', 'SnO2', 'SO2'};
opts2.VariableTypes = {'string', 'double', 'double', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'};
opts2 = setvaropts(opts2, {'SiO2', 'Na2O', 'K2O', 'CaO', 'MgO', ...
    'Al2O3', 'Fe2O3', 'CuO', 'PbO', 'BaO', 'P2O5', 'SrO', 'SnO2', 'SO2'}, 'FillValue', 0);
T2_raw = readtable(attach_path, opts2, 'UseExcel', false);
fprintf('表单2 读取完成: %d 行, %d 种化学成分\n', height(T2_raw), width(T2_raw)-1);

% 表单3：待预测样本
opts3 = spreadsheetImportOptions('NumVariables', 16);
opts3.Sheet = 3;
opts3.DataRange = 'A2:P9';
opts3.VariableNames = {'SAMPLE_ID', 'WEAT', 'SiO2', 'Na2O', 'K2O', 'CaO', 'MgO', ...
    'Al2O3', 'Fe2O3', 'CuO', 'PbO', 'BaO', 'P2O5', 'SrO', 'SnO2', 'SO2'};
opts3.VariableTypes = {'string', 'string', 'double', 'double', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'};
opts3 = setvaropts(opts3, {'SiO2', 'Na2O', 'K2O', 'CaO', 'MgO', ...
    'Al2O3', 'Fe2O3', 'CuO', 'PbO', 'BaO', 'P2O5', 'SrO', 'SnO2', 'SO2'}, 'FillValue', 0);
T3_raw = readtable(attach_path, opts3, 'UseExcel', false);
fprintf('表单3 读取完成: %d 行, 未知样本\n', height(T3_raw));

%% ==================== 二、表单1预处理：类别变量编码 ====================
fprintf('\n--- 二、表单1预处理 ---\n');

% 创建副本
T1_proc = T1;

% 纹饰编码: A→0, B→1, C→2
T1_proc.ORNA = categorical(cellstr(T1_proc.ORNA));
orna_levels = categories(T1_proc.ORNA);
fprintf('纹饰类别: %s\n', strjoin(orna_levels, ', '));
T1_proc.ORNA_num = double(categorical(cellstr(T1_proc.ORNA))) - 1;

% 类型编码: 高钾→0, 铅钡→1
T1_proc.TYPE = categorical(cellstr(T1_proc.TYPE));
type_levels = categories(T1_proc.TYPE);
fprintf('玻璃类型: %s\n', strjoin(type_levels, ', '));
T1_proc.TYPE_num = double(categorical(cellstr(T1_proc.TYPE))) - 1;

% 颜色编码
% 先处理缺失值：用众数填充
color_str = cellstr(T1_proc.COLOR);
missing_color = ismissing(T1_proc.COLOR) | strcmp(color_str, '') | strcmp(color_str, 'NaN');
if any(missing_color)
    valid_colors = color_str(~missing_color);
    % 手动计算众数
    [unique_colors, ~, ic] = unique(valid_colors);
    counts = accumarray(ic, 1);
    [~, max_idx] = max(counts);
    mode_color = unique_colors{max_idx};
    color_str(missing_color) = {mode_color};
    T1_proc.COLOR = categorical(color_str);
    fprintf('颜色缺失值: %d 个, 已用众数 "%s" 填充\n', sum(missing_color), mode_color);
end
T1_proc.COLOR_cat = categorical(cellstr(T1_proc.COLOR));
color_levels = categories(T1_proc.COLOR_cat);
fprintf('颜色类别: %s\n', strjoin(color_levels, ', '));
T1_proc.COLOR_num = double(categorical(cellstr(T1_proc.COLOR))) - 1;

% 风化编码: 无风化→0, 风化→1
T1_proc.WEAT = categorical(cellstr(T1_proc.WEAT));
weat_levels = categories(T1_proc.WEAT);
fprintf('风化状态: %s\n', strjoin(weat_levels, ', '));
T1_proc.WEAT_num = double(categorical(cellstr(T1_proc.WEAT))) - 1;

fprintf('表单1编码完成: 纹饰(%d类), 类型(%d类), 颜色(%d类), 风化(%d类)\n', ...
    length(orna_levels), length(type_levels), length(color_levels), length(weat_levels));

%% ==================== 三、表单2预处理：成分数据清洗 ====================
fprintf('\n--- 三、表单2预处理 ---\n');

% 提取文物编号（去除部位/风化点标记）
sample_ids = cellstr(T2_raw.SAMPLE_ID);
artifact_nums = zeros(length(sample_ids), 1);
for i = 1:length(sample_ids)
    sid = sample_ids{i};
    % 提取开头数字部分
    num_part = regexp(sid, '^\d+', 'match');
    if ~isempty(num_part)
        artifact_nums(i) = str2double(num_part{1});
    else
        artifact_nums(i) = NaN;
    end
end

% 成分矩阵（14种氧化物）
comp_names = {'SiO2', 'Na2O', 'K2O', 'CaO', 'MgO', 'Al2O3', ...
    'Fe2O3', 'CuO', 'PbO', 'BaO', 'P2O5', 'SrO', 'SnO2', 'SO2'};
X2_raw = T2_raw{:, 2:15};

% 零值替换：零值→eps（成分数据不允许零）
n_zeros = sum(X2_raw(:) == 0);
X2_raw(X2_raw == 0) = eps;
fprintf('零值替换: %d 个零值 → eps(≈%.2e)\n', n_zeros, eps);

% 无效数据标注：成分总和超出[85, 105]范围的采样点
comp_sums_raw = sum(X2_raw, 2);
invalid_mask = (comp_sums_raw < 85) | (comp_sums_raw > 105);
fprintf('成分总和范围检查: [%.2f, %.2f]%%\n', min(comp_sums_raw), max(comp_sums_raw));
if any(invalid_mask)
    fprintf('  警告: %d 个采样点总和超出[85,105]范围\n', sum(invalid_mask));
end

% 归一化：使每个样本总和为100%
X2_norm = 100 * X2_raw ./ sum(X2_raw, 2);

% 中心对数比(CLR)变换：打破成分数据的定和约束
% z_i = log(x_i / g(x)), 其中g(x)是几何均值
X2_clr = zeros(size(X2_norm));
for i = 1:size(X2_norm, 1)
    row = X2_norm(i, :);
    gm = geomean(row(row > 0));  % 几何均值（排除零值）
    X2_clr(i, :) = log(row ./ gm);
end

% 缺失值处理：NaN用对应列的均值填充
nan_count = sum(isnan(X2_clr(:)));
if nan_count > 0
    col_means = mean(X2_clr, 1, 'omitnan');
    for j = 1:size(X2_clr, 2)
        col_nan = isnan(X2_clr(:, j));
        if any(col_nan)
            X2_clr(col_nan, j) = col_means(j);
        end
    end
    fprintf('缺失值填充: %d 个NaN → 列均值(CLR空间)\n', nan_count);
end

% 关联表单1的类型和风化信息
T2_proc = table(artifact_nums, sample_ids);
T2_proc.ARTIFACT_NUM = artifact_nums;
T2_proc.SAMPLE_ID = string(sample_ids);

% 匹配类型和风化
T2_proc.TYPE = repmat("", height(T2_proc), 1);
T2_proc.TYPE_num = zeros(height(T2_proc), 1);
T2_proc.WEAT = repmat("", height(T2_proc), 1);
T2_proc.WEAT_num = zeros(height(T2_proc), 1);

for i = 1:height(T2_proc)
    an = T2_proc.ARTIFACT_NUM(i);
    match_row = find((1:height(T1_proc))' == an, 1);
    if ~isempty(match_row)
        T2_proc.TYPE(i) = string(T1_proc.TYPE(match_row));
        T2_proc.TYPE_num(i) = T1_proc.TYPE_num(match_row);
        T2_proc.WEAT(i) = string(T1_proc.WEAT(match_row));
        T2_proc.WEAT_num(i) = T1_proc.WEAT_num(match_row);
    end
end

% 检查匹配情况
unmatched = T2_proc.TYPE == "" | ismissing(T2_proc.TYPE);
fprintf('表单1-2匹配: %d/%d 匹配成功 (%d未匹配)\n', ...
    sum(~unmatched), height(T2_proc), sum(unmatched));

% 合并CLR变换后的成分数据
X2_table = array2table(X2_clr, 'VariableNames', comp_names);
X2_norm_table = array2table(X2_norm, 'VariableNames', comp_names);
T2_merged = [T2_proc, X2_table];

fprintf('表单2预处理完成: %d采样点, CLR变换后有NaN=%d\n', ...
    height(T2_merged), sum(isnan(table2array(X2_table)), 'all'));

%% ==================== 四、表单3预处理 ====================
fprintf('\n--- 四、表单3预处理 ---\n');

% 成分矩阵
X3_raw = T3_raw{:, 3:16};

% 零值替换
X3_raw(X3_raw == 0) = eps;

% 风化编码
T3_proc = T3_raw;
weat3_str = cellstr(T3_proc.WEAT);
T3_proc.WEAT_num = zeros(length(weat3_str), 1);
for i = 1:length(weat3_str)
    if contains(weat3_str{i}, '风化') && ~contains(weat3_str{i}, '无')
        T3_proc.WEAT_num(i) = 1;
    end
end

% 归一化 → CLR变换
X3_norm = 100 * X3_raw ./ sum(X3_raw, 2);
X3_clr = zeros(size(X3_norm));
for i = 1:size(X3_norm, 1)
    row = X3_norm(i, :);
    gm = geomean(row(row > 0));
    X3_clr(i, :) = log(row ./ gm);
end

% NaN填充
if any(isnan(X3_clr(:)))
    col_means3 = mean(X3_clr, 1, 'omitnan');
    for j = 1:size(X3_clr, 2)
        col_nan = isnan(X3_clr(:, j));
        if any(col_nan)
            X3_clr(col_nan, j) = col_means3(j);
        end
    end
end

fprintf('表单3预处理完成: %d 个未知样本\n', height(T3_proc));

%% ==================== 五、绘图：预处理对比 ====================
fprintf('\n--- 五、生成预处理对比图 ---\n');

% 图1：主要成分含量箱线图（高钾 vs 铅钡，选4种关键成分）
figure('Position', [100, 100, 1600, 600]);
high_k_idx = T2_proc.TYPE_num == 0;
pb_idx = T2_proc.TYPE_num == 1;

% 选取关键成分：SiO2(1), K2O(3), PbO(9), BaO(10)
key_comp_idx = [1, 3, 9, 10];  % SiO2, K2O, PbO, BaO
key_comp_names = comp_names(key_comp_idx);

for p = 1:4
    subplot(1, 4, p);
    j = key_comp_idx(p);
    boxplot([X2_norm(high_k_idx, j); X2_norm(pb_idx, j)], ...
        [repmat({'高钾'}, sum(high_k_idx), 1); repmat({'铅钡'}, sum(pb_idx), 1)]);
    title(key_comp_names{p}, 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('归一化含量 (%)');
    grid on;
end
sgtitle('关键成分分布对比（归一化后）', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(fig_dir, 'preprocess_comparison.png'));
print(gcf, fullfile(fig_dir, 'preprocess_comparison_300.png'), '-dpng', '-r300');
close(gcf);

% 图2：缺失值热力图（预处理前后）
figure('Position', [100, 100, 1400, 500]);

subplot(1, 2, 1);
nan_before = isnan(T2_raw{:, 2:15}) | (T2_raw{:, 2:15} == 0);
imagesc(nan_before);
colormap(gca, [0.95 0.95 0.95; 0.8 0.2 0.2]);
title('预处理前：缺失/零值分布（红色=缺失/零值）', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('化学成分'); ylabel('采样点');
set(gca, 'XTick', 1:14, 'XTickLabel', comp_names, 'XTickLabelRotation', 45);
colorbar('off');

subplot(1, 2, 2);
nan_after = isnan(X2_clr);
imagesc(nan_after);
colormap(gca, [0.95 0.95 0.95; 0.2 0.6 0.2]);
title('预处理后：缺失值分布（绿色=缺失）', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('化学成分'); ylabel('采样点');
set(gca, 'XTick', 1:14, 'XTickLabel', comp_names, 'XTickLabelRotation', 45);
colorbar('off');

sgtitle('缺失值处理前后对比', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(fig_dir, 'preprocess_missing.png'));
print(gcf, fullfile(fig_dir, 'preprocess_missing_300.png'), '-dpng', '-r300');
close(gcf);

fprintf('预处理图1-2已保存到 result/figures/\n');

%% ==================== 六、保存预处理结果 ====================
fprintf('\n--- 六、保存预处理结果 ---\n');

% 保存为CSV（MAT格式也保存）
% 保存完整预处理结果
% 表单1编码结果
T1_save = table((1:height(T1_proc))', T1_proc.ORNA_num, T1_proc.TYPE_num, ...
    T1_proc.COLOR_num, T1_proc.WEAT_num, ...
    'VariableNames', {'文物编号', '纹饰_编码', '类型_编码', '颜色_编码', '风化_编码'});
writetable(T1_save, fullfile(result_dir, 'form1_encoded.csv'));

% 表单2 CLR数据 + 元信息
T2_full = [T2_proc(:, {'ARTIFACT_NUM', 'TYPE_num', 'WEAT_num'}), X2_table];
writetable(T2_full, fullfile(result_dir, 'form2_clr.csv'));

% 表单2归一化数据
T2_norm_full = [T2_proc(:, {'ARTIFACT_NUM', 'TYPE_num', 'WEAT_num'}), X2_norm_table];
writetable(T2_norm_full, fullfile(result_dir, 'form2_normalized.csv'));

% 表单3 CLR数据
T3_save = [T3_proc(:, {'SAMPLE_ID', 'WEAT'}), ...
    array2table(X3_clr, 'VariableNames', comp_names)];
writetable(T3_save, fullfile(result_dir, 'form3_clr.csv'));

% 保存所有预处理数据的MAT文件
save(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1_proc', 'T2_merged', 'T3_proc', ...
    'X2_clr', 'X2_norm', 'X2_raw', 'X3_clr', 'X3_norm', 'X3_raw', ...
    'comp_names', 'T2_proc');

% 保存汇总cleaned_data
% 合并表单2的元信息和CLR数据
all_data = [T2_proc(:, {'ARTIFACT_NUM', 'TYPE_num', 'WEAT_num'}), X2_table];
writetable(all_data, fullfile(result_dir, 'cleaned_data.csv'));

fprintf('预处理结果已保存:\n');
fprintf('  %s\n', fullfile(result_dir, 'cleaned_data.csv'));
fprintf('  %s\n', fullfile(result_dir, 'preprocessed_data.mat'));
fprintf('  form1_encoded.csv, form2_clr.csv, form2_normalized.csv, form3_clr.csv\n');

fprintf('\n=============================================================\n');
fprintf('数据预处理完成!\n');
fprintf('=============================================================\n');
