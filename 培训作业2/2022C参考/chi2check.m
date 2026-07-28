function chi2check(A)
% 判断卡方检验的条件
Asize = sum(A,"all");
B = sum(A,2)*sum(A)/Asize;
B = B(:);
fprintf('样本总数为 %d\n',Asize);
fprintf('最小的期望计数为 %.4f\n',min(B));
if B >= 5 & Asize >=40
    disp('采用卡方检验公式');
elseif min(B) >= 1 & min(B) < 5 & Asize >=40
    disp('采用 Yates 校正卡方检验公式');
else
    disp('采用 Fisher 确切检验公式');
end
end

