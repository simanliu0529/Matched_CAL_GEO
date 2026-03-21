function [Index_All_unique, Index_VFM_Original] = Fun_match_SpatioTemporal_Optimized(FY4A_Lon, FY4A_Lat, FY4A_Time_All, VFM_Lon, VFM_Lat, VFM_time, DISTANCE_THRESHOLD_KM, MaxTimeDiff_hours)
% FUN_MATCH_SPATIOTEMPORAL_OPTIMIZED 优化后的时空匹配函数 (使用 KD-Tree 提高空间匹配效率)

N_VFM = length(VFM_Lon);
N_Time = length(FY4A_Time_All);

% 1. 空间匹配优化：使用 KD-Tree 查找最近邻

% 将 FY4A 网格转换为点列表
FY4A_Lon_vec = FY4A_Lon(:);
FY4A_Lat_vec = FY4A_Lat(:);
FY4A_points = [FY4A_Lon_vec, FY4A_Lat_vec];

% CALIPSO 点
VFM_points = [VFM_Lon, VFM_Lat];

% 构建 KD-Tree 并找到最近邻点 (使用欧氏距离)
tree = KDTreeSearcher(FY4A_points);
[Index_Linear, ~] = knnsearch(tree, VFM_points, 'K', 1);

% 将一维索引转换为二维行列索引
[Row, Col] = ind2sub(size(FY4A_Lon), Index_Linear);

%% 2. 空间匹配验证 (Haversine距离 + 距离阈值)

% Haversine 矢量化计算：计算 VFM 点到它们各自最近邻 FY4A 点的精确距离 (km)

% 提取最近邻 FY4A 像元的经纬度
FY4A_Lat_NN = FY4A_Lat_vec(Index_Linear);
FY4A_Lon_NN = FY4A_Lon_vec(Index_Linear);

% 将经纬度转换为弧度 (VFM 和最近邻 FY4A)
rad_VFM_Lon = deg2rad(VFM_Lon);
rad_VFM_Lat = deg2rad(VFM_Lat);
rad_FY4A_Lon_NN = deg2rad(FY4A_Lon_NN);
rad_FY4A_Lat_NN = deg2rad(FY4A_Lat_NN);

% Haversine (完全矢量化)
dLon = rad_FY4A_Lon_NN - rad_VFM_Lon;
dLat = rad_FY4A_Lat_NN - rad_VFM_Lat;

% 注意：Haversine公式中的 cos(rad_VFM_Lat) 也要是向量
a = sin(dLat/2).^2 + cos(rad_VFM_Lat) .* ...
    cos(rad_FY4A_Lat_NN) .* sin(dLon/2).^2;
c = 2 * atan2(sqrt(a), sqrt(1-a));
distance_km = 6371 * c; % 地球半径6371km，单位：km

% 应用空间距离阈值
Invalid_Spatial_Idx = distance_km >= DISTANCE_THRESHOLD_KM;
Row(Invalid_Spatial_Idx) = 0; % 标记无效
Col(Invalid_Spatial_Idx) = 0;

%% 3. 时间匹配 (最近邻 + 时间差异阈值)

% (此部分与原代码相同，效率已高)
FY4A_Time2 = repmat(FY4A_Time_All', N_VFM, 1);
VFM_time2 = repmat(VFM_time, 1, N_Time);
diff_Time = abs(FY4A_Time2 - VFM_time2); % 差值以天为单位

% 对每个VFM点，找到最小时间差和对应的FY4A时间索引
[Min_DiffTime, Index_Time] = min(diff_Time, [], 2);

% 应用时间差异阈值 (MaxTimeDiff_hours / 24, 以天为单位)
Index_Time(Min_DiffTime > MaxTimeDiff_hours/24) = NaN;

%% 4. 联合筛选和去重

% 找出所有满足匹配条件的VFM廓线 (空间索引 > 0 且时间索引有效)
Combined_Valid_Idx = (Row > 0) & ~isnan(Index_Time);

% 提取满足条件的索引
Row_Valid = Row(Combined_Valid_Idx);
Col_Valid = Col(Combined_Valid_Idx);
Index_Time_Valid = Index_Time(Combined_Valid_Idx);

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

% 返回 VFM 廓线到唯一网格点的映射
Index_VFM_Original = Index_VFM_Map;

end