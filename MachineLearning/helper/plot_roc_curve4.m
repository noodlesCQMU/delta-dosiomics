%% 画多分类ROC曲线图 输入SVMmodel NNmodel XGmodel， 选择的预测特征和画图标题
% 画图ROC曲线对比图 
% 输入真实标签 每个分类的预测数矩阵（NxC),画图的Title，和可选的类别名称 XG_ClassNames适用于XGBoost
% 输入DP的预测结果和DP_scores和DP的真实标签
function plot_roc_curve4(Testdata, SVMmodel, NNmodel, XGmodels,XG_ClassNames,preditors,DP_Prediction, DP_Scores,DP_Label,PlotTitle)
%获得真实标签
TrueLabel = Testdata.Label;

%获得测试分数
[~, score_svm] = predict(SVMmodel, Testdata);%获得测试预测结果
SVM_ClassNames = SVMmodel.ClassNames; %获得分类数目

numsamples = numel(TrueLabel); %样本总数
numClasses = numel(SVM_ClassNames); 
%类别总数  由于其余模型的分类数目一致  因此统一使用该变量

%%  SVM模型画图
% 使用 Micro-average 计算 AUC (适用于多分类)
% 将标签和分数展开
%初始化二进制标签向量和分数向量
y_bin = zeros(numsamples*numClasses, 1);
score_bin = zeros(numsamples*numClasses, 1);

%遍历每个类别，以二类来评估
for i = 1:numClasses
    
    %遍历当前类别下的每个样本的分类结果和预测分数
    idx = (i-1)*numsamples + 1 : i*numsamples;
    
    %%%创建二值标签，当前类别为1，其他未为0
    y_bin(idx) = strcmp(string(TrueLabel), string(SVM_ClassNames{i}));%对比字符串相等返回1否则返回0
    score_bin(idx) = score_svm(:,i); %获得当前样本的预测分数
end

%ROC分析
[Xroc_svm, Yroc_svm, ~, microAUC_svm] = perfcurve(y_bin, score_bin, 1);
fprintf('Micro-average AUC: %.4f\n', microAUC_svm);


%%  NN模型画图
%获得测试分数
[~, score_nn] = predict(NNmodel, Testdata);%获得测试预测结果
NN_ClassNames = NNmodel.ClassNames;


%再次遍历每个类别，以二类来评估
for i = 1:numClasses
    
    %遍历当前类别下的每个样本的分类结果和预测分数
    idx = (i-1)*numsamples + 1 : i*numsamples;
    
    %%%创建二值标签，当前类别为1，其他未为0
    y_bin(idx) = strcmp(string(TrueLabel), string(NN_ClassNames{i}));%对比字符串相等返回1否则返回0
    score_bin(idx) = score_nn(:,i); %获得当前样本的预测分数
end

%ROC分析
[Xroc_nn, Yroc_nn, ~, microAUC_nn] = perfcurve(y_bin, score_bin, 1);
fprintf('Micro-average AUC: %.4f\n', microAUC_nn);

%% XGboost画图
%[~,  XG_ClassNames] = grp2idx(Testdata.Label); %获得XG分类数目
Test_array = table2array(Testdata(:,preditors));%获取测试数据所选的特征集数据
Test_py = py.numpy.array(Test_array);%将测试数据转换测python的格式
Test_final = py.xgboost.DMatrix(Test_py); %% 转换测试数据为Dmatrix格式
num_models = numel(XGmodels); %获取XG模型数量

%计算预测分数
for i=1:num_models
    pyscore = XGmodels{i}.predict(Test_final, pyargs('output_margin', true));%获取分数
    pyscores(:,:,i) = double(pyscore);
end
score_xg = mean(pyscores,3);

%再次遍历每个类别，以二类来评估
for i = 1:numClasses
    
    %遍历当前类别下的每个样本的分类结果和预测分数
    idx = (i-1)*numsamples + 1 : i*numsamples;
    
    %%%创建二值标签，当前类别为1，其他未为0
    y_bin(idx) = strcmp(string(TrueLabel), string(XG_ClassNames{i}));%对比字符串相等返回1否则返回0
    score_bin(idx) = score_xg(:,i); %获得当前样本的预测分数
end

%ROC分析
[Xroc_xg, Yroc_xg, ~, microAUC_xg] = perfcurve(y_bin, score_bin, 1);
fprintf('Micro-average AUC: %.4f\n', microAUC_xg);

%% DP模型
[numsamples_DP, classnum_DP] = size(DP_Scores); %获取样本和数目
DP_ClassNames = unique(DP_Label);%获得类别列表


%再次遍历每个类别，以二类来评估
for i = 1:classnum_DP
    
    %遍历当前类别下的每个样本的分类结果和预测分数
    idx = (i-1)*numsamples_DP + 1 : i*numsamples_DP;
    
    %%%创建二值标签，当前类别为1，其他未为0
    y_bin(idx) = strcmp(string(DP_Label), string(DP_ClassNames(i)));%对比字符串相等返回1否则返回0
    score_bin(idx) = DP_Scores(:,i); %获得当前样本的预测分数
end

%ROC分析
[Xroc_DP, Yroc_DP, ~, microAUC_DP] = perfcurve(y_bin, score_bin, 1);
fprintf('Micro-average AUC: %.4f\n', microAUC_DP);



%% 画ROC对比图

%画图
%figure(1);
subplot(2,3,4)
plot(Xroc_svm, Yroc_svm, 'b--', 'LineWidth', 2); hold on;
plot(Xroc_nn, Yroc_nn, 'g:', 'LineWidth', 2)
plot(Xroc_xg, Yroc_xg, 'k-.', 'LineWidth', 2)
plot(Xroc_DP, Yroc_DP,'r-','LineWidth',2)

plot([0 1],[0 1],'k--', 'LineWidth', 0.5);
legend(sprintf('SVM (AUC = %.4f)', microAUC_svm),sprintf('NN (AUC = %.4f)', microAUC_nn),...
    sprintf('XGBoost (AUC = %.4f)',microAUC_xg),sprintf('3DResNet50 (AUC = %.4f)', microAUC_DP),'Location','southeast');

    
% === 字体分开设置区域 ===
% 1. 刻度字体
set(gca, 'FontSize', 10, 'FontName', 'Arial'); 
    
% 2. 坐标轴标签字体
xlabel('False Positive Rate', 'FontSize', 12, 'FontWeight', 'normal');
ylabel('True Positive Rate', 'FontSize', 12, 'FontWeight', 'normal');
    
% 3. 标题字体
title(sprintf(PlotTitle), ...
          'FontSize', 12);
% ========================
    
grid on; axis square;
ax = gca;
ax.GridLineStyle = '--';
ax.LineWidth = 0.5;
    
% 保存为 PDF 和 EMF
% exportgraphics(gcf, [filename '.pdf'], 'ContentType', 'vector');
% exportgraphics(gcf, [filename '.emf'], 'ContentType', 'vector');
end
