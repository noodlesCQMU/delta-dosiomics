%%  测试模型  输入深度学习模型cell组，测试集数据
%%  输出宏平均指标 预测标签和得分数
function [Metrics, MaxPrediction, Scores] = EvalDeepModel(DeepModels, TestData)  
model_num = length(DeepModels); %获得测试模型的数量
%预先分配table数组用于独立测试存储评估指标
Metrics_Array = repmat(table, 1,model_num); 
%获得测试集的分类数目
classnum = numel(unique(TestData.Labels));

for i = 1:model_num
    %验证获得预测标签
    [predictedLabels, score] = classify(DeepModels{i}.net,TestData,...
        'ExecutionEnvironment','cpu','MiniBatchSize',32);

     %获得混淆矩阵
    cm = confusionmat(TestData.Labels, predictedLabels);

    %每个模型的临床测试指标
    Metrics_Array(i,:) = Eval_Metrics(cm, classnum);  

    Prediction(:,i) = string(predictedLabels); %获得预测标签
    scores(:,:,i) = double(score); %存储预测分数
end
%计算最终的平均评估指标
Metrics = mean(Metrics_Array); %求平均值获得平均指标
fprintf('训练集五折交叉验证准确率 %.2f %%.\n', Metrics.accuracy);
fprintf('训练集五折交叉验证精确率 %.4f.\n', Metrics.MacroPrecision);
fprintf('训练集五折交叉验证召回率 %.4f.\n', Metrics.MacroRecall);
fprintf('训练集五折交叉验证F1分数 %.4f.\n', Metrics.MacroF1);
%获取最大投票的预测结果
MaxPrediction = MaxVoteCount(Prediction, TestData);
%获得平均预测分数
Scores = mean(scores,3);