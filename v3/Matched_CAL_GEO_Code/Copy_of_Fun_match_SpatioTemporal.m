function [Index_All_unique, Index_VFM_Original] = Fun_match_SpatioTemporal(FY4A_Lon, FY4A_Lat, FY4A_Time_All, VFM_Lon, VFM_Lat, VFM_time, DISTANCE_THRESHOLD_KM, MaxTimeDiff_hours)
% FUN_MATCH_SPATIOTEMPORAL 执行时空最邻近匹配，包含距离和时间阈值限制。
%
% 输入:
%   FY4A_Lon          - FY4A/H8 网格经度矩阵 (LatNum x LonNum)
%   FY4A_Lat          - FY4A/H8 网格纬度矩阵 (LatNum x LonNum)
%   FY4A_Time_All     - FY4A/H8 逐小时时间序列 (TimeNum x 1, MATLAB datenum)
%   VFM_Lon           - CALIPSO 廓线经度向量 (N_VFM x 1)
%   VFM_Lat           - CALIPSO 廓线纬度向量 (N_VFM x 1)
%   VFM_time          - CALIPSO 廓线时间向量 (N_VFM x 1, MATLAB datenum)
%   DISTANCE_THRESHOLD_KM - 空间距离阈值 (km)
%   MaxTimeDiff_hours - 时间差异阈值 (小时)
%
% 输出:
%   Index_All_unique  - 唯一的匹配成功的 FY4A 网格索引 [Row, Col, TimeIdx] (N_unique x 3)
%   Index_VFM_Original- 原始 VFM 廓线索引，指示哪些 VFM 点匹配到了 Index_All_unique 中的哪个唯一网格 (N_VFM_valid x 1)

N_VFM = length(VFM_Lon);
N_Time = length(FY4A_Time_All);

%% 1. 空间匹配 (基于Haversine距离 + 距离阈值)

% 初始化匹配结果
Row = zeros(N_VFM, 1, 'single');
Col = zeros(N_VFM, 1, 'single');

for i = 1:N_VFM
    % 计算球面距离 (Haversine公式)
    
    % 将经纬度转换为弧度
    rad_FY4A_Lon = deg2rad(FY4A_Lon);
    rad_FY4A_Lat = deg2rad(FY4A_Lat);
    rad_VFM_Lon = deg2rad(VFM_Lon(i));
    rad_VFM_Lat = deg2rad(VFM_Lat(i));
    
    % Haversine
    dLon = rad_FY4A_Lon - rad_VFM_Lon;
    dLat = rad_FY4A_Lat - rad_VFM_Lat;
    
    a = sin(dLat/2).^2 + cos(rad_VFM_Lat) .* ...
        cos(rad_FY4A_Lat) .* sin(dLon/2).^2;
    c = 2 * atan2(sqrt(a), sqrt(1-a));
    distance = 6371 * c; % 地球半径6371km，单位：km
   
    % 找最小距离的H8像元
    [minDist, idx] = min(distance(:));
    
    if ~isempty(idx) && minDist < DISTANCE_THRESHOLD_KM
        % 找到有效匹配，将一维索引转换为二维下标
        [row, col] = ind2sub(size(FY4A_Lon), idx);
        % 记录索引
        Row(i) = row;
        Col(i) = col;
    else
        % 不满足距离阈值，设置为 0 (无效)
        Row(i) = 0;
        Col(i) = 0;
    end
end

%% 2. 时间匹配 (最近邻 + 时间差异阈值)

FY4A_Time2 = repmat(FY4A_Time_All', N_VFM, 1);
VFM_time2 = repmat(VFM_time, 1, N_Time);
diff_Time = abs(FY4A_Time2 - VFM_time2); % 差值以天为单位

% 对每个VFM点，找到最小时间差和对应的FY4A时间索引
[Min_DiffTime, Index_Time] = min(diff_Time, [], 2);

% 应用时间差异阈值 (MaxTimeDiff_hours / 24, 以天为单位)
Index_Time(Min_DiffTime > MaxTimeDiff_hours/24) = NaN;

%% 3. 联合筛选和去重

% 找出所有满足匹配条件的VFM廓线 (空间索引 > 0 且时间索引有效)
Combined_Valid_Idx = (Row > 0) & ~isnan(Index_Time);

% 提取满足条件的索引
Row_Valid = Row(Combined_Valid_Idx);
Col_Valid = Col(Combined_Valid_Idx);
Index_Time_Valid = Index_Time(Combined_Valid_Idx);
VFM_Original_Idx_Valid = find(Combined_Valid_Idx); % 原始 VFM 廓线中满足条件的索引

% 存储满足条件的匹配信息
Index_All_Valid = [Row_Valid, Col_Valid, Index_Time_Valid]; 

% 检查是否有任何有效匹配
if isempty(Index_All_Valid)
    Index_All_unique = [];
    Index_VFM_Original = [];
    return;
end

% 移除重复的 FY4A 网格点，并记录原始 VFM 廓线对应关系
[Index_All_unique, ~, Index_VFM_Map] = unique(Index_All_Valid,'rows'); 

% Index_VFM_Original 记录了 Index_All_unique 的第 k 行对应的是
% 原始 VFM 廓线中第 Index_VFM_Map 组的数据。
% 为了在主程序中方便处理，我们返回映射后的索引 (长度与 Index_All_unique 相同)
% 但更常见且好处理的做法是返回一个长度为 N_VFM_valid 的索引，
% 其中的值指示该 VFM 廓线匹配到了 Index_All_unique 的哪一行。
% 我们采用后者: Index_VFM_Original = Index_VFM_Map
Index_VFM_Original = Index_VFM_Map;

end