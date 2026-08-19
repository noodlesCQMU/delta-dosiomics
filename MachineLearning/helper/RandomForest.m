%%%随机森林树模型，输入训练数据，训练特征向量，输出训练模型
function [RF_Model,imp]=RandomForest(dataTrain,predictors)
%注意predictors的格式 需保证为行向量
%% RandomForest Tree
B=100; %常用100个树
%随机森林特征选取其中的m个 小于样本特征的sqrt(p)个， 由于DataTest有一个Response因此要减1
%'Reproducible' 设置为true可保证树的重复性 保证教学
%%形成弱的决策树
weaker_tree=templateTree('NumVariablesToSample',sqrt(size(predictors,2)));
%需要优化的参数
tree_params={'MaxNumSplits','MinLeafSize','SplitCriterion'};
%交叉熵 所有特征都使用  'deviance'表示选择cross entropy, 'gdi'表示选择Gini index
RF_Model=fitcensemble(dataTrain,'Label','PredictorNames',predictors,... 
    'Method','Bag','NumLearningCycles',B,'Learners',weaker_tree,'OptimizeHyperparameters',...    %%装B颗树  t是装什么类型的树  甚至KNN能装进来
   tree_params,'HyperparameterOptimizationOptions',...%优化参数只选择了minleafsize 和MaxNumsplits 如果全选设置all
    struct('UseParallel',true,'AcquisitionFunctionName','expected-improvement-plus','kfold',5,'MaxObjectiveEvaluations',50,'ShowPlots',false,'Verbose',0));
Best_params=RF_Model.HyperparameterOptimizationResults.XAtMinObjective;
disp("====最佳参数===="),disp(Best_params);
imp=predictorImportance(RF_Model);