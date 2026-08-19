%模型评估，输出五折交叉验证准确率  测试准确率  输入评估模型、训练集数据、测试集数据
function [metrics_cv, metrics_test,cm_test]=eval_model(Model,dataTrain,dataTest)
%% 交叉验证
cvModel=crossval(Model,'kfold',5);%五折交叉验证
[predictedLabel,~]=kfoldPredict(cvModel); %获得预测标签结果
[cm_cv,~] = confusionmat(dataTrain.Label,predictedLabel);%获得混淆矩阵
classnum = numel(Model.ClassNames);%获得模型的分类数目
%验证集的指标计算
metrics_cv = Eval_Metrics(cm_cv, classnum);
fprintf('训练集五折交叉验证准确率 %.2f %%.\n', metrics_cv.accuracy);
fprintf('训练集五折交叉验证精确率 %.4f.\n', metrics_cv.MacroPrecision);
fprintf('训练集五折交叉验证召回率 %.4f.\n', metrics_cv.MacroRecall);
fprintf('训练集五折交叉验证F1分数 %.4f.\n', metrics_cv.MacroF1);

%% 测试集验证
%测试结果
[Test_predict,~]=predict(Model,dataTest);%获得测试预测结果
%计算混淆矩阵  混淆矩阵的类别

neworder = {'Body','Error-free','Gantry','MLC-random','MLC-sys',...
    'MU','Set-up'};
[cm_test,order_test] = confusionmat(dataTest.Label,Test_predict,"Order",neworder);

%%%测试集的指标计算
metrics_test = Eval_Metrics(cm_test, classnum);
fprintf('独立测试集准确率 %.2f %%.\n', metrics_test.accuracy);
fprintf('独立测试集精确率 %.4f.\n', metrics_test.MacroPrecision);
fprintf('独立测试集召回率 %.4f.\n', metrics_test.MacroRecall);
fprintf('独立测试集F1分数 %.4f.\n', metrics_test.MacroF1);

%展示混淆矩阵
figure,
cmfig = confusionchart(cm_test,order_test);%图表混淆矩阵
cmfig.Title='MLC-Error Confusion Matrix';
%cmfig.ColumnSummary="column-normalized";
%cmfig.RowSummary='row-normalized';
%rocObj=rocmetrics(dataTest.Label,test_scores,className);
%{
subplot(1,2,2)
rocObj=rocmetrics(dataTest.Label,test_scores,className);
%[~,~,~,AUC_cv]=average(rocObj,"micro");  %计算AUC值
%%展示ROC曲线
plot(rocObj,ShowModelOperatingPoint=false)  %不显示模型工作点
%}
