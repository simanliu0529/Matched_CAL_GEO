function [Flag_VFM,Flag_VFM5, CAL_H, COD, Latitude_CPro] = Fun_Calculate_TargetH_LSM( ...
    filepath_CPro, TargetCOD, Latitude_5km, Latitude_VFM, Altitude_CAL, Reg)
% -------------------------------------------------------------------------
% Fun_Calculate_TargetH_LSM
% 目的：
%   1) 用 VFM 5km 纬度与 CPro 5km 中点纬度做连续段匹配（不使用时间）
%   2) 在匹配到的 CPro 5km profile 上积分得到 COD，并插值找到 TargetCOD 对应高度 TargetH
%   3) 将 TargetH 映射到 VFM 的 583 垂直 bins（输出行号 ClosestRow）
%   4) 将 CPro 的纬度 (start/mid/end) 扩展到 333m 维度：
%        start -> 每组第1点
%        mid   -> 每组第7点（按你的要求）
%        end   -> 每组第15点
%      组内其它点用线性插值填充
%
% 输入：
%   filepath_CPro : CPro 文件完整路径
%   TargetCOD     : 目标 COD (如 0.2)
%   Latitude_5km  : VFM 5km 纬度 (N5×1 或 1×N5)
%   Latitude_VFM  : VFM 333m 纬度 (N333×1 或 1×N333)
%   Altitude_CAL  : VFM 垂直高度向量（583×1 或 1×583）
%   Reg           : ROI struct (LonMin/LonMax/LatMin/LatMax)
%
% 输出：
%   Flag_VFM      : N333×1，333m廓线是否能映射到匹配到的CPro(1/0)
%   CAL_H         : 2×N333，(1,:) = TargetH_km, (2,:) = TargetRow583
%   COD           : nz×N5match（保持5km维度的诊断输出）
%   Latitude_CPro : N333×1，扩展到333m维度后的CPro纬度（与你的Latitude_VFM等长）
% -------------------------------------------------------------------------

% ---- 初始化输出 ----
% ---- 统一列向量 ----
Latitude_5km = Latitude_5km(:);
Latitude_VFM = Latitude_VFM(:);
Altitude_CAL = Altitude_CAL(:);

% ---- 固定尺寸输出初始化（关键：绝不返回[]） ----
N333 = numel(Latitude_VFM);
N5   = numel(Latitude_5km);

Flag_VFM   = false(N333, 1);
Flag_VFM5  = false(N5,   1);
CAL_H      = nan(2, N333);
COD        = [];
Latitude_CPro = nan(N333, 1, 'single');


start = [0 0];
edges = [-9 -9];
nPer  = 15; % 5km -> 333m

% ---- 统一列向量 ----
Latitude_5km = Latitude_5km(:);
Latitude_VFM = Latitude_VFM(:);
Altitude_CAL = Altitude_CAL(:);

% ---- 读 CPro 经纬度 (N5_all×3) ----
variable = 'Longitude';
[~, Longitude_CPro] = readHDF(filepath_CPro, variable, start, edges);
variable = 'Latitude';
[~, Latitude_CPro_Raw] = readHDF(filepath_CPro, variable, start, edges);

% ---- ROI筛选（用中点第2列）----
validRange_CPro = Longitude_CPro(:,2) >= Reg.LonMin & Longitude_CPro(:,2) <= Reg.LonMax & ...
    Latitude_CPro_Raw(:,2) >= Reg.LatMin & Latitude_CPro_Raw(:,2) <= Reg.LatMax;

% Latitude_5km=Latitude_5km(validRange_CPro);

if sum(validRange_CPro) == 0
    disp('Cpro LatLon is not in ROI LatLon, skip this hdf file!');
    return;
end

% ---- VFM(5km) 与 CPro(5km) 连续段匹配（不用时间，只按纬度重合）----
[Flag_VFM5, Flag_CPro] = Fun_VFM_CPro_Match(Latitude_5km, Latitude_CPro_Raw(:,2));

if sum(Flag_VFM5) == 0 || sum(Flag_CPro) == 0
    % Flag_VFM = [];
    return;
end

% ---- 合并 CPro ROI 与 匹配段 ----
% validRange_CPro = validRange_CPro(:) & Flag_CPro(:);
validRange_CPro = Flag_CPro(:);

% 匹配到的5km索引（在各自序列内）
idxVFM5 = find(Flag_VFM5(:) == 1);        % 在 Latitude_5km 内的索引
idxCPro = find(validRange_CPro(:) == 1);  % 在 CPro 全序列内的索引

if isempty(idxVFM5) || isempty(idxCPro)
    % Flag_VFM = [];
    return;
end

% ---- 长度一致性校验（不一致则截断到最短）----
if numel(idxVFM5) ~= numel(idxCPro)
    warning('VFM5km matched count (%d) != CPro matched count (%d). Truncating to min.', ...
        numel(idxVFM5), numel(idxCPro));
    nMin = min(numel(idxVFM5), numel(idxCPro));
    idxVFM5 = idxVFM5(1:nMin);
    idxCPro = idxCPro(1:nMin);
end

nMatch5 = numel(idxCPro);

% =====================================================================
%  A) 生成333m维度的 Flag_VFM 与 Latitude_CPro(=N333×1)
% =====================================================================
N333 = numel(Latitude_VFM);
N5 = numel(Latitude_5km);

Flag_VFM = false(N333,1);
Latitude_CPro = nan(N333,1,'single');

% 关键：Latitude_CPro 应该直接使用 Latitude_VFM 的值
% 对于每个匹配到的5km点，找到对应的333m点范围，直接复制 Latitude_VFM 的值
for g = 1:nMatch5
    vfm5_idx = idxVFM5(g);  % 在 Latitude_5km 中的索引
    cpro_idx = idxCPro(g);  % 在 Latitude_CPro_Raw 中的索引

    % 计算该5km点在完整333m序列中对应的起始索引
    % 假设：Latitude_VFM(1:15) 对应 Latitude_5km(1)
    start_333_idx = (vfm5_idx - 1) * nPer + 1;
    end_333_idx = vfm5_idx * nPer;

    % 越界保护
    if start_333_idx > N333
        continue;
    end
    if end_333_idx > N333
        end_333_idx = N333;
    end

    % 该组在333m上的实际索引范围
    kk = start_333_idx:end_333_idx;

    if isempty(kk)
        continue;
    end

    % 直接使用 Latitude_VFM 的值，而不是通过插值生成
    % 这样 Latitude_CPro 就与 Latitude_VFM 完全一致
    Latitude_CPro(kk) = single(Latitude_VFM(kk));

    % 标记这些点为有效匹配
    Flag_VFM(kk) = true;
end

% =====================================================================
%  B) 计算 COD (只在匹配到的 CPro 5km profiles 上)
% =====================================================================
variable = 'Extinction_Coefficient_532';
[~, CPro_alpha] = readHDF(filepath_CPro, variable, start, edges);
CPro_alpha = CPro_alpha'; % [nz × N5_all]

% CPro高度
Altitude_CPro = hdfread(filepath_CPro, '/metadata', 'Fields', 'Lidar_Data_Altitudes');
if iscell(Altitude_CPro)
    Altitude_CPro = Altitude_CPro{1,1};
end
Altitude_CPro = double(Altitude_CPro(:)); % nz×1

% 有效掩码
validMask_Data = CPro_alpha ~= -9999;
CPro_alpha(~validMask_Data) = 0;

% 积分 COD（全序列）
COD_full = -cumtrapz(Altitude_CPro, double(CPro_alpha)); % [nz×N5_all]

% 只取匹配到的CPro列（idxCPro）
COD = COD_full(:, idxCPro); % 输出诊断量：nz×nMatch5

% =====================================================================
%  C) 找 TargetCOD 对应的 TargetH (km)，并映射到583行号
% =====================================================================
TargetH = nan(1, nMatch5);
maxCOD = max(COD, [], 1, 'omitnan');

for col_i = 1:nMatch5
    if maxCOD(col_i) > 0
        x = COD(:, col_i); % COD
        [x_sorted, uniqueIdx] = unique(x, 'sorted');
        validIdx = ~isnan(x_sorted);
        if sum(validIdx) > 1
            x_use = x_sorted(validIdx);
            y_use = Altitude_CPro(uniqueIdx(validIdx)); % km
            try
                TargetH(col_i) = interp1(x_use, y_use, TargetCOD, 'linear', NaN);
            catch
                TargetH(col_i) = NaN;
            end
        end
    end
end

% 映射到 VFM 583行号
Altitude_CAL = double(Altitude_CAL(:)); % 583×1
TargetH_rep = repmat(TargetH, numel(Altitude_CAL), 1);
Altitude_VFM_Mat = repmat(Altitude_CAL, 1, nMatch5);
[~, ClosestRow] = min(abs(Altitude_VFM_Mat - TargetH_rep), [], 1);

CAL_H_5km = nan(2, nMatch5);
linearInd = sub2ind(size(Altitude_VFM_Mat), ClosestRow, 1:nMatch5);
CAL_H_5km(1,:) = Altitude_VFM_Mat(linearInd);
CAL_H_5km(2,:) = ClosestRow;
CAL_H_5km(:, isnan(TargetH)) = NaN;

% =====================================================================
%  D) 扩展 CAL_H 到 333m 维度（每组15条共用）
% =====================================================================
CAL_H = nan(2, N333);

% 对每个匹配的5km组，将CAL_H_5km扩展到对应的15个333m点
for g = 1:nMatch5
    vfm5_idx = idxVFM5(g);  % 在 Latitude_5km 中的索引

    % 计算该5km点在完整333m序列中对应的起始索引
    start_333_idx = (vfm5_idx - 1) * nPer + 1;
    end_333_idx = vfm5_idx * nPer;

    % 越界保护
    if start_333_idx > N333
        continue;
    end
    if end_333_idx > N333
        end_333_idx = N333;
    end

    % 该组在333m上的实际索引范围
    kk = start_333_idx:end_333_idx;

    % 将5km的CAL_H值复制到该组的所有333m点
    if ~isnan(CAL_H_5km(1, g))
        CAL_H(1, kk) = CAL_H_5km(1, g);  % 高度值
        CAL_H(2, kk) = CAL_H_5km(2, g);  % 行号
    end
end
Flag_VFM5 = logical(Flag_VFM5');

end
