%%%%XGBOOST实现多分类  matlab调用python库函数  输入训练数据 测试数据  以及选择的特征向量
%交叉验证和测试集准确率 和XG模型
function [metrics_cv,metrics_test,XG_models,LabelNames,cm]=XGBoost(dataTrain,dataTest,preditors,num_class)
%标签转换 由于matlab标签从1开始，而python XGBoost中标签从0开始
[Train_Label,LabelNames]= grp2idx(dataTrain.Label);
Train_Label=Train_Label-1;

XTrain=table2array(dataTrain(:,preditors));%获取训练数据特
YTrain=Train_Label;%获取训练标签


%% 训练集五折交叉验证
cv=cvpartition(dataTrain.Label,'KFold',5);

XG_models=cell(1,cv.NumTestSets); %用于保存每个模型
Metrics_array = repmat(table, 1,cv.NumTestSets); %预先分配table数组用于存储评估指标


for fold=1:cv.NumTestSets
    
    %获取交叉验证中的训练集和测试集索引
    trainIdx=cv.training(fold);
    testIdx=cv.test(fold);

    %以此索引获取当前折的python格式数据  
    %先采用matlab阵列获取对应特征和标签 然后在转换成python处理所需要的格式
    Xtrain_fold=py.numpy.array(XTrain(trainIdx,:));
    Ytrain_fold=py.numpy.array(YTrain(trainIdx));

    Xval_fold=py.numpy.array(XTrain(testIdx,:));
    Yval_fold=py.numpy.array(YTrain(testIdx)); %由于标签为列向量

    %% 转换为DMatrix格式数据
    data_train=py.xgboost.DMatrix(Xtrain_fold,label=Ytrain_fold); %%交叉验证中的训练集
    data_val=py.xgboost.DMatrix(Xval_fold,label=Yval_fold);   %%交叉验证中的测试集
    
    %% 创建XGBoost参数字典（Python字典格式） 通过jupterNotebook确定的参数
    params = py.dict(pyargs(...
        'objective', 'multi:softmax',...
        'num_class', int32(num_class),...      % 必须为整数
        'max_depth', int32(9),...
        'eta', 0.3,...
        'subsample', 0.6,...
        'colsample_bytree',0.9,...
        'booster','gbtree',...
        'min_child_weight',0,...
        'eval_metric', 'mlogloss'...  %多分类一般使用这个 还可以考虑使用mlogloss
        )...
      );

   %训练模型
   num_boost_round = int32(200); % 必须转换为Python整数   %%迭代次数（或者所弱分类器决策树的数量）
   XG_models{fold}= py.xgboost.train(params, data_train, num_boost_round);

   %验证数据
   pred = XG_models{fold}.predict(data_val);
   pred_labels = double(pred); % 需要转换为MATLAB类型

   %计算准确率
   val_Label=double(Yval_fold);%python格式的真实标签 需要转换成matlab类型

   [cm_fold,~] = confusionmat(val_Label, pred_labels);%获得混淆矩阵
   Metrics_array(fold,:) = Eval_Metrics(cm_fold, num_class);  %获得每折评估指标   
end

metrics_cv = mean(Metrics_array); %求平均值
fprintf('训练集五折交叉验证准确率 %.2f %%.\n', metrics_cv.accuracy);
fprintf('训练集五折交叉验证精确率 %.4f.\n', metrics_cv.MacroPrecision);
fprintf('训练集五折交叉验证召回率 %.4f.\n', metrics_cv.MacroRecall);
fprintf('训练集五折交叉验证F1分数 %.4f.\n', metrics_cv.MacroF1);

%% 测试集数据结果
%%%进行独立测试  使用测试集数据 集成模型进行预测
num_models=numel(XG_models); %获取模型数量
size_test=size(dataTest.Label,1);%获得测试集样本的数据
pred_tests=zeros(size_test,num_models); %新建用于存储每个样本在每个模型的预测结果

%获取独立测试集数据

XTest=table2array(dataTest(:,preditors));%获取测试集特征

XTest_py=py.numpy.array(XTest);%将测试数据转换测python的格式
data_test = py.xgboost.DMatrix(XTest_py); %% 转换测试数据为Dmatrix格式

%进行测试 每个模型测试以此
for i=1:num_models
    pred_test = XG_models{i}.predict(data_test); %获得测试结果
    pred_tests(:,i)=double(pred_test); % 预测通过double转换为MATLAB类型 存储到样本数据结果中
end

%%%多数投票
final_pred_Labels=mode(round(pred_tests),2);  %考虑到python分类结果可能会存在浮点树，使用round四舍五入确保程序稳健
%将数字转换成真实标签  python是0-based索引，matlab是1-based索引
True_class=dataTest.Label;% 真实标签
Pred_class=LabelNames(final_pred_Labels+1); %预测标签;

%%最终测试结果
%计算混淆矩阵
neworder = {'Body','Error-free','Gantry','MLC-random','MLC-sys',...
    'MU','Set-up'};
[cm,order] = confusionmat(True_class,Pred_class,"Order",neworder);
metrics_test = Eval_Metrics(cm, num_class);  %获得每折评估指标 
fprintf('独立测试集准确率 %.2f %%.\n', metrics_test.accuracy);
fprintf('独立测试集精确率 %.4f.\n', metrics_test.MacroPrecision);
fprintf('独立测试集召回率 %.4f.\n', metrics_test.MacroRecall);
fprintf('独立测试集F1分数 %.4f.\n', metrics_test.MacroF1);

%画图
figure,
cmfig = confusionchart(cm,order);%图表混淆矩阵
%cmfig.ColumnSummary='column-normalized';
%cmfig.RowSummary="row-normalized";
cmfig.Title='MLC-Error Confusion Matrix';
%cmfig.RowSummary='row-normalized';
%cmfig.ColumnSummary="column-normalized";
fprintf("haha")
%%