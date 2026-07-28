function T1 = Predata1

%% 导入电子表格中的数据
% 用于从以下电子表格导入数据的脚本:
%%
% 
%    工作簿: C:\Users\Caibin Zeng\Desktop\2022C\附件.xlsx
%    工作表: 表单1
%
%% 设置导入选项并导入数据

opts = spreadsheetImportOptions("NumVariables", 4);

% 指定工作表和范围
opts.Sheet = "表单1新";
opts.DataRange = "B2:E59";

% 指定列名称和类型
opts.VariableNames = ["ORNA", "TYPE", "COLOR", "WEAT"];
opts.SelectedVariableNames = ["ORNA", "TYPE", "COLOR", "WEAT"];
opts.VariableTypes = ["string", "string", "string", "string"];

% 指定变量属性
opts = setvaropts(opts, ["ORNA", "TYPE", "COLOR", "WEAT"], "EmptyFieldRule", "auto");

% 导入数据
T1 = readtable("附件.xlsx", opts, "UseExcel", false);
%% 

%% 量化变量

T1.ORNA(T1.ORNA == "A") = 0;
T1.ORNA(T1.ORNA == "B") = 1;
T1.ORNA(T1.ORNA == "C") = 2;
T1.TYPE(T1.TYPE == "高钾") = 0;
T1.TYPE(T1.TYPE == "铅钡") = 1;
T1.COLOR(T1.COLOR == "黑") = 0;
T1.COLOR(T1.COLOR == "蓝绿") = 1;
T1.COLOR(T1.COLOR == "绿") = 2;
T1.COLOR(T1.COLOR == "浅蓝") = 3;
T1.COLOR(T1.COLOR == "浅绿") = 4;
T1.COLOR(T1.COLOR == "深蓝") = 5;
T1.COLOR(T1.COLOR == "深绿") = 6;
T1.COLOR(T1.COLOR == "紫") = 7;
T1.WEAT(T1.WEAT == "无风化") = 0;
T1.WEAT(T1.WEAT == "风化") = 1;
%%
T1.WEAT = categorical(T1.WEAT);
T1.COLOR = categorical(T1.COLOR);
T1.TYPE = categorical(T1.TYPE);
T1.ORNA = categorical(T1.ORNA);
% 清除临时变量
clear opts
end