function r = GRA(X0,X1)
% X0:参考序列
% X1: 比较序列
% 标准化：初值法或均值法
X0 = X0./mean(X0);
X1 = X1./mean(X1);

S1 = X1 - X0; %每个比较序列与参考序列作差
min2=min(min(abs(S1)));  %求两级最小差
max2=max(max(abs(S1)));  %求两级最大差
rho=0.5;                   %分辨系数
eta=(min2+rho*max2)./(abs(S1)+rho*max2);  %求关联系数
r=mean(eta);                              %求关联度
r=r';
end
