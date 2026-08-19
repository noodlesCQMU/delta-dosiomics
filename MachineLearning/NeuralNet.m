%% 神经网络多分类算法
%输入训练集数据 %所需要的训练特征向量 %注意predictors的格式 需保证为行向量
%datatrian为Table类型，其中response变量‘Label’,特征变量名保存在predictors
%输出神经网络模型
function nnModel=NeuralNet(dataTrain,predictors)
%设置申请网络优化参数
%还以增加layerWeightsInitializer和LayerBiasesInitializer（神经元权重和偏置）进行优化 通常选用默认值即可
nn_params={'LayerSizes','Activations','Lambda','standardize'};
%对SVM进行优化 寻找最优参数  5折交叉验证获取最优参数
nnModel = fitcnet(dataTrain,'Label','PredictorNames',predictors,...
   "OptimizeHyperparameters",nn_params,...
    'HyperparameterOptimizationOptions',...
    struct('AcquisitionFunctionName','expected-improvement-plus','kfold',5,'MaxObjectiveEvaluations',50,'ShowPlots',false,'Verbose',0));
bestParams=nnModel.HyperparameterOptimizationResults.XAtMinObjective;
disp("=== 支持向量机最优超参数 ===");
disp(bestParams);