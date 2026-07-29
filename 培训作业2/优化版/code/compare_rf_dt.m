%% 对比：决策树(DT) vs 随机森林(RF) vs SVM vs LDA
% 加载预处理数据，输出四种分类器的对比结果
clc;
fprintf('================================================================\n');
fprintf(' 分类器对比：DT | RF | SVM | LDA\n');
fprintf('================================================================\n');

% 加载数据
base_dir = fileparts(mfilename('fullpath'));
result_dir = fullfile(base_dir, '..', 'result');
load(fullfile(result_dir, 'preprocessed_data.mat'), ...
    'T1_proc', 'T2_merged', 'X2_clr', 'X2_norm', 'X2_raw', 'comp_names', 'T2_proc');

comp_labels = {'SiO_2','Na_2O','K_2O','CaO','MgO','Al_2O_3', ...
    'Fe_2O_3','CuO','PbO','BaO','P_2O_5','SrO','SnO_2','SO_2'};

fprintf('\n数据加载完成: %d个样本, %d个特征\n', size(X2_norm,1), size(X2_norm,2));

%% 分别对未风化/风化样本进行四种分类器对比
rng(42);  % 固定随机种子

for weat_state = 0:1
    state_name = iif(weat_state==0, '未风化', '风化');
    fprintf('\n========== %s样本 (n=%d) ==========\n', state_name, sum(T2_proc.WEAT_num==weat_state));

    % 筛选数据
    idx = T2_proc.WEAT_num == weat_state;
    X = X2_norm(idx, :);
    y = categorical(T2_proc.TYPE_num(idx), [0 1], {'高钾','铅钡'});

    n = size(X, 1);
    fprintf('  类别分布: 高钾=%d, 铅钡=%d\n', sum(y=='高钾'), sum(y=='铅钡'));

    % -------- 1. 决策树 (DT) --------
    fprintf('\n--- 1. 决策树 (DT) ---\n');
    dt_mdl = fitctree(X, y, ...
        'PredictorNames', comp_labels, ...
        'OptimizeHyperparameters', 'auto', ...
        'HyperparameterOptimizationOptions', ...
        struct('AcquisitionFunctionName','expected-improvement-plus', ...
               'MaxObjectiveEvaluations',30, 'ShowPlots',false, 'Verbose',0));
    dt_cv = crossval(dt_mdl, 'KFold', 5);
    dt_loss = kfoldLoss(dt_cv);
    dt_acc = (1 - dt_loss) * 100;
    fprintf('  5折CV准确率: %.2f%%\n', dt_acc);

    % 特征重要性
    dt_imp = predictorImportance(dt_mdl);
    [~, dt_imp_idx] = sort(dt_imp, 'descend');
    fprintf('  Top3特征: ');
    for k = 1:3
        fprintf('%s(%.3f)  ', comp_labels{dt_imp_idx(k)}, dt_imp(dt_imp_idx(k)));
    end
    fprintf('\n');

    % 输出分类规则（前3层）
    fprintf('  决策树结构: 节点数=%d, 叶节点数=%d\n', ...
        dt_mdl.NumNodes, length(find(dt_mdl.IsBranchNode==0)));

    % -------- 2. 随机森林 (RF) --------
    fprintf('\n--- 2. 随机森林 (RF) ---\n');

    % TreeBagger 需要数值标签
    y_num = T2_proc.TYPE_num(idx);

    % 尝试不同树数量的RF
    nTrees_list = [50, 100, 200];
    best_rf_acc = 0;
    best_nTrees = 50;

    for nTrees = nTrees_list
        rf_mdl = TreeBagger(nTrees, X, y_num, ...
            'Method', 'classification', ...
            'OOBPrediction', 'on', ...
            'PredictorNames', comp_labels, ...
            'MinLeafSize', max(1, floor(n/10)));

        % OOB误差
        oob_err = oobError(rf_mdl);
        oob_acc = (1 - oob_err(end)) * 100;

        % 5折CV（手写，因为TreeBagger没有crossval方法）
        cv_mdl = fitcensemble(X, y_num, 'Method', 'Bag', 'NumLearningCycles', nTrees, ...
            'Learners', templateTree('MinLeafSize', max(1, floor(n/10))), ...
            'KFold', 5);
        cv_loss = kfoldLoss(cv_mdl);
        cv_acc = (1 - cv_loss) * 100;

        fprintf('  nTrees=%d: OOB准确率=%.2f%%, 5折CV准确率=%.2f%%\n', nTrees, oob_acc, cv_acc);

        if cv_acc > best_rf_acc
            best_rf_acc = cv_acc;
            best_nTrees = nTrees;
        end
    end

    fprintf('  最佳RF: nTrees=%d, CV准确率=%.2f%%\n', best_nTrees, best_rf_acc);

    % 用最佳参数训练最终RF模型
    rf_final = TreeBagger(best_nTrees, X, y_num, ...
        'Method', 'classification', ...
        'OOBPrediction', 'on', ...
        'OOBPredictorImportance', 'on', ...
        'PredictorNames', comp_labels, ...
        'MinLeafSize', max(1, floor(n/10)));

    % RF特征重要性
    rf_imp = rf_final.OOBPermutedPredictorDeltaError;
    [rf_imp_sorted, rf_imp_idx] = sort(rf_imp, 'descend');
    fprintf('  RF Top3特征: ');
    for k = 1:3
        fprintf('%s(%.3f)  ', comp_labels{rf_imp_idx(k)}, rf_imp_sorted(k));
    end
    fprintf('\n');

    % -------- 3. SVM (RBF核) --------
    fprintf('\n--- 3. SVM (RBF核) ---\n');
    try
        svm_mdl = fitcsvm(X, y, ...
            'KernelFunction', 'RBF', ...
            'OptimizeHyperparameters', 'auto', ...
            'HyperparameterOptimizationOptions', ...
            struct('AcquisitionFunctionName','expected-improvement-plus', ...
                   'MaxObjectiveEvaluations',30, 'ShowPlots',false, 'Verbose',0));
        svm_cv = crossval(svm_mdl, 'KFold', 5);
        svm_loss = kfoldLoss(svm_cv);
        svm_acc = (1 - svm_loss) * 100;
        fprintf('  5折CV准确率: %.2f%%\n', svm_acc);
        try
            gamma_val = 1 / svm_mdl.KernelParameters.Scale^2;
        catch
            gamma_val = NaN;
        end
        fprintf('  最优超参数: C=%.3f, Gamma=%.4f\n', ...
            svm_mdl.BoxConstraints(1), gamma_val);
    catch ME
        fprintf('  SVM训练失败: %s\n', ME.message);
        svm_acc = NaN;
    end

    % -------- 4. LDA --------
    fprintf('\n--- 4. 线性判别分析 (LDA) ---\n');
    try
        lda_mdl = fitcdiscr(X, y);
        lda_cv = crossval(lda_mdl, 'KFold', 5);
        lda_loss = kfoldLoss(lda_cv);
        lda_acc = (1 - lda_loss) * 100;
        fprintf('  5折CV准确率: %.2f%%\n', lda_acc);
        fprintf('  判别函数数: %d\n', lda_mdl.NumCoeffs);
    catch ME
        % LDA对小样本可能不稳定，尝试带正则化
        try
            lda_mdl = fitcdiscr(X, y, 'DiscrimType', 'pseudoLinear');
            lda_cv = crossval(lda_mdl, 'KFold', 5);
            lda_loss = kfoldLoss(lda_cv);
            lda_acc = (1 - lda_loss) * 100;
            fprintf('  5折CV准确率(pseudo): %.2f%%\n', lda_acc);
        catch ME2
            fprintf('  LDA训练失败: %s\n', ME2.message);
            lda_acc = NaN;
        end
    end

    % ======== 汇总 ========
    fprintf('\n========== %s 汇总 ==========\n', state_name);
    fprintf('%-20s %10s %10s\n', '分类器', '5折CV准确率', '宏平均F1');
    fprintf('%-20s %10s %10s\n', '--------------------', '----------', '----------');

    % 计算各分类器的宏平均F1
    dt_f1 = compute_cv_f1(dt_cv, X, y);
    rf_f1 = compute_cv_f1_rf(X, y_num, best_nTrees);
    if ~isnan(svm_acc)
        svm_f1 = compute_cv_f1(svm_cv, X, y);
    else
        svm_f1 = NaN;
    end
    if ~isnan(lda_acc)
        lda_f1 = compute_cv_f1(lda_cv, X, y);
    else
        lda_f1 = NaN;
    end

    fprintf('%-20s %8.2f%% %8.3f\n', '决策树 (DT)', dt_acc, dt_f1);
    fprintf('%-20s %8.2f%% %8.3f\n', sprintf('随机森林 (RF,n=%d)', best_nTrees), best_rf_acc, rf_f1);
    fprintf('%-20s %8.2f%% %8.3f\n', 'SVM (RBF核)', svm_acc, svm_f1);
    fprintf('%-20s %8.2f%% %8.3f\n', 'LDA', lda_acc, lda_f1);

    % 胜出者
    accs = [dt_acc, best_rf_acc, svm_acc, lda_acc];
    names = {'DT','RF','SVM','LDA'};
    [best, best_i] = max(accs);
    fprintf('\n  最佳分类器: %s (%.2f%%)\n', names{best_i}, best);
    fprintf('  非线性(DT/RF/SVM)均值: %.2f%%\n', mean(accs(1:3), 'omitnan'));
end

%% 特征重要性对比图
fprintf('\n====== 特征重要性对比: DT vs RF ======\n');
for weat_state = 0:1
    state_name = iif(weat_state==0, '未风化', '风化');
    idx = T2_proc.WEAT_num == weat_state;
    X = X2_norm(idx, :);
    y_num = T2_proc.TYPE_num(idx);
    y = categorical(y_num, [0 1], {'高钾','铅钡'});
    n = size(X, 1);

    % DT
    dt_mdl = fitctree(X, y, 'PredictorNames', comp_labels);
    dt_imp = predictorImportance(dt_mdl);

    % RF
    rf_mdl = TreeBagger(100, X, y_num, 'Method', 'classification', ...
        'OOBPrediction', 'on', 'OOBPredictorImportance', 'on', ...
        'MinLeafSize', max(1, floor(n/10)));
    rf_imp = rf_mdl.OOBPermutedPredictorDeltaError;
    rf_imp = rf_imp(:)';  % ensure row vector

    % 打印排名
    fprintf('\n【%s】特征重要性排名 (Top 8)\n', state_name);
    fprintf('%-6s %-12s %-12s\n', '排名', 'DT', 'RF');
    fprintf('%-6s %-12s %-12s\n', '----', '------------', '------------');

    [~, dt_order] = sort(dt_imp, 'descend');
    [~, rf_order] = sort(rf_imp, 'descend');
    for k = 1:min(8, length(comp_labels))
        fprintf('%-6d %-12s %-12s\n', k, comp_labels{dt_order(k)}, comp_labels{rf_order(k)});
    end
end

fprintf('\n================================================================\n');
fprintf(' 对比分析完成!\n');
fprintf('================================================================\n');

%% 辅助函数
function f1 = compute_cv_f1(cv_mdl, X, y)
    % 从已训练的CV模型计算宏平均F1
    y_pred = kfoldPredict(cv_mdl);
    classes = categories(y);
    f1_scores = zeros(length(classes), 1);
    for c = 1:length(classes)
        tp = sum((y_pred == classes{c}) & (y == classes{c}));
        fp = sum((y_pred == classes{c}) & (y ~= classes{c}));
        fn = sum((y_pred ~= classes{c}) & (y == classes{c}));
        if tp + fp > 0, prec = tp / (tp + fp); else, prec = 0; end
        if tp + fn > 0, rec = tp / (tp + fn); else, rec = 0; end
        if prec + rec > 0, f1_scores(c) = 2 * prec * rec / (prec + rec); end
    end
    f1 = mean(f1_scores);
end

function f1 = compute_cv_f1_rf(X, y_num, nTrees)
    % 对RF使用fitcensemble的KFold分区计算F1
    cv_mdl = fitcensemble(X, y_num, 'Method', 'Bag', 'NumLearningCycles', nTrees, ...
        'KFold', 5);
    y_pred = kfoldPredict(cv_mdl);
    f1_scores = zeros(2, 1);
    for c = 0:1
        tp = sum((y_pred == c) & (y_num == c));
        fp = sum((y_pred == c) & (y_num ~= c));
        fn = sum((y_pred ~= c) & (y_num == c));
        if tp + fp > 0, prec = tp / (tp + fp); else, prec = 0; end
        if tp + fn > 0, rec = tp / (tp + fn); else, rec = 0; end
        if prec + rec > 0, f1_scores(c+1) = 2 * prec * rec / (prec + rec); end
    end
    f1 = mean(f1_scores);
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
