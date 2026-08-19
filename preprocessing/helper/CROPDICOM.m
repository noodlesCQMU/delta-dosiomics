function [crop_new,crop_ori,crop_info]=CROPDICOM(info_new,info_ori)
data_ori=uint32(dicomread(info_ori));
data_new=uint32(dicomread(info_new)); %确保都是uint32位
size_ori=size(data_ori);
disp(size_ori);

size_new=size(data_new);
disp(size_new);

fprintf('两者尺寸相等无需裁剪\n');
crop_info=info_ori;  %复制DICOM_info

pixelSpacing_ori=info_ori.PixelSpacing;  %获取原始的像素分辨率
pixelSpacing_new=info_new.PixelSpacing;  %获取新的像素分辨率

imagePositionPatient_ori=info_ori.ImagePositionPatient;%获取位置信以便后期裁剪
imagePositionPatient_new=info_new.ImagePositionPatient;%获取位置信以便后期裁剪

if isequal(size_new,size_ori)
    crop_ori=data_ori;   
    crop_new=data_new;  %如果尺寸一致则不需要裁剪
    fprintf('两者尺寸相等无需裁剪\n');
else
    %计算两者的覆盖空间覆盖范围，如果有差异则需要裁剪
    xrange_ori=[imagePositionPatient_ori(1),imagePositionPatient_ori(1)+(size_ori(2)-1)*pixelSpacing_ori(1)];
    xrange_new=[imagePositionPatient_new(1),imagePositionPatient_new(1)+(size_new(2)-1)*pixelSpacing_new(1)];
    yrange_ori=[imagePositionPatient_ori(2),imagePositionPatient_ori(2)+(size_ori(1)-1)*pixelSpacing_ori(2)];
    yrange_new=[imagePositionPatient_new(2),imagePositionPatient_new(2)+(size_new(1)-1)*pixelSpacing_new(2)];

    %判断是否阵列x维度是否相同相等
    if isequal(size_new(2),size_ori(2))
        xrange_two=xrange_ori;
        xStart_ori =1; %原始矩阵的起始位置
        xEnd_ori=size_ori(2);
        xStart_new= 1;%新矩阵的起始位置
        xEnd_new =size_new(2);
        fprintf('X维度尺寸相同，使用原始维度!\n');
    else
        fprintf('X维度有差异，进行裁剪!\n');
        xrange_two=[max(xrange_ori(1),xrange_new(1)),min(xrange_ori(2),xrange_new(2))];  %计算X的裁剪范围
        xStart_ori = round((xrange_two(1) - imagePositionPatient_ori(1)) / pixelSpacing_ori(1)) + 1; %原始矩阵的起始位置
        xEnd_ori= round((xrange_two(2) - imagePositionPatient_ori(1)) / pixelSpacing_ori(1)) + 1;
        xStart_new= round((xrange_two(1) - imagePositionPatient_new(1)) / pixelSpacing_new(1)) + 1;%新矩阵的起始位置
        xEnd_new = round((xrange_two(2) - imagePositionPatient_new(1)) / pixelSpacing_new(1)) + 1;
        crop_info.ImagePositionPatient(1)=xrange_two(1);
    end

    %判断y维度
    if isequal(size_ori(1),size_new(1))
        yStart_ori =1; %原始矩阵的起始位置
        yEnd_ori= size_ori(1);
        yStart_new= 1;%新矩阵的起始位置
        yEnd_new =size_new(1);
        fprintf('Y维度尺寸相同，使用原始维度!\n');
    else
        fprintf('Y维度有差异，进行裁剪!\n');
        yrange_two=[max(yrange_ori(1),yrange_new(1)),min(yrange_ori(2),yrange_new(2))]; %计算y的裁剪范围
        yStart_ori = round((yrange_two(1) - imagePositionPatient_ori(2)) / pixelSpacing_ori(2)) + 1; %原始矩阵的起始位置
        yEnd_ori= round((yrange_two(2) - imagePositionPatient_ori(2)) / pixelSpacing_ori(2)) + 1;
        yStart_new= round((yrange_two(1) - imagePositionPatient_new(2)) / pixelSpacing_new(2)) + 1;%新矩阵的起始位置
        yEnd_new = round((yrange_two(2) - imagePositionPatient_new(2)) / pixelSpacing_new(2)) + 1;
        crop_info.ImagePositionPatient(2)=yrange_two(1);
    end

    %判断z维度
    if isequal(size_ori(4),size_new(4))
        zStart_ori=1;%原始矩阵的起始位置
        zEnd_ori=size_ori(4);
        zStart_new=1;%新矩阵的位置
        zEnd_new=size_new(4);
        fprintf('Z维度尺寸相同，使用原始维度!\n');
    else
        fprintf('Z维度有差异，进行裁剪!\n');
        %通过GridFrameoffsetVector来计算公共区域
        grid_ori=info_ori.GridFrameOffsetVector;
        grid_new=info_new.GridFrameOffsetVector;
        
        %找到图像的起始位置
        zposition_ori=imagePositionPatient_ori(3)+grid_ori;
        zposition_new=imagePositionPatient_new(3)+grid_new;
        
        %找到公共范围区域
        ZminCommon=max(min(zposition_ori),min(zposition_new));
        ZmaxCommon=min(max(zposition_ori),max(zposition_new));
        
        zStart_ori=find(zposition_ori>=ZminCommon,1);  %找到zpos中大于等于共同最小区域的索引值
        zEnd_ori=find(zposition_ori<=ZmaxCommon,1,'last');%从尾部开始搜索小于等于共同最大区域的索引值
        zStart_new=find(zposition_new>=ZminCommon,1);
        zEnd_new=find(zposition_new<=ZmaxCommon,1,'last');
        crop_info.ImagePositionPatient(3)=ZminCommon;
    end

    crop_ori=data_ori(yStart_ori:yEnd_ori,xStart_ori:xEnd_ori,:,zStart_ori:zEnd_ori);
    crop_new=data_new(yStart_new:yEnd_new,xStart_new:xEnd_new,:,zStart_new:zEnd_new);
    disp(crop_info.ImagePositionPatient);
end