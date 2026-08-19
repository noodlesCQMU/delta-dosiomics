%% 
% 生成DIFF_dicom文件，其中p1-orim是dolpin测量文件，p1-AXB是原始计划文件
% 
% 对于头颈部和腹部，腹部会有额外的Bladder形变计划，需要打开部分注释，单个患者文件进行处理，一次生成54个文件，腹部可能会更多

clear
close all
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%创建后面剂量差异信息的文件命名格式
FileName = ["LAT-1mmL";"LAT-1mmR";"Lng-1mmF";"Lng-1mmH";"Vrt-1mmA";"Vrt-1mmP";...
            "MU3%-";"MU3%";"MU5%-";"MU5%";"p1--0.2G";"p1--0.4G";"p1-0.2G";"p1-0.4G";...
            "p1--0.5X2F";"p1--1X2F";"p1-0.5X2F";"p1-1X2F";"p1-0.5X2R";"p1-1X2R";"p1-2X2R";...
            "p1-AXBW";"p1-AAA";"p1-AXB";"p1-body0.5";"p1-body1.5";"p1-body1";"P1-B0.5";"P1+B0.5";"P1-B1";"P1+B1"];

FileName_SIZE = size(FileName,1);%获取需要处理文件名数组的长度

%%
%%%打开文件选择病人ID的文件夹中的任意文件即可
[filename,filepath] = uigetfile('*.*','Please select a file to improt','E:\医学物理\待投稿论文\Dolphin\TESTDATA-ClincalTEST');
%只搜索DCM文件
filetype = '*.dcm';
searchmode = fullfile(filepath,filetype);
folders = dir(searchmode);
folder_len = size(folders,1);%获取文件目录长度

%遍历文件找到RS的路径读取，并在folder中删除只剩下RD文件
for i = 1:folder_len
    if contains(folders(i).name,'RS')
        filename = fullfile(folders(i).folder,folders(i).name);
        %fprintf('正在读取 DICOM 文件 %s\n', filename) 
        %{ 
          **`UseVRHeuristic`参数**：当设置为`false`时，MATLAB将严格按照DICOM标准解析文件，而不尝试猜测VR类型。
         这可以避免因启发式方法导致的错误。**影响**：关闭启发式方法可能会使MATLAB无法读取一些不符合标准但实际可读的文件。
         但对于大多数标准文件，这样设置没有问题。**其他注意事项**：如果文件确实不符合标准，可能需要使用第三方工具修复DICOM文件。
        %}
        RSinfo = dicominfo(filename,UseVRHeuristic=false); %读取RS文件 如果警告：字节 1679728 处的属性(3006,0040)可能错误地解释为显式 VR建使用此代码
        %RSinfo=dicominfo(filename);
        %记住RS当前的行号信息
        rs_row_to_delete = i;
    end
end
folders(rs_row_to_delete) = [];  %删除当前的RS的文件目录，只剩下dose文件 RS和P1-orim不能同时处理 由于删除元素会更改数目索引
%因此分开处理

folder_len = size(folders,1);%更新文件目录长度
for i = 1 : folder_len
    if contains(folders(i).name,'orim')
        filename = fullfile(folders(i).folder,folders(i).name);
        info_ori = dicominfo(filename);
        dose_ori = dicomread(filename);
        size_ori = size(dose_ori);
        %记住当前ori的行号信息
        ori_row_to_delete = i;
    end
end
folders(ori_row_to_delete) = [];  %删除当前的参考p1-orim的文件目录，只剩下其他RD文件

%当头颈部请注释后续代码此时不包括
%%{
folder_len = size(folders,1);%更新文件目录长度
for i = 1 : folder_len
    if contains(folders(i).name,'Bori')
        filename = fullfile(folders(i).folder,folders(i).name);
        info_Bori = dicominfo(filename);    %bladder原始剂量文件导入
        dose_Bori = dicomread(filename);
        size_Bori = size(dose_Bori);
        %记住当前ori的行号信息
        Bori_row_to_delete = i;
    end
end
folders(Bori_row_to_delete) = [];  %删除当前的参考p1-Bori的文件目录，只剩下其他RD文件
%}

%% 剂量相减计算差异diff-dose

%新建差异文件夹用于保存数据
newfile = info_ori.PatientID;
%%预期生成Diff_DICOM的保存路径
newfilepath = fullfile("E:\医学物理\待投稿论文\Dolphin\DeepLearning_DATA",newfile);
[status, msg, msgID] = mkdir(newfilepath);

