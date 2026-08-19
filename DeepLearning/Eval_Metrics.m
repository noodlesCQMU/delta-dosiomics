%% 输出指标Table的形式输出Metrics Accuracy 宏平均Precision Recall 和 F1分数和微平均Precision Recall和F1分数 
%%输入混淆矩阵和分类数目
function Metrics = Eval_Metrics(ConfusionMatrix, ClassNum)

%计算准确率
accuracy = trace(ConfusionMatrix)/sum(ConfusionMatrix(:))*100;

%% 计算宏平均指标
%初始化
precision = zeros(ClassNum,1);
recall    = zeros(ClassNum,1);
f1score   = zeros(ClassNum,1);

%计算宏平均指标
for i = 1:ClassNum
    TP = ConfusionMatrix(i,i);

    %假正例  其他类别别预测为当前类
    FP = sum(ConfusionMatrix(:,i)) -TP;
    
    %假反例FN, 当前类被预测为其他类
    FN = sum(ConfusionMatrix(i,:)) -TP;

    %真负例TN,其他类正确分类
    TN = sum(ConfusionMatrix(:)) - TP - FP -FN;

    %计算指标
    precision(i) = TP / (TP+FP);
    recall(i) = TP/ (TP+FN);
    f1score(i) = 2*(precision(i)*recall(i))/(precision(i)+recall(i));
end

MacroPrecision  = mean(precision);
MacroRecall = mean(recall);
MacroF1 = mean(f1score);

%%%计算微平均指标  微平均的指标实际上就等于准确率  因此可以省略掉

%{
totalTP = sum(diag(ConfusionMatrix));
totalFP = 0;
totalFN = 0;
for i= 1:ClassNum
    totalFP = totalFP +(sum(ConfusionMatrix(:,i)) - ConfusionMatrix(i,i));
    totalFN = totalFN +(sum(ConfusionMatrix(i,:)) - ConfusionMatrix(i,i));
end 
MicroPrecision = totalTP / (totalTP + totalFP);
MicroRecall = totalTP/ (totalTP + totalFN);
MicroF1 = 2 * (MicroPrecision * MicroRecall) / (MicroPrecision +
MicroRecall);
%}
%仅包含宏平均指标
Metrics = table(accuracy,MacroPrecision,MacroRecall,MacroF1);