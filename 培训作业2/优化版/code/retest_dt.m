%% 重跑DT：多次随机种子 + 多种CV划分，验证能否达100%
clc;
fprintf('=============================================================\n');
fprintf(' DT 多次重跑：检查未风化样本能否达到100%%\n');
fprintf('=============================================================\n');

base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'X2_norm', 'comp_names', 'T2_proc');

comp_labels = {'SiO_2','Na_2O','K_2O','CaO','MgO','Al_2O_3', ...
    'Fe_2O_3','CuO','PbO','BaO','P_2O_5','SrO','SnO_2','SO_2'};

% 未风化样本
idx = T2_proc.WEAT_num == 0;
X = X2_norm(idx, :);
y = categorical(T2_proc.TYPE_num(idx), [0 1], {'高钾','铅钡'});
n = size(X, 1);
fprintf('\n未风化样本: n=%d (高钾=%d, 铅钡=%d)\n', n, sum(y=='高钾'), sum(y=='铅钡'));

%% 测试1：不同随机种子
fprintf('\n====== 测试1: 不同随机种子 (默认超参数) ======\n');
seeds = 0:29;
acc_list = zeros(length(seeds), 1);
best_acc = 0; best_seed = 0;

for i = 1:length(seeds)
    rng(seeds(i));
    cv = cvpartition(y, 'KFold', 5);
    mdl = fitctree(X, y, 'PredictorNames', comp_labels);
    loss = kfoldLoss(crossval(mdl, 'CVPartition', cv));
    acc = (1 - loss) * 100;
    acc_list(i) = acc;
    if acc > best_acc
        best_acc = acc; best_seed = seeds(i);
    end
end

fprintf('默认超参数 DT, 30次不同种子:\n');
fprintf('  最高: %.2f%% (seed=%d)\n', best_acc, best_seed);
fprintf('  最低: %.2f%%\n', min(acc_list));
fprintf('  均值: %.2f%%\n', mean(acc_list));
fprintf('  达成100%%次数: %d/30\n', sum(acc_list == 100));

%% 测试2：不同CV划分 + 超参数优化
fprintf('\n====== 测试2: 超参数优化 + 不同CV划分 ======\n');
n_trials = 20;
opt_acc_list = zeros(n_trials, 1);
opt_100_count = 0;

for t = 1:n_trials
    rng(t);
    cv = cvpartition(y, 'KFold', 5);

    % 超参数优化 DT
    mdl = fitctree(X, y, ...
        'PredictorNames', comp_labels, ...
        'OptimizeHyperparameters', 'auto', ...
        'HyperparameterOptimizationOptions', ...
        struct('AcquisitionFunctionName','expected-improvement-plus', ...
               'MaxObjectiveEvaluations', 30, ...
               'ShowPlots', false, 'Verbose', 0));

    loss = kfoldLoss(crossval(mdl, 'CVPartition', cv));
    acc = (1 - loss) * 100;
    opt_acc_list(t) = acc;
    if acc == 100
        opt_100_count = opt_100_count + 1;
    end

    if mod(t, 5) == 0
        fprintf('  已完成 %d/20...\n', t);
    end
end

fprintf('超参数优化 DT, 20次不同CV+种子:\n');
fprintf('  最高: %.2f%%\n', max(opt_acc_list));
fprintf('  最低: %.2f%%\n', min(opt_acc_list));
fprintf('  均值: %.2f%%\n', mean(opt_acc_list));
fprintf('  达成100%%次数: %d/20\n', opt_100_count);

%% 测试3：留一法 (LOOCV)
fprintf('\n====== 测试3: 留一法 (LOOCV) ======\n');
rng(42);
mdl_loo = fitctree(X, y, 'PredictorNames', comp_labels);
cv_loo = cvpartition(y, 'Leaveout');
loss_loo = kfoldLoss(crossval(mdl_loo, 'CVPartition', cv_loo));
acc_loo = (1 - loss_loo) * 100;
fprintf('默认DT 留一法准确率: %.2f%%\n', acc_loo);

% 超参数优化 + LOOCV
mdl_loo_opt = fitctree(X, y, ...
    'PredictorNames', comp_labels, ...
    'OptimizeHyperparameters', 'auto', ...
    'HyperparameterOptimizationOptions', ...
    struct('AcquisitionFunctionName','expected-improvement-plus', ...
           'MaxObjectiveEvaluations', 30, ...
           'ShowPlots', false, 'Verbose', 0));
loss_loo_opt = kfoldLoss(crossval(mdl_loo_opt, 'CVPartition', cv_loo));
acc_loo_opt = (1 - loss_loo_opt) * 100;
fprintf('优化DT 留一法准确率: %.2f%%\n', acc_loo_opt);

%% 测试4：检查误分类样本
fprintf('\n====== 测试4: 哪些样本被DT分错 ======\n');
rng(42);
cv = cvpartition(y, 'KFold', 5);
for fold = 1:5
    train_idx = find(training(cv, fold));
    test_idx = find(test(cv, fold));
    mdl = fitctree(X(train_idx,:), y(train_idx), 'PredictorNames', comp_labels);
    y_pred = predict(mdl, X(test_idx,:));
    y_true = y(test_idx);
    misclass = find(y_pred ~= y_true);

    if ~isempty(misclass)
        fprintf('Fold %d: 误分类样本:\n', fold);
        orig_idx_all = find(idx);
        for m = 1:length(misclass)
            sample_no = orig_idx_all(test_idx(misclass(m)));
            fprintf('  采样点#%d: 真值=%s, 预测=%s\n', sample_no, ...
                string(y_true(misclass(m))), string(y_pred(misclass(m))));
            fprintf('    成分: PbO=%.4f, BaO=%.4f, K2O=%.4f, SiO2=%.4f\n', ...
                X(test_idx(misclass(m)), 9), X(test_idx(misclass(m)), 10), ...
                X(test_idx(misclass(m)), 3), X(test_idx(misclass(m)), 1));
        end
    else
        fprintf('Fold %d: 无误分类\n', fold);
    end
end

%% 测试5：风化样本 DT 深度分析
fprintf('\n====== 测试5: 风化样本DT (n=42)深度分析 ======\n');
idx_w = T2_proc.WEAT_num == 1;
X_w = X2_norm(idx_w, :);
y_w = categorical(T2_proc.TYPE_num(idx_w), [0 1], {'高钾','铅钡'});
fprintf('风化样本: n=%d (高钾=%d, 铅钡=%d)\n', size(X_w,1), sum(y_w=='高钾'), sum(y_w=='铅钡'));

% 检查是否一个特征就能完美分开
fprintf('\n单特征分裂能力:\n');
for j = 1:14
    Xj = X_w(:, j);
    % 尝试找最佳分裂点
    [sorted_x, sort_idx] = sort(Xj);
    sorted_y = y_w(sort_idx);
    for s = 1:(length(sorted_x)-1)
        left = sorted_y(1:s);
        right = sorted_y(s+1:end);
        if all(left == left(1)) && all(right == right(1)) && left(1) ~= right(1)
            fprintf('  %s: 在 x=%.4f 处完美分裂!\n', comp_labels{j}, ...
                (sorted_x(s) + sorted_x(s+1)) / 2);
            break;
        end
    end
end

fprintf('\n=============================================================\n');
fprintf(' 重跑完成\n');
fprintf('=============================================================\n');