folder_len = size(folders,1); %在更新获取文件长度

%%%开始读取文件剂量剂量差异
for i = 1 : folder_len
    newfile = fullfile(folders(i).folder,folders(i).name);%逐个读取逐个计算
    info_new = dicominfo(newfile);
    
   

    %%%%调用子函数 尺寸匹配重采样计算公共区域的差异剂量  此为新函数，建议应采用统一的diff计算函数
    [dosediff, diff_info] = cal_diff(info_ori, info_new,RSinfo);


    %%%%%————————  形成dcm文件用于3Dslicer后期组学处理  ——————————%%%%%
    dosediff = dosediff /diff_info.DoseGridScaling;  %根据刻度进行归一
    
    [rows,cols,slices] = size(dosediff); 
    
    dosediff = reshape(dosediff,[rows,cols,1, slices]); %形成4D矩阵 用于后期封装
    dosediff = int32(dosediff); %double转换为有符号类型

    %将差异剂量图封装成Dicom数据保存回去 用于3D slicer数据处理
     for j = 1 : FileName_SIZE   %获取需要保存的文件名数据长度
        if contains(folders(i).name,FileName(j),"IgnoreCase",true) %不包含大小写对比文件名
            diff_info.SeriesInstanceUID = dicomuid();
            diff_info.SeriesDescription = char(FileName(j)); %用于SD
            diff_info.SOPInstanceUID = dicomuid();
            diff_info.PixelRepresentation = 1; %表明为有符号的数据  相减有正有负
            dosename = FileName(j)+".dcm";
            doefilename = fullfile(newfilepath,dosename);
            dicomwrite(dosediff,doefilename,diff_info,'CreateMode','copy');
        end
     end   
end
%%
%可视化验证
%测试例 显示不同分类差异图像
%BODYfile
BDname = "p1-body1.5"+".dcm";
BDfile = fullfile(newfilepath, BDname);
BDinfo = dicominfo(BDfile);
BDVolume = squeeze(double(dicomread(BDinfo)))*BDinfo.DoseGridScaling;
%Body变化测试图像
%BDVolume =permute(BDVolume,[2,3,1]);

%MUfile
MUname = "MU5%"+".dcm";
MUfile = fullfile(newfilepath, MUname);
MUinfo = dicominfo(MUfile);
MUVolume = squeeze(double(dicomread(MUinfo)))*MUinfo.DoseGridScaling; %MU测试图像
%MUVolume =permute(MUVolume,[2,3,1]);


%Gantryfile
GNname = "p1-0.4G"+".dcm";
GNfile = fullfile(newfilepath, GNname);
GNinfo = dicominfo(GNfile);
GNVolume =squeeze(double(dicomread(GNinfo)))*GNinfo.DoseGridScaling; %GN测试图像
%GNVolume =permute(GNVolume,[2,3,1]);


%MLCSfile
MLCSname = "p1-1X2F"+".dcm";
MLCSfile = fullfile(newfilepath, MLCSname);
MLCSinfo = dicominfo(MLCSfile);
MLCSVolume = squeeze(double(dicomread(MLCSinfo)))*MLCSinfo.DoseGridScaling; %MLC SYSTEM测试图像
%MLCSVolume =permute(MLCSVolume,[2,3,1]);


%MLCRfile
MLCRname = "p1-2X2R"+".dcm";
MLCRfile = fullfile(newfilepath, MLCRname);
MLCRinfo = dicominfo(MLCRfile);
MLCRVolume = squeeze(double(dicomread(MLCRinfo)))*MLCRinfo.DoseGridScaling; %MLC RADNOM测试图像
%MLCRVolume =permute(MLCRVolume,[2,3,1]);


%SETUP file
STname = "LAT-1mmR"+".dcm";
STfile = fullfile(newfilepath, STname);
STinfo = dicominfo(STfile);
STVolume =squeeze(double(dicomread(STinfo)))*STinfo.DoseGridScaling; %SET UP测试图像
%STVolume =permute(STVolume,[2,3,1]);

%ERRORFREE file
EFname = "P1-AXBW"+".dcm";
EFfile = fullfile(newfilepath, EFname);
EFinfo = dicominfo(EFfile);
EFVolume = squeeze(double(dicomread(EFinfo)))*EFinfo.DoseGridScaling; %SET UP测试图像
%EFVolume =permute(EFVolume,[2,3,1]);

