%模型临床评估，输出临床测试准确率\类别得分和分类目录  输入评估模型、测试集数据
function [accuracy_test, test_scores, className] = Clinicaleval_model(Model,dataTest)
%测试结果
[Test_predict,test_scores]=predict(Model,dataTest);%获得测试预测结果
className=Model.ClassNames;

%计算混淆矩阵  混淆矩阵的类别
[cm_test,order_test] = confusionmat(dataTest.Label,Test_predict);

%%%测试集准确率
accuracy_test = trace(cm_test)/sum(cm_test(:))*100;

fprintf('测试集准确率 %.2f %%', accuracy_test);

%展示
figure,
cmfig = confusionchart(cm_test,order_test);%图表混淆矩阵
cmfig.Title='MLC-Error Confusion Matrix';
cmfig.ColumnSummary="column-normalized";
cmfig.RowSummary='row-normalized';

%{
subplot(1,2,2)
rocObj=rocmetrics(dataTest.Label,test_scores,className);
%[~,~,~,AUC_cv]=average(rocObj,"micro");  %计算AUC值
%%展示ROC曲线
plot(rocObj,ShowModelOperatingPoint=false)  %不显示模型工作点l
%}