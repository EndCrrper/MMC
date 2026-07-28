function clusterR(X)
CompNames = ['SiO_2', "Na_2O", "K_2O", "CaO", "MgO", "Al_2O_3", ...
    "Fe_2O_3", "Cu_O", "PbO", "BaO", "P_2O_5", "SrO", "SnO_2", "SO_2"];
LabelNames = cellstr(CompNames);
% Pearson 相关系数
 rho = corr(X, 'type','pearson')
% 热图
figure;
heatmap(LabelNames,LabelNames,rho, 'FontSize',10, 'FontName','Times New Roman');
colormap(jet)
DistList = {'single','average','weighted'};
Q00D = pdist(X','correlation');
Q00Z1 = linkage(Q00D,'single'); %基于最小距离
Q00Z2 = linkage(Q00D,'average'); %基于平均距离
Q00Z3 = linkage(Q00D,'weighted'); %基于最小权重距离
Q00R = [cophenet(Q00Z1,Q00D),cophenet(Q00Z2,Q00D),cophenet(Q00Z3,Q00D)];
Q00Z = linkage(Q00D,DistList(Q00R==max(Q00R)));
figure;
Q00h = dendrogram(Q00Z,'Labels',LabelNames);
Q00T = cluster(Q00Z,3);
Q00Tres = table(CompNames',Q00T,'VariableNames',["成分" "分类"]);
sortrows(Q00Tres, "分类")
end