%模型评估，输出五折交叉验证准确率  测试准确率  输入评估模型、测试数据所选特征、测试集数据
function [Finalscores, accuracy_test] = XGBoost_eval_model(XG_models, preditors, dataTest, ClassNames)
num_models = numel(XG_models); %获取模型数量
size_test = size(dataTest.Label,1);%获得测试集样本的数据

predict_results = zeros(size_test, num_models); %新建用于存储每个样本在每个模型的预测结果

XTest = table2array(dataTest(:,preditors));%获取测试数据特征集数据
%获取测试集特征
XTest_py = py.numpy.array(XTest);%将测试数据转换测python的格式
data_test = py.xgboost.DMatrix(XTest_py); %% 转换测试数据为Dmatrix格式

%进行测试 每个模型测试以此
for i=1:num_models
    predict_result = XG_models{i}.predict(data_test); %获得单个模型的测试结果

    pyscore = XG_models{i}.predict(data_test, pyargs('output_margin', true));%获取分数
    pyscores(:,:,i) = double(pyscore);
    predict_results(:,i) = double(predict_result); % 预测通过double转换为MATLAB类型 存储到样本数据结果中
end
Finalscores = mean(pyscores,3);
%%%多数投票 最大为最终预测 


final_pred_Labels = mode(predict_results, 2);  %考虑到python分类结果可能会存在浮点树，使用round四舍五入确保程序稳健
%将数字转换成真实标签  python是0-based索引，matlab是1-based索引

True_class = dataTest.Label;% 真实标签
Pred_class = ClassNames(final_pred_Labels+1); %预测标签  数字标签不要忘了+1


%%最终测试结果
%计算混淆矩阵
[cm,order] = confusionmat(True_class, Pred_class);
accuracy_test= sum(diag(cm)) / sum(cm(:));
fprintf('XGBoost模型测试集多数投票准确率为: %.2f%%\n', accuracy_test*100);

%画图
figure,
cmfig = confusionchart(cm,order);%图表混淆矩阵
cmfig.ColumnSummary='column-normalized';
cmfig.RowSummary="row-normalized";
cmfig.Title='MLC-Error Confusion Matrix';
cmfig.RowSummary='row-normalized';
cmfig.ColumnSummary="column-normalized";
cmfig.Normalization="total-normalized";
