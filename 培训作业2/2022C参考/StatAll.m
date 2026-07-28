function [Amean,Amin,Amax,Astd,Avc,Askew,Akurt] = StatAll(A)
% 提取矩阵A的统计规律
% A: n*p矩阵 （按列提取）
Amean = mean(A); % 均值
Amin = min(A); % 最小值
Amax = max(A); % 最大值
Astd = std(A); % 标准差
Avc = 100*Astd./Amean; % 变异系数
Askew = skewness(A,0); % 偏度系数
Akurt = kurtosis(A,0); % 峰度系数
end