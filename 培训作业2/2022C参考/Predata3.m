function [T4,T6] = Predata3
%% 导入电子表格中的数据
% 用于从以下电子表格导入数据的脚本:
%%
% 
%    工作簿: C:\Users\Caibin Zeng\Desktop\2022C\附件.xlsx
%    工作表: 表单3
%
%% 设置导入选项并导入数据

opts = spreadsheetImportOptions("NumVariables", 16);

% 指定工作表和范围
opts.Sheet = "表单3";
opts.DataRange = "A2:P9";

% 指定列名称和类型
opts.VariableNames = ["NO", "WEAT", "SiO2", "Na2O", "K2O", "CaO", "MgO", "Al2O3", "Fe2O3", "CuO", "PbO", "BaO", "P2O5", "SrO", "SnO2", "SO2"];
opts.VariableTypes = ["categorical", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];

% 指定变量属性
opts = setvaropts(opts, ["SiO2", "Na2O", "K2O", "CaO", "MgO", "Al2O3", "Fe2O3", "CuO", "PbO", "BaO", "P2O5", "SrO", "SnO2", "SO2"], "FillValue", 0);

% 导入数据
S2 = readtable("附件.xlsx", opts, "UseExcel", false);
S2.WEAT(S2.WEAT == "无风化") = 0;
S2.WEAT(S2.WEAT == "风化") = 1;
S2.WEAT = categorical(S2.WEAT);
%%
T3 = S2(:,3:end);
T4 = T3.Variables;
% % 近零值处理：
% % 由成分数据的特点,取每一列的非零数最小值乘以0.65作为查补值
% for ii = 1:2
%     ind = T4(:,ii+1)~=0;
%     ind2 = T4(:,ii+1)==0;
%     temp = 0.65*min(T4(ind,ii+1));
%     T4(ind2,ii+1) =temp;
% end
% for ii = 1:1
%     ind = T4(:,ii+4)~=0;
%     ind2 = T4(:,ii+4)==0;
%     temp = 0.65*min(T4(ind,ii+4));
%     T4(ind2,ii+4) =temp;
% end
% for ii = 1:4
%     ind = T4(:,ii+6)~=0;
%     ind2 = T4(:,ii+6)==0;
%     temp = 0.65*min(T4(ind,ii+6));
%     T4(ind2,ii+6) =temp;
% end
% for ii = 1:3
%     ind = T4(:,ii+11)~=0;
%     ind2 = T4(:,ii+11)==0;
%     temp = 0.65*min(T4(ind,ii+11));
%     T4(ind2,ii+11) =temp;
% end
%% 
T4(T4==0)=eps;
T5 = array2table(T4,'VariableNames',["SiO2", "Na2O", "K2O", "CaO", "MgO", "Al2O3", "Fe2O3", "CuO", "PbO", "BaO", "P2O5", "SrO", "SnO2", "SO2"]);
T6 = [S2(:,1:2) T5];
%% 清除临时变量

clear opts