function GridProfilesMap = Fun_match_GridToProfiles( ...
    FY4A_Lon, FY4A_Lat, FY4A_Time_All, ...
    VFM_Lon, VFM_Lat, VFM_time, ...
    MaxTimeDiff_hours, SearchRadius_km, MinProfileCount)
% FUN_MATCH_GRIDTOPROFILES
% 将 VFM 333m 廓线按 “最近FY4A时刻 + 最近FY4A网格” 做一对多映射
% 并进行：时间门控、距离门控、最小廓线数门控（少于 MinProfileCount 认为无效，直接丢弃）
%
% 输入：
%   FY4A_Lon/FY4A_Lat : FY4A 网格经纬度（可不规则，ROI 内允许 NaN）
%   FY4A_Time_All     : FY4A 每小时时间序列（datenum, 单位天）
%   VFM_Lon/VFM_Lat   : VFM 333m 廓线经纬度（1D，长度 Nvfm）
%   VFM_time          : VFM 廓线时间（datenum, 单位天，长度 Nvfm）
%   MaxTimeDiff_hours : 最大时间差（小时），如 0.5 表示 ±30min
%   SearchRadius_km   : 空间门控半径（km），如 2.5 或 4
%   MinProfileCount   : 每个 (grid,time) 最少廓线数，如 10
%
% 输出：
%   GridProfilesMap(k).gridRow, gridCol, gridTimeIdx
%   GridProfilesMap(k).profileIndices  (原始VFM索引)
%   GridProfilesMap(k).MatchCount

    % ---------------- 参数默认值 ----------------
    if nargin < 8 || isempty(MaxTimeDiff_hours), MaxTimeDiff_hours = 0.5; end
    if nargin < 9 || isempty(SearchRadius_km),   SearchRadius_km   = 4; end
    if nargin < 10 || isempty(MinProfileCount),  MinProfileCount   = 10;  end

    % ---------------- 向量化 ----------------
    VFM_Lon  = double(VFM_Lon(:));
    VFM_Lat  = double(VFM_Lat(:));
    VFM_time = double(VFM_time(:));
    FY4A_Time_All = double(FY4A_Time_All(:));

    [rows, cols] = size(FY4A_Lon);
    FY4A_Lon_vec = double(FY4A_Lon(:));
    FY4A_Lat_vec = double(FY4A_Lat(:));

    % ---------------- FY4A 网格有效点（允许 ROI 内 NaN 洞） ----------------
    validGrid = isfinite(FY4A_Lon_vec) & isfinite(FY4A_Lat_vec);
    if ~any(validGrid)
        GridProfilesMap = struct('gridRow', {}, 'gridCol', {}, 'gridTimeIdx', {}, ...
                                 'profileIndices', {}, 'MatchCount', {});
        return;
    end
    FY_Lon_valid = FY4A_Lon_vec(validGrid);
    FY_Lat_valid = FY4A_Lat_vec(validGrid);
    gridLinearIdx_valid = find(validGrid);  % 映射回原始网格 linearIdx

    % ============================================================
    % 1) 时间最近邻匹配 + 时间门控
    % ============================================================
    % diff_days: [Nvfm x Nt]，Nt=24 时很小；若未来更大可改分块或 knnsearch 时间轴
    diff_days = abs(VFM_time - FY4A_Time_All');         % 单位：天
    [minDiffDays, timeIdx] = min(diff_days, [], 2);     % 最近FY4A时刻索引
    timeDiff_hours = minDiffDays * 24;

    validTime = timeDiff_hours <= MaxTimeDiff_hours;
    if ~any(validTime)
        GridProfilesMap = struct('gridRow', {}, 'gridCol', {}, 'gridTimeIdx', {}, ...
                                 'profileIndices', {}, 'MatchCount', {});
        return;
    end

    idx0 = find(validTime);           % 原始 VFM 索引
    subLon = VFM_Lon(validTime);
    subLat = VFM_Lat(validTime);
    subTimeIdx = timeIdx(validTime);

    % ============================================================
    % 2) 空间最近邻（仅对有效网格点建树） + 映射回原网格索引
    % ============================================================
    tree = KDTreeSearcher([FY_Lon_valid, FY_Lat_valid]);
    nn_valid_idx = knnsearch(tree, [subLon, subLat]);        % 返回 validGrid 子集索引
    gridLinearIdx = gridLinearIdx_valid(nn_valid_idx);       % 映射回原始网格 linearIdx

    % ============================================================
    % 3) Haversine 距离门控（km）
    % ============================================================
    lon_g = FY4A_Lon_vec(gridLinearIdx);
    lat_g = FY4A_Lat_vec(gridLinearIdx);

    dist_km = haversine_km(subLat, subLon, lat_g, lon_g);
    validDist = dist_km <= SearchRadius_km;

    if ~any(validDist)
        GridProfilesMap = struct('gridRow', {}, 'gridCol', {}, 'gridTimeIdx', {}, ...
                                 'profileIndices', {}, 'MatchCount', {});
        return;
    end

    idx0 = idx0(validDist);
    gridLinearIdx = gridLinearIdx(validDist);
    subTimeIdx = subTimeIdx(validDist);

    % ============================================================
    % 4) 按 (gridLinearIdx, timeIdx) 聚合
    % ============================================================
    key = [gridLinearIdx, subTimeIdx];
    [keyU, ~, ic] = unique(key, 'rows');
    nGroup = size(keyU, 1);

    profilesCell = accumarray(ic, idx0, [nGroup 1], @(x){x});
    matchCount = cellfun(@numel, profilesCell);

    % ============================================================
    % 5) 最小廓线数门控：少于 MinProfileCount 直接丢弃
    % ============================================================
    keep = matchCount >= MinProfileCount;
    if ~any(keep)
        GridProfilesMap = struct('gridRow', {}, 'gridCol', {}, 'gridTimeIdx', {}, ...
                                 'profileIndices', {}, 'MatchCount', {});
        return;
    end

    keyU = keyU(keep, :);
    profilesCell = profilesCell(keep);
    matchCount = matchCount(keep);

    nKeep = size(keyU, 1);
    GridProfilesMap = repmat(struct('gridRow', [], 'gridCol', [], 'gridTimeIdx', [], ...
                                    'profileIndices', [], 'MatchCount', []), nKeep, 1);

    for k = 1:nKeep
        gl  = keyU(k,1);
        tIx = keyU(k,2);
        [r,c] = ind2sub([rows, cols], gl);

        GridProfilesMap(k).gridRow = r;
        GridProfilesMap(k).gridCol = c;
        GridProfilesMap(k).gridTimeIdx = tIx;
        GridProfilesMap(k).profileIndices = profilesCell{k};
        GridProfilesMap(k).MatchCount = matchCount(k);
    end
end

% ===================== 子函数：Haversine 距离(km) =====================
function d_km = haversine_km(lat1, lon1, lat2, lon2)
    R = 6371.0; % km
    lat1 = deg2rad(lat1); lon1 = deg2rad(lon1);
    lat2 = deg2rad(lat2); lon2 = deg2rad(lon2);

    dlat = lat2 - lat1;
    dlon = lon2 - lon1;

    a = sin(dlat/2).^2 + cos(lat1).*cos(lat2).*sin(dlon/2).^2;
    c = 2*atan2(sqrt(a), sqrt(1-a));
    d_km = R*c;
end
