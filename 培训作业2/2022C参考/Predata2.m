function [T2,T4] = Predata2
%% 导入电子表格中的数据
% 用于从以下电子表格导入数据的脚本:
%%
% 
%    工作簿: C:\Users\Caibin Zeng\Desktop\2022C\附件.xlsx
%    工作表: 表单2
%
%% 设置导入选项并导入数据

opts = spreadsheetImportOptions("NumVariables", 17);

% 指定工作表和范围
opts.Sheet = "表单2新";
opts.DataRange = "A2:Q70";

% 指定列名称和类型
opts.VariableNames = ["NO","TYPE", "WEAT", "SiO2", "Na2O", "K2O", "CaO", "MgO", "Al2O3", "Fe2O3", "CuO", "PbO", "BaO", "P2O5", "SrO", "SnO2", "SO2"];
opts.SelectedVariableNames = ["NO","TYPE", "WEAT", "SiO2", "Na2O", "K2O", "CaO", "MgO", "Al2O3", "Fe2O3", "CuO", "PbO", "BaO", "P2O5", "SrO", "SnO2", "SO2"];
opts.VariableTypes = ["categorical","string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];

% 指定变量属性
opts = setvaropts(opts, ["SiO2", "Na2O", "K2O", "CaO", "MgO", "Al2O3", "Fe2O3", "CuO", "PbO", "BaO", "P2O5", "SrO", "SnO2", "SO2"], "FillValue", 0);

% 导入数据
S1 = readtable("附件.xlsx", opts, "UseExcel", false);
% 量化处理
S1.TYPE(S1.TYPE == "高钾") = 0;
S1.TYPE(S1.TYPE == "铅钡") = 1;
S1.WEAT(S1.WEAT == "无风化") = 0;
S1.WEAT(S1.WEAT == "风化") = 1;
S1.WEAT = categorical(S1.WEAT);
S1.TYPE = categorical(S1.TYPE);
%%
S2 = S1(:,4:end);
T2 = S2.Variables;
% % 近零值处理：
% % 由成分数据的特点,取每一列的非零数最小值乘以0.65作为查补值
% for ii = 1:13
%     ind = T2(:,ii+1)~=0;
%     ind2 = T2(:,ii+1)==0;
%     temp = 0.65*min(T2(ind,ii+1));
%     T2(ind2,ii+1) =temp;
% end
T2(T2==0) = eps;
T3 = array2table(T2,'VariableNames',["SiO2", "Na2O", "K2O", "CaO", "MgO", "Al2O3", "Fe2O3", "CuO", "PbO", "BaO", "P2O5", "SrO", "SnO2", "SO2"]);
T4 = [S1(:,1:3) T3];
%% 清除临时变量

clear opts
end