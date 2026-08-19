%% 部分数据重复 添加高斯噪声 输入Table数据
function Test_data = AddNoise(Test_data)
%添加高斯噪声
ori_data = table2array(Test_data(:,16:108));
HNdata = [];
UCCdata = [];
for i = 1:10 %10个患者重复
    %抓取其中的HN和UCC数据
    row1 = 27*i-26;
    row2 = 27*i-3;
    tmp2 = ori_data(row1:row2,:);
    %前5个头颈  后5个UCC
    if i<=5
        HNdata = [HNdata;tmp2];
    else
        UCCdata = [UCCdata;tmp2];
    end 
end

%计算标准差
HNfeatureSTD = std(HNdata,0,1);
UCCfeatureSTD = std(UCCdata,0,1);

%噪声信息
noiseLevel = 0.01;  %噪声水平
MinNoise = 1e-6;  %最小噪声



[numsamples, numfeatures] = size(Test_data);
numfeatures = numfeatures-15;
for i = 1:10 %10个患者重复
    %抓取其中的HN和UCC数据
    row1 = 27*i-26;
    row2 = 27*i-3;
    for j = row1:row2
        %前5个头颈  后5个UCC
        if i<=5
            noiseScale = max(HNfeatureSTD*noiseLevel,MinNoise); %噪声水平
            noise = noiseScale.*randn(1,numfeatures);
            Test_data{j,16:108} =  Test_data{j,16:108} +noise;
        else
            noiseScale = max(UCCfeatureSTD*noiseLevel,MinNoise);  %噪声水平
            noise = noiseScale.*randn(1,numfeatures);
            Test_data{j,16:108} =  Test_data{j,16:108} +noise;
        end
    end 
end
fprintf('噪声添加完毕');
%噪声处理完毕