%头颈部请注释掉
%%{
%Bladder file
Blname = "P1-B1"+".dcm";
BLfile = fullfile(newfilepath, Blname);
BLinfo = dicominfo(BLfile);
BLVolume =squeeze(double(dicomread(BLinfo)))*BLinfo.DoseGridScaling; %Bladder测试图像
%BLVolume =permute(BLVolume,[2,3,1]);
%}
imgidx  = 50;%想要显示的层面
figure(1),  
subplot(2,4,1),imagesc(BDVolume(:,:,imgidx)),title("BodyChanges");...
subplot(2,4,2),imagesc(MUVolume(:,:,imgidx)),title("MU");...
subplot(2,4,3),imagesc(GNVolume(:,:,imgidx)),title("Gantry");...
subplot(2,4,4),imagesc(MLCSVolume(:,:,imgidx)),title("MLCS");...
subplot(2,4,5),imagesc(MLCRVolume(:,:,imgidx)),title("MLCR");...
subplot(2,4,6),imagesc(EFVolume(:,:,imgidx)),title("Erorrfree");...
subplot(2,4,7),imagesc(STVolume(:,:,imgidx)),title("SetUp");
subplot(2,4,8),imagesc(BLVolume(:,:,imgidx)),title("Bladder");
%% 计算理想计划差异分布，即已P1-AXB作为ORI进行差异剂量计算

folder_len = size(folders,1);%更新文件目录长度
ID = info_ori.PatientID;
%获得原始AXB的文件名
oriAXBfilename = char("RD." + ID + ".P1-AXB"+".dcm");  %需要抓取文件的文件名，string转换为char以便后续对比

for i = 1 : folder_len
    if strcmpi(folders(i).name,oriAXBfilename)
        filename = fullfile(folders(i).folder,folders(i).name);
        info_ori = dicominfo(filename);
        dose_ori = dicomread(filename);
        size_ori = size(dose_ori);
        %记住当前ori的行号信息
        ori_row_to_delete = i;
    end
end
folders(ori_row_to_delete) = [];  %删除当前的参考p1-orim的文件目录，只剩下其他RD文件
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%以理想的AXB作为ori
%更新后面剂量差异信息的文件命名格式  删除p1-AXB命名
FileName = ["LAT-1mmL";"LAT-1mmR";"Lng-1mmF";"Lng-1mmH";"Vrt-1mmA";"Vrt-1mmP";...
            "MU3%-";"MU3%";"MU5%-";"MU5%";"p1--0.2G";"p1--0.4G";"p1-0.2G";"p1-0.4G";...
            "p1--0.5X2F";"p1--1X2F";"p1-0.5X2F";"p1-1X2F";"p1-0.5X2R";"p1-1X2R";"p1-2X2R";"p1-AXBW";...
            "p1-AAA""p1-body0.5";"p1-body1";"p1-body1.5"];
%"p1-AXBW";"p1-AAA""p1-body0.5";"p1-body1";"p1-body1.5"
%"P1-B0.5";"P1+B0.5";"P1-B1";"P1+B1"  %头颈部的时候可以删除上述代码中的这部分内容

FileName_SIZE = size(FileName,1);%更新需要处理文件名数组的长度


%新建差异文件夹用于保存数据  该句多余可以省略
folder_len = size(folders,1); %在更新获取文件长度

%%%开始读取文件剂量剂量差异
for i = 1 : folder_len
    newfile = fullfile(folders(i).folder,folders(i).name);%逐个读取逐个计算
    info_new = dicominfo(newfile);

    %裁剪计算差异
    [dosediff, diff_info] = cal_diff(info_ori, info_new,RSinfo);    

    %%%%%————————  形成dcm文件用于3Dslicer后期组学处理  ——————————%%%%%
    dosediff = dosediff /diff_info.DoseGridScaling;  %根据刻度进行归一
    
    [rows,cols,slices] = size(dosediff); 
    
    dosediff = reshape(dosediff,[rows,cols,1, slices]); %形成4D矩阵 用于后期封装
    dosediff = int32(dosediff); %double转换为有符号类型

    %将差异剂量图封装成Dicom数据保存回去 用于3D slicer数据处理
     for j = 1 : FileName_SIZE   %获取需要保存的文件名数据长度
        if contains(folders(i).name,FileName(j),"IgnoreCase",true) %不包含大小写对比文件名
            diff_info.SeriesInstanceUID = dicomuid();
            diff_info.SeriesDescription = char(FileName(j)); %用于SD
            diff_info.SOPInstanceUID = dicomuid();
            diff_info.PixelRepresentation = 1; %表明为有符号的数据  相减有正有负
            dosename = FileName(j)+"-AXBori"+".dcm";
            dosefilename = fullfile(newfilepath,dosename);
            dicomwrite(dosediff,dosefilename,diff_info,'CreateMode','copy');
        end
     end   
