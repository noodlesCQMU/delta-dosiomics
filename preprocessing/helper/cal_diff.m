function [Dose_diff, Diff_info] = cal_diff(dose_ori_info, dose_new_info, rs_info)
%CAL_DIFF  基于 RS 中 Body 最大外接长方体与剂量公共区域交集计算剂量差异
%
%   [Dose_diff, Diff_info] = cal_diff(dose_ori_info, dose_new_info, rs_info)
%
%   输入：
%       dose_ori_info : 原始 / 参考 RT Dose 的 dicominfo 结构体
%       dose_new_info : 新 RT Dose 的 dicominfo 结构体
%       rs_info       : RT Structure 的 dicominfo 结构体
%
%   输出：
%       Dose_diff : 裁剪后的 3D 剂量差异矩阵，单位 Gy
%                   Dose_diff = Dose_new_crop - Dose_ori_on_new_crop
%
%       Diff_info : copy dose_new_info 后修改得到的 DICOM info
%
%   核心原则：
%       1. 以 dose_new_info 的剂量网格作为输出网格；
%       2. 从 RT Structure 中寻找 ROIName 包含 "Body" 的结构；
%       3. 若有多个 Body 候选，选择最大外接长方体体积最大的那个；
%       4. 计算区域为：
%
%              Body 最大外接长方体
%          ∩   Dose_new 剂量区域
%          ∩   Dose_ori 剂量区域
%
%       5. 输出 Dose_diff 是裁剪后的三维矩阵；
%       6. 不使用 mask 将非 Body 区域置 0；
%       7. Dose_ori 若与 Dose_new 网格不一致，会插值到 Dose_new 裁剪网格。

%% ============================================================
%  1. 输入检查
%% ============================================================

if ~isfield(dose_ori_info, 'Filename')
    error('dose_ori_info 缺少 Filename 字段，无法读取 Dose_ori DICOM。');
end

if ~isfield(dose_new_info, 'Filename')
    error('dose_new_info 缺少 Filename 字段，无法读取 Dose_new DICOM。');
end

if ~isfield(rs_info, 'StructureSetROISequence')
    error('rs_info 缺少 StructureSetROISequence，可能不是 RT Structure 文件。');
end

if ~isfield(rs_info, 'ROIContourSequence')
    error('rs_info 缺少 ROIContourSequence，无法读取 ROI 轮廓信息。');
end

fprintf('\n================ cal_diff 开始 ================\n');
fprintf('Dose_ori 文件: %s\n', dose_ori_info.Filename);
fprintf('Dose_new 文件: %s\n', dose_new_info.Filename);

%% ============================================================
%  2. 读取 RT Dose，并转换为 Gy
%% ============================================================

Dose_ori = readRTDoseAsGy(dose_ori_info);
Dose_new = readRTDoseAsGy(dose_new_info);

Dose_ori = double(Dose_ori);
Dose_new = double(Dose_new);

if ndims(Dose_ori) ~= 3
    error('Dose_ori 不是三维剂量矩阵，请检查 DICOM。');
end

if ndims(Dose_new) ~= 3
    error('Dose_new 不是三维剂量矩阵，请检查 DICOM。');
end

fprintf('Dose_ori size = [%s]\n', num2str(size(Dose_ori)));
fprintf('Dose_new size = [%s]\n', num2str(size(Dose_new)));

%% ============================================================
%  3. 获取 Dose_ori 和 Dose_new 的患者物理坐标轴
%
%  MATLAB 剂量矩阵维度：
%       Dose(row, col, slice)
%
%  对应患者坐标：
%       row   -> Y
%       col   -> X
%       slice -> Z
%% ============================================================

[xOri, yOri, zOri] = getDoseAxesPatient(dose_ori_info, size(Dose_ori));
[xNew, yNew, zNew] = getDoseAxesPatient(dose_new_info, size(Dose_new));

fprintf('\nDose_ori 物理范围:\n');
fprintf('X: %.3f ~ %.3f mm\n', min(xOri), max(xOri));
fprintf('Y: %.3f ~ %.3f mm\n', min(yOri), max(yOri));
fprintf('Z: %.3f ~ %.3f mm\n', min(zOri), max(zOri));

fprintf('\nDose_new 物理范围:\n');
fprintf('X: %.3f ~ %.3f mm\n', min(xNew), max(xNew));
fprintf('Y: %.3f ~ %.3f mm\n', min(yNew), max(yNew));
fprintf('Z: %.3f ~ %.3f mm\n', min(zNew), max(zNew));

%% ============================================================
%  4. 从 RT Structure 中获取 Body 最大外接长方体
%% ============================================================

bodyBox = getLargestBodyBoundingBox(rs_info);

fprintf('\n选择的 Body 最大外接长方体:\n');
fprintf('ROIName   : %s\n', bodyBox.roiName);
fprintf('ROINumber : %d\n', bodyBox.roiNumber);
fprintf('X: %.3f ~ %.3f mm, LenX = %.3f mm\n', ...
    bodyBox.xMin, bodyBox.xMax, bodyBox.lenX);
fprintf('Y: %.3f ~ %.3f mm, LenY = %.3f mm\n', ...
    bodyBox.yMin, bodyBox.yMax, bodyBox.lenY);
fprintf('Z: %.3f ~ %.3f mm, LenZ = %.3f mm\n', ...
    bodyBox.zMin, bodyBox.zMax, bodyBox.lenZ);
fprintf('外接长方体体积: %.3f mm^3\n', bodyBox.volume);

%% ============================================================
%  5. 计算 Body 最大长方体与两套剂量区域的空间交集
%
%  交集区域：
%       Body bounding box
%       ∩ Dose_new physical extent
%       ∩ Dose_ori physical extent
%% ============================================================

xMin = max([bodyBox.xMin, min(xNew), min(xOri)]);
xMax = min([bodyBox.xMax, max(xNew), max(xOri)]);

yMin = max([bodyBox.yMin, min(yNew), min(yOri)]);
yMax = min([bodyBox.yMax, max(yNew), max(yOri)]);

zMin = max([bodyBox.zMin, min(zNew), min(zOri)]);
zMax = min([bodyBox.zMax, max(zNew), max(zOri)]);

if xMin >= xMax || yMin >= yMax || zMin >= zMax
    error('Body 最大长方体与两套剂量区域没有有效三维交集。');
end

fprintf('\n最终空间交集范围:\n');
fprintf('X: %.3f ~ %.3f mm\n', xMin, xMax);
fprintf('Y: %.3f ~ %.3f mm\n', yMin, yMax);
fprintf('Z: %.3f ~ %.3f mm\n', zMin, zMax);

%% ============================================================
%  6. 在 Dose_new 网格上寻找该交集对应的裁剪索引
%
%  注意：
%       这里不是生成 mask 后置零，
%       而是直接裁剪出矩形子矩阵。
%% ============================================================

tolX = estimateAxisTolerance(xNew);
tolY = estimateAxisTolerance(yNew);
tolZ = estimateAxisTolerance(zNew);

ixCrop = find(xNew >= xMin - tolX & xNew <= xMax + tolX);
iyCrop = find(yNew >= yMin - tolY & yNew <= yMax + tolY);
izCrop = find(zNew >= zMin - tolZ & zNew <= zMax + tolZ);

if isempty(ixCrop) || isempty(iyCrop) || isempty(izCrop)
    error('交集区域在 Dose_new 网格中没有有效体素。');
end

fprintf('\nDose_new 裁剪索引范围:\n');
fprintf('Rows    Y index: %d ~ %d, 共 %d\n', ...
    min(iyCrop), max(iyCrop), numel(iyCrop));
fprintf('Columns X index: %d ~ %d, 共 %d\n', ...
    min(ixCrop), max(ixCrop), numel(ixCrop));
fprintf('Frames  Z index: %d ~ %d, 共 %d\n', ...
    min(izCrop), max(izCrop), numel(izCrop));

%% ============================================================
%  7. 裁剪 Dose_new
%% ============================================================

Dose_new_crop = Dose_new(iyCrop, ixCrop, izCrop);

xCrop = xNew(ixCrop);
yCrop = yNew(iyCrop);
zCrop = zNew(izCrop);

fprintf('\nDose_new_crop size = [%s]\n', num2str(size(Dose_new_crop)));

%% ============================================================
%  8. 将 Dose_ori 插值到 Dose_new 的裁剪网格上
%% ============================================================

[Dose_ori_sorted, yOri_sorted, xOri_sorted, zOri_sorted] = ...
    sortDoseForInterpolation(Dose_ori, yOri, xOri, zOri);

F_ori = griddedInterpolant( ...
    {yOri_sorted, xOri_sorted, zOri_sorted}, ...
    Dose_ori_sorted, ...
    'linear', ...
    'none');

[YcropGrid, XcropGrid, ZcropGrid] = ndgrid(yCrop, xCrop, zCrop);

Dose_ori_crop_on_new = F_ori(YcropGrid, XcropGrid, ZcropGrid);

if any(isnan(Dose_ori_crop_on_new(:)))
    error(['裁剪区域内仍存在 Dose_ori 插值失败的点。' ...
           '说明交集边界可能超出了 Dose_ori 的实际网格范围，请检查坐标或适当缩小边界。']);
end

%% ============================================================
%  9. 直接计算裁剪矩阵内的 Dose_new - Dose_ori
%
%  这里不使用 mask，也不把任何非 Body 区域置零。
%  Dose_diff 本身就是裁剪后的长方体矩阵。
%% ============================================================

Dose_diff = Dose_new_crop - Dose_ori_crop_on_new;

fprintf('\nDose_diff size = [%s]\n', num2str(size(Dose_diff)));
fprintf('Dose_new_crop 范围: %.6f ~ %.6f Gy\n', ...
    min(Dose_new_crop(:)), max(Dose_new_crop(:)));
fprintf('Dose_ori_crop_on_new 范围: %.6f ~ %.6f Gy\n', ...
    min(Dose_ori_crop_on_new(:)), max(Dose_ori_crop_on_new(:)));
fprintf('Dose_diff 范围: %.6f ~ %.6f Gy\n', ...
    min(Dose_diff(:)), max(Dose_diff(:)));

%% ============================================================
%  10. 构建输出 Diff_info
%
%  因为 Dose_diff 已经被裁剪，所以必须同步修改：
%       Rows
%       Columns
%       NumberOfFrames
%       ImagePositionPatient
%       GridFrameOffsetVector
%% ============================================================

Diff_info = dose_new_info;

Diff_info.Rows = size(Dose_diff, 1);
Diff_info.Columns = size(Dose_diff, 2);
Diff_info.NumberOfFrames = size(Dose_diff, 3);

% 更新 UID，避免与原始 DICOM 冲突
Diff_info.SOPInstanceUID = dicomuid;
Diff_info.SeriesInstanceUID = dicomuid;

if isfield(Diff_info, 'MediaStorageSOPInstanceUID')
    Diff_info.MediaStorageSOPInstanceUID = Diff_info.SOPInstanceUID;
end

% 更新裁剪后第一层左上角体素的物理位置
% 这里按常规横断面 RT Dose 处理：
%   ImagePositionPatient = [第一个 col 的 X, 第一个 row 的 Y, 第一个 slice 的 Z]
newIPP = double(dose_new_info.ImagePositionPatient(:));
newIPP(1) = xCrop(1);
newIPP(2) = yCrop(1);
newIPP(3) = zCrop(1);

Diff_info.ImagePositionPatient = newIPP;

% 更新 GridFrameOffsetVector
% 推荐改为相对于新 ImagePositionPatient(3) 的偏移，使第一层为 0
Diff_info.GridFrameOffsetVector = zCrop(:) - zCrop(1);

% 更新描述信息
Diff_info.SeriesDescription = 'Cropped dose difference: Dose_new minus Dose_ori';
Diff_info.DoseComment = 'Dose_new - Dose_ori in intersection of Body bounding box and dose regions';

% 差异剂量可能为负值，建议后续写出为 signed int16
Diff_info.PixelRepresentation = 1;   % 1 = signed integer

% 建议 DoseGridScaling

% 更新时间
Diff_info.ContentDate = datestr(now, 'yyyymmdd');
Diff_info.ContentTime = datestr(now, 'HHMMSS');

fprintf('\n输出 Diff_info 已更新:\n');
fprintf('Rows = %d\n', Diff_info.Rows);
fprintf('Columns = %d\n', Diff_info.Columns);
fprintf('NumberOfFrames = %d\n', Diff_info.NumberOfFrames);
fprintf('ImagePositionPatient = [%.3f %.3f %.3f]\n', ...
    Diff_info.ImagePositionPatient(1), ...
    Diff_info.ImagePositionPatient(2), ...
    Diff_info.ImagePositionPatient(3));
fprintf('DoseGridScaling = %.12g\n', Diff_info.DoseGridScaling);

fprintf('================ cal_diff 完成 ================\n\n');

end


%% ========================================================================
%  子函数 1：读取 RT Dose 并转换为 Gy
%% ========================================================================

function DoseGy = readRTDoseAsGy(info)

raw = dicomread(info.Filename);
raw = squeeze(raw);
raw = double(raw);

if ndims(raw) == 2
    raw = reshape(raw, size(raw, 1), size(raw, 2), 1);
end

if isfield(info, 'DoseGridScaling')
    DoseGy = raw .* double(info.DoseGridScaling);
elseif isfield(info, 'RescaleSlope')
    slope = double(info.RescaleSlope);

    if isfield(info, 'RescaleIntercept')
        intercept = double(info.RescaleIntercept);
    else
        intercept = 0;
    end

    DoseGy = raw .* slope + intercept;
else
    warning('当前 RT Dose 中未发现 DoseGridScaling 或 RescaleSlope，直接使用原始像素值。');
    DoseGy = raw;
end

end


%% ========================================================================
%  子函数 2：获取 RT Dose 的患者物理坐标轴
%% ========================================================================

function [xVec, yVec, zVec] = getDoseAxesPatient(info, doseSize)
%GETDOSEAXESPATIENT 获取 RT Dose 网格在患者坐标系下的 X/Y/Z 坐标
%
%   对于常规横断面 RT Dose：
%       Dose(row, col, slice)
%       row   -> Y
%       col   -> X
%       slice -> Z

nRows = doseSize(1);
nCols = doseSize(2);

if numel(doseSize) >= 3
    nFrames = doseSize(3);
else
    nFrames = 1;
end

if ~isfield(info, 'ImagePositionPatient')
    error('RT Dose 缺少 ImagePositionPatient。');
end

if ~isfield(info, 'PixelSpacing')
    error('RT Dose 缺少 PixelSpacing。');
end

IPP = double(info.ImagePositionPatient(:));
PixelSpacing = double(info.PixelSpacing(:));

rowSpacing = PixelSpacing(1);
colSpacing = PixelSpacing(2);

% 默认常规横断面剂量网格
xVec = IPP(1) + (0:nCols-1) .* colSpacing;
yVec = IPP(2) + (0:nRows-1) .* rowSpacing;

% 检查 ImageOrientationPatient
if isfield(info, 'ImageOrientationPatient')
    IOP = double(info.ImageOrientationPatient(:));

    standardAxial = norm(IOP(:) - [1;0;0;0;1;0]) < 1e-4;

    if ~standardAxial
        warning(['当前 RT Dose 的 ImageOrientationPatient 并非标准横断面 [1 0 0 0 1 0]。' ...
                 '本函数仍按常规横断面方式计算坐标，请确认剂量方向。']);
    end
end

% Z 方向
if isfield(info, 'GridFrameOffsetVector')
    gfov = double(info.GridFrameOffsetVector(:));

    if numel(gfov) ~= nFrames
        warning('GridFrameOffsetVector 数量与 Dose 帧数不一致。');
    end

    if abs(gfov(1)) < 1e-6
        % GFOV 是相对 IPP(3) 的偏移
        zVec = IPP(3) + gfov(:)';
    elseif abs(gfov(1) - IPP(3)) < 1e-3
        % GFOV 可能本身是绝对 Z 坐标
        zVec = gfov(:)';
    else
        % 保守处理为相对 IPP(3)
        zVec = IPP(3) + gfov(:)';
    end
else
    if isfield(info, 'SliceThickness')
        dz = double(info.SliceThickness);
    else
        dz = 1;
        warning('缺少 GridFrameOffsetVector 和 SliceThickness，暂以 1 mm 作为 Z 间距。');
    end

    zVec = IPP(3) + (0:nFrames-1) .* dz;
end

end


%% ========================================================================
%  子函数 3：为 griddedInterpolant 排序剂量矩阵
%% ========================================================================

function [DoseSorted, ySorted, xSorted, zSorted] = sortDoseForInterpolation(Dose, yVec, xVec, zVec)

[ySorted, iy] = sort(yVec, 'ascend');
[xSorted, ix] = sort(xVec, 'ascend');
[zSorted, iz] = sort(zVec, 'ascend');

DoseSorted = Dose(iy, ix, iz);

end


%% ========================================================================
%  子函数 4：从 RT Structure 获取 Body 最大外接长方体
%% ========================================================================

function bodyBox = getLargestBodyBoundingBox(rs_info)

roiMap = getROINameNumberMap(rs_info);

roiNumbers = roiMap.ROINumber;
roiNames = roiMap.ROIName;

isBody = contains(lower(roiNames), 'body');

if ~any(isBody)
    error('RT Structure 中未找到 ROIName 包含 "Body" 的结构。');
end

bodyROINumbers = roiNumbers(isBody);
bodyROINames = roiNames(isBody);

fprintf('\n发现 Body 候选 ROI 数量: %d\n', numel(bodyROINumbers));

for i = 1:numel(bodyROINumbers)
    fprintf('  Candidate %d: ROINumber = %d, ROIName = %s\n', ...
        i, bodyROINumbers(i), bodyROINames(i));
end

bestVolume = -inf;
bestBox = struct();

for i = 1:numel(bodyROINumbers)

    roiNumber = bodyROINumbers(i);
    roiName = bodyROINames(i);

    pts = collectContourPointsByROINumber(rs_info, roiNumber);

    if isempty(pts)
        warning('ROIName = %s 未提取到 ContourData，跳过。', roiName);
        continue;
    end

    xMin = min(pts(:,1));
    xMax = max(pts(:,1));

    yMin = min(pts(:,2));
    yMax = max(pts(:,2));

    zMin = min(pts(:,3));
    zMax = max(pts(:,3));

    lenX = xMax - xMin;
    lenY = yMax - yMin;
    lenZ = zMax - zMin;

    volume = lenX * lenY * lenZ;

    fprintf('\nBody候选: %s\n', roiName);
    fprintf('  X: %.3f ~ %.3f, LenX = %.3f mm\n', xMin, xMax, lenX);
    fprintf('  Y: %.3f ~ %.3f, LenY = %.3f mm\n', yMin, yMax, lenY);
    fprintf('  Z: %.3f ~ %.3f, LenZ = %.3f mm\n', zMin, zMax, lenZ);
    fprintf('  外接长方体体积 = %.3f mm^3\n', volume);

    if lenX <= 0 || lenY <= 0 || lenZ <= 0 || ~isfinite(volume)
        warning('ROIName = %s 的外接长方体无效，跳过。', roiName);
        continue;
    end

    if volume > bestVolume
        bestVolume = volume;

        bestBox.xMin = xMin;
        bestBox.xMax = xMax;
        bestBox.yMin = yMin;
        bestBox.yMax = yMax;
        bestBox.zMin = zMin;
        bestBox.zMax = zMax;

        bestBox.lenX = lenX;
        bestBox.lenY = lenY;
        bestBox.lenZ = lenZ;
        bestBox.volume = volume;

        bestBox.roiName = roiName;
        bestBox.roiNumber = roiNumber;
    end
end

if isempty(fieldnames(bestBox))
    error('虽然找到了 Body 相关 ROI，但未能提取有效的最大外接长方体。');
end

bodyBox = bestBox;

end


%% ========================================================================
%  子函数 5：读取 ROIName 与 ROINumber 对应关系
%% ========================================================================

function roiMap = getROINameNumberMap(rs_info)

roiSeq = rs_info.StructureSetROISequence;
itemNames = fieldnames(roiSeq);

n = numel(itemNames);

roiNumbers = zeros(n, 1);
roiNames = strings(n, 1);

for i = 1:n

    item = roiSeq.(itemNames{i});

    if isfield(item, 'ROINumber')
        roiNumbers(i) = double(item.ROINumber);
    else
        roiNumbers(i) = NaN;
    end

    if isfield(item, 'ROIName')
        roiNames(i) = string(item.ROIName);
    else
        roiNames(i) = "";
    end
end

valid = ~isnan(roiNumbers) & roiNames ~= "";

roiMap = table(roiNumbers(valid), roiNames(valid), ...
    'VariableNames', {'ROINumber', 'ROIName'});

end


%% ========================================================================
%  子函数 6：根据 ROINumber 收集 ROI 的全部轮廓点
%% ========================================================================

function ptsAll = collectContourPointsByROINumber(rs_info, targetROINumber)

ptsAll = [];

roiContourSeq = rs_info.ROIContourSequence;
roiContourItems = fieldnames(roiContourSeq);

for i = 1:numel(roiContourItems)

    roiContourItem = roiContourSeq.(roiContourItems{i});

    if ~isfield(roiContourItem, 'ReferencedROINumber')
        continue;
    end

    refNumber = double(roiContourItem.ReferencedROINumber);

    if refNumber ~= targetROINumber
        continue;
    end

    if ~isfield(roiContourItem, 'ContourSequence')
        continue;
    end

    contourSeq = roiContourItem.ContourSequence;
    contourItems = fieldnames(contourSeq);

    for c = 1:numel(contourItems)

        contourItem = contourSeq.(contourItems{c});

        if ~isfield(contourItem, 'ContourData')
            continue;
        end

        contourData = double(contourItem.ContourData(:));

        if numel(contourData) < 9
            continue;
        end

        pts = reshape(contourData, 3, [])';
        % pts 每一行为 [x, y, z]

        ptsAll = [ptsAll; pts]; %#ok<AGROW>
    end
end

end


%% ========================================================================
%  子函数 7：估计坐标轴容差
%% ========================================================================

function tol = estimateAxisTolerance(axisVec)

axisVec = double(axisVec(:));
axisVec = sort(axisVec);

if numel(axisVec) < 2
    tol = 1e-6;
    return;
end

d = abs(diff(axisVec));
d = d(d > 0);

if isempty(d)
    tol = 1e-6;
else
    tol = min(d) * 1e-3;
end

end