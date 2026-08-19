%%函数相关性检测,返回需要删除的特征和相关性矩阵 初始特征重要性排序
%输入data,以及需要筛选的相关性阈值TH
%data为table数据，第一列为label其余为特征  TH输入一般为0-1 
function [FeatureToDelete,corr_matrix,imp]=correlate_feature(data,TH)
%初始化需要删除的特征
FeatureToDelete={}; 

%获取特征名称
predictors=data.Properties.VariableNames;  %获取变量名特征
predictors(1)=[]; %去除其中的标签项目label  实际是应该为预测值


%随机森林进行特征重要性计算
B=100; %常用100个树%重复取样次数 %随机森林特征选取其中的m个 小于样本特征的sqrt(p)个， 由于DataTest有一个Response因此要减1

%templatedTree告诉重复取样袋装法 里面是决策树
%'Reproducible',true让每一次的结果都一样，用于测试或者教学。特征筛选中也应该保持可重复性
%%形成弱的决策树
weaker_tree=templateTree('NumVariablesToSample',sqrt(size(predictors,2)));
%需要优化的参数
tree_params={'MinLeafSize','MaxNumSplits','SplitCriterion'};

%交叉熵 所有特征都使用  'deviance'表示选择cross entropy, 'gdi'表示选择Gini index
MLCtree_bag=fitcensemble(data,'Label','PredictorNames',predictors,... 
    'Method','Bag','NumLearningCycles',B,'Learners',weaker_tree,'OptimizeHyperparameters',...    %%装B颗树  t是装什么类型的树  甚至KNN能装进来
    tree_params,'HyperparameterOptimizationOptions',...%优化参数只选择了minleafsize 和MaxNumsplits 如果全选设置all会增加boost选项
        struct('UseParallel',true,'AcquisitionFunctionName','expected-improvement-plus',...
        'kfold',5,'MaxObjectiveEvaluations',50,'ShowPlots',false,'Verbose',0));  %最大迭代次数50次，关闭图像展示，关闭迭代信息

best_params=MLCtree_bag.HyperparameterOptimizationResults.XAtMinObjective;
disp("最优参数为");
disp(best_params);
%特征重要性评估
imp=predictorImportance(MLCtree_bag);

%相关性计算
X_corr=table2array(data(:,2:108));
corr_matrix=corr(X_corr,Type="Spearman");

%%筛除高相关特征
[rows, cols] = find(abs(corr_matrix) > TH & triu(ones(size(corr_matrix)),1)); 
% 仅取上三角，排除对角线  triu(A,1)返回A的上三角且不包括对角线
high_corr_pairs = [predictors(rows)', predictors(cols)'];

%比较高相关性的重要特征性，删除特征性较低的一个
high_corr_len=length(high_corr_pairs);  %获取长度

for i=1:high_corr_len
    feature1=high_corr_pairs{i,1};  %取特征1
    feature2=high_corr_pairs{i,2};  %取特征2

    index1=find(strcmp(predictors,feature1));  %获取特征1的索引
    index2=find(strcmp(predictors,feature2));  %获取特征2的索引

    %tmp临时变量存储需要删除的特征
    if imp(index1) < imp(index2)  %删除小的特征 留下较大的特征
        tmp=feature1;
    else
        tmp=feature2; 
    end

    %判断需要删除是否已经属于需要删除的特征
    if ~ismember(tmp,FeatureToDelete)
        FeatureToDelete{end+1}=tmp;  %存储
    end
end