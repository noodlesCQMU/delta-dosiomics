%输入data为table数据 第一列为label imp为特征重要性排序 
function [feature_to_delete,accuracyval,micro_AUC,macro_AUC]=FeatureToRecursion(data,predictors)
%使用递归算法 联合RF进行特征筛选

len=length(predictors);% 获取初始特征长度

accuracyval=zeros(len,1); %初始化特征筛选记录的accuracyval
%初始化后续递归特征评价的AUC
micro_AUC=zeros(len,1);
macro_AUC=zeros(len,1);

%初始化特征字符串
feature_to_delete=cell(len,1);

%% RandomForest Tree 第一次RF   
B=100; %常用100个树%重复取样次数

%随机森林特征选取其中的m个 小于样本特征的sqrt(p)个， 由于DataTest有一个Response因此要减1

%templatedTree告诉重复取样袋装法 里面是决策树
%'Reproducible',true让每一次的结果都一样，用于测试或者教学。特征筛选中也应该保持可重复性
%%形成弱的决策树
weaker_tree=templateTree('NumVariablesToSample',sqrt(size(predictors,2)));
%需要优化的参数
tree_params={'MaxNumSplits','MinLeafSize','SplitCriterion'};

%交叉熵 所有特征都使用  'deviance'表示选择cross entropy, 'gdi'表示选择Gini index
MLCtree_bag=fitcensemble(data,'Label','PredictorNames',predictors,... 
    'Method','Bag','NumLearningCycles',B,'Learners',weaker_tree,'OptimizeHyperparameters',...    %%装B颗树  t是装什么类型的树  甚至KNN能装进来
    tree_params,'HyperparameterOptimizationOptions',...%优化参数只选择了minleafsize 和MaxNumsplits 如果全选设置all会增加boost选项
        struct('UseParallel',true,'AcquisitionFunctionName','expected-improvement-plus','kfold',5,...
        'MaxObjectiveEvaluations',50,'ShowPlots',false,'Verbose',0));

%收集验证结果  5折交叉验证
cvModel=crossval(MLCtree_bag,'kfold',5);
[predictedLabel,scores]=kfoldPredict(cvModel);
classNames=MLCtree_bag.ClassNames;
[cm,~] = confusionmat(data.Label,predictedLabel);

%计算准确率和auc
accuracyval(1) = trace(cm)/sum(cm(:));
rocObj=rocmetrics(data.Label,scores,classNames);

%计算多分类中的宏平均和微平均AUC值
[~,~,~,macro_AUC(1)]=average(rocObj,'macro');
[~,~,~,micro_AUC(1)]=average(rocObj,'micro');

  
%计算随机森林特征值重要性
imp=predictorImportance(MLCtree_bag);
[~, indices] = sort(imp, 'ascend'); %对特征进行升序排序

%升序排序  从小到大  
sortedPredictors=predictors(indices); %得到排序的预测特征

%开始特征筛选  删除最小重要性的特征
feature_to_delete{1}=sortedPredictors(1); %找到最小的特征即第一个特征  保存第一个删选的特征
sortedPredictors(1)=[];  %更新后的特征 删除首位第一个特征


for i=2:len
    %% RandomForest Tree   
    B=100; %常用100个树%重复取样次数
    %随机森林特征选取其中的m个 小于样本特征的sqrt(p)个， 由于DataTest有一个Response因此要减1

    %templatedTree告诉重复取样袋装法 里面是决策树
    %'Reproducible',true让每一次的结果都一样，用于测试或者教学。特征筛选中也应该保持可重复性
    
    %%形成弱的决策树
    weaker_tree=templateTree('NumVariablesToSample',sqrt(size(sortedPredictors,2)));  %筛除后特征取样
    %需要优化的参数
    tree_params={'MaxNumSplits','MinLeafSize','SplitCriterion'};
    
    %交叉熵 所有特征都使用  'deviance'表示选择cross entropy, 'gdi'表示选择Gini index
    MLCtree_bag=fitcensemble(data,'Label','PredictorNames',sortedPredictors,... 
        'Method','Bag','NumLearningCycles',B,'Learners',weaker_tree,'OptimizeHyperparameters',...    %%装B颗树  t是装什么类型的树  甚至KNN能装进来
    tree_params,'HyperparameterOptimizationOptions',...%优化参数只选择了minleafsize 和MaxNumsplits 如果全选设置all会增加boost选项
        struct('UseParallel',true,'AcquisitionFunctionName','expected-improvement-plus','kfold',5,...
        'MaxObjectiveEvaluations',50,'ShowPlots',false,'Verbose',0));


    %收集验证结果
    cvModel=crossval(MLCtree_bag,'kfold',5);
    [predictedLabel,scores]=kfoldPredict(cvModel);
    classNames=MLCtree_bag.ClassNames;
    [cm,~] = confusionmat(data.Label,predictedLabel);

    %计算准确率和auc
    accuracyval(i) = trace(cm)/sum(cm(:));
    rocObj=rocmetrics(data.Label,scores,classNames);

    %计算多分类中的宏平均和微平均AUC值
    [~,~,~,macro_AUC(i)]=average(rocObj,'macro');
    [~,~,~,micro_AUC(i)]=average(rocObj,'micro');
    
    %放入首位特征
    feature_to_delete{i}=sortedPredictors(1);
    %继续删除特征最低重要性特征
    sortedPredictors(1)=[];
    if isempty(sortedPredictors)   %判断特征是否结束
        break;
    end
end