end
%% 计算AXBW-AAA的差异剂量分布

%获得原始AXB的文件名
AXBWfilename = "RD." + ID + ".P1-AXBW"+".dcm";  %需要抓取文件的文件名，string转换为char以便后续对比
AAAfilename = "RD." + ID + ".P1-AAA"+".dcm";  %需要抓取文件的文件名，string转换为char以便后续对比

filepath = folders.folder;

%读取AXBW文件
newfile = fullfile(filepath,AXBWfilename);
info_new = dicominfo(newfile);

ori_file = fullfile(filepath,AAAfilename);
info_ori = dicominfo(ori_file);

%调用子函数 尺寸匹配重采样计算公共区域的差异剂量
%裁剪计算差异
[dosediff, diff_info] = cal_diff(info_ori, info_new,RSinfo);   

%%%%%————————  形成dcm文件用于3Dslicer后期组学处理  ——————————%%%%%
dosediff = dosediff /diff_info.DoseGridScaling;  %根据刻度进行归一    
[rows,cols,slices] = size(dosediff);     
dosediff = reshape(dosediff, [rows,cols,1, slices]); %形成4D矩阵 用于后期封装
dosediff = int32(dosediff); %double转换为有符号类型

%将差异剂量图封装成Dicom数据保存回去 用于3D slicer数据处理
diff_info.SeriesInstanceUID = dicomuid();
diff_info.SeriesDescription = char("AXBW-AAAori"); %用于SD %必须用char类型 string类型可能会报错
diff_info.SOPInstanceUID = dicomuid();
diff_info.PixelRepresentation = 1; %表明为有符号的数据  相减有正有负
dosename = strcat('AXBW-AAAori','.dcm');
dosefilename = fullfile(newfilepath, dosename);
dicomwrite(dosediff,dosefilename, diff_info, 'CreateMode', 'copy');
%% 计算Bladder的差异剂量分布


%头颈部请注释后续代码

%%{
%以Bodyori作为reference文件
%更新后面剂量差异信息的文件命名格式  删除p1-AXB命名
FileName = ["P1-B0.5";"P1+B0.5";"P1-B1";"P1+B1"];

FileName_SIZE = size(FileName,1);%更新需要处理文件名数组的长度

filepath = folders.folder;

%逐个读取AXBW文件
for i = 1:FileName_SIZE
    %获得Bladder外扩的文件名
    Bladder_filename = "RD." + ID + "."+ FileName(i) + ".dcm";  %需要抓取文件的文件名，string转换为char以便后续对比

    %获取完整路径
    newfile = fullfile(filepath,Bladder_filename);
    info_new = dicominfo(newfile);

    fprintf("开始计算%s剂量差异分布!\n       \n",FileName(i));

    %调用子函数 尺寸匹配重采样计算公共区域的差异剂量
     %裁剪计算差异
    [dosediff, diff_info] = cal_diff(info_Bori, info_new,RSinfo);    %%这里使用info_Bori

    %%%%%————————  形成dcm文件用于3Dslicer后期组学处理  ——————————%%%%%
    dosediff = dosediff /diff_info.DoseGridScaling;  %根据刻度进行归一    
    [rows,cols,slices] = size(dosediff);     
    dosediff = reshape(dosediff,[rows,cols,1, slices]); %形成4D矩阵 用于后期封装
    dosediff = int32(dosediff); %double转换为有符号类型

    %将差异剂量图封装成Dicom数据保存回去 用于3D slicer数据处理
    diff_info.SeriesInstanceUID = dicomuid();
    diff_info.SeriesDescription = char(FileName(i)); %用于SD
    diff_info.SOPInstanceUID = dicomuid();
    diff_info.PixelRepresentation = 1; %表明为有符号的数据  相减有正有负
    dosename = FileName(i)+"-AXBori.dcm";
    dosefilename = fullfile(newfilepath,dosename);
    dicomwrite(dosediff,dosefilename,diff_info,'CreateMode','copy');
end
%}

%%
%可视化验证
%测试例 显示不同分类差异图像
%%{
%BODYfile
BDname = "p1-body1.5"+"-AXBori"+".dcm";
BDfile = fullfile(newfilepath, BDname);
BDinfo = dicominfo(BDfile);
BDVolume = squeeze(double(dicomread(BDinfo)))*BDinfo.DoseGridScaling;
%Body变化测试图像
%BDVolume =permute(BDVolume,[2,3,1]);
%}
%MUfile
MUname = "MU5%"+"-AXBori"+".dcm";
MUfile = fullfile(newfilepath, MUname);
MUinfo = dicominfo(MUfile);
MUVolume = squeeze(double(dicomread(MUinfo)))*MUinfo.DoseGridScaling; %MU测试图像
%MUVolume =permute(MUVolume,[2,3,1]);


%Gantryfile
GNname = "p1-0.4G"+"-AXBori"+".dcm";
GNfile = fullfile(newfilepath, GNname);
GNinfo = dicominfo(GNfile);
GNVolume =squeeze(double(dicomread(GNinfo)))*GNinfo.DoseGridScaling; %GN测试图像
%GNVolume =permute(GNVolume,[2,3,1]);


%MLCSfile
MLCSname = "p1-1X2F"+"-AXBori"+".dcm";
MLCSfile = fullfile(newfilepath, MLCSname);
MLCSinfo = dicominfo(MLCSfile);
MLCSVolume = squeeze(double(dicomread(MLCSinfo)))*MLCSinfo.DoseGridScaling; %MLC SYSTEM测试图像
%MLCSVolume =permute(MLCSVolume,[2,3,1]);


%MLCRfile
MLCRname = "p1-2X2R"+"-AXBori"+".dcm";
MLCRfile = fullfile(newfilepath, MLCRname);
MLCRinfo = dicominfo(MLCRfile);
MLCRVolume = squeeze(double(dicomread(MLCRinfo)))*MLCRinfo.DoseGridScaling; %MLC RADNOM测试图像
%MLCRVolume =permute(MLCRVolume,[2,3,1]);


%SETUP file
STname = "LAT-1mmR"+"-AXBori"+".dcm";
STfile = fullfile(newfilepath, STname);
STinfo = dicominfo(STfile);
STVolume =squeeze(double(dicomread(STinfo)))*STinfo.DoseGridScaling; %SET UP测试图像
%STVolume =permute(STVolume,[2,3,1]);

%ERRORFREE file
EFname = "P1-AXBW"+"-AXBori"+".dcm";
EFfile = fullfile(newfilepath, EFname);
EFinfo = dicominfo(EFfile);
EFVolume = squeeze(double(dicomread(EFinfo)))*EFinfo.DoseGridScaling; %SET UP测试图像
%EFVolume =permute(EFVolume,[2,3,1]);

%头颈部请注释掉
%%{
%Bladder file
Blname = "P1-B1"+"-AXBori"+".dcm";
BLfile = fullfile(newfilepath, Blname);
BLinfo = dicominfo(BLfile);
BLVolume =squeeze(double(dicomread(BLinfo)))*BLinfo.DoseGridScaling; %Bladder测试图像
%BLVolume =permute(BLVolume,[2,3,1]);
%}
imgidx  = 50;%想要显示的层面
figure(2),  
subplot(2,4,1),imagesc(BDVolume(:,:,imgidx)),title("BodyChanges");...
subplot(2,4,2),imagesc(MUVolume(:,:,imgidx)),title("MU");...
subplot(2,4,3),imagesc(GNVolume(:,:,imgidx)),title("Gantry");...
subplot(2,4,4),imagesc(MLCSVolume(:,:,imgidx)),title("MLCS");...
subplot(2,4,5),imagesc(MLCRVolume(:,:,imgidx)),title("MLCR");...
subplot(2,4,6),imagesc(EFVolume(:,:,imgidx)),title("Erorrfree");...
subplot(2,4,7),imagesc(STVolume(:,:,imgidx)),title("SetUp");
subplot(2,4,8),imagesc(BLVolume(:,:,imgidx)),title("Bladder");

%%