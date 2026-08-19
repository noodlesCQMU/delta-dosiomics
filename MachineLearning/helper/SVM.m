%% 支持向量机多分类算法
%输入训练集数据 %所需要的训练特征向量 %注意predictors的格式 需保证为行向量
%datatrian为Table类型，其中response变量‘Label’,特征变量名保存在predictors
%输出SVM模型
function svm_Model=SVM(dataTrain,predictors)
svm_Model = fitcecoc(dataTrain,'Label','PredictorNames',predictors,...
    "Learners","svm","OptimizeHyperparameters",'all',...
    'HyperparameterOptimizationOptions',...
    struct('AcquisitionFunctionName','expected-improvement-plus','kfold',5,...
    'MaxObjectiveEvaluations',50,'ShowPlots',false,'Verbose',0));
bestParams=svm_Model.HyperparameterOptimizationResults.XAtMinObjective;
disp("=== 支持向量机最优超参数 ===");
disp(bestParams);

