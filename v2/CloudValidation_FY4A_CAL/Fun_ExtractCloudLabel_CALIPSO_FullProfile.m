function CloudLabel = Fun_ExtractCloudLabel_CALIPSO_FullProfile( ...
    ProfileData, ProfilePhase, Altitude, ...
    CalRow1p0, MinProfileCount, minDH)

% 0=晴空
% 1=水云
% 2=冰云
% 3=多层云(上冰下水)
% 4=Mixed/uncertain

if nargin < 5 || isempty(MinProfileCount), MinProfileCount = 10; end
if nargin < 6 || isempty(minDH), minDH = 1.0; end

[Nprof, ~] = size(ProfileData);
Alt = double(Altitude(:));
CalRow1p0 = CalRow1p0(:);
if numel(CalRow1p0) < Nprof
    CalRow1p0(Nprof,1) = NaN;
end

CloudLabel = 4;   % 默认不确定

% =========================================================
% 1. 有效廓线筛选
% =========================================================
valid_mask = (ProfileData == 1) |(ProfileData == 2);

row_valid_cnt = sum(valid_mask,2);
valid_row = row_valid_cnt > 0;
valid_cols = find(valid_row);

if numel(valid_cols) < MinProfileCount
    return
end

cloud_mask = (ProfilePhase >= 1) &(ProfilePhase <= 3) & valid_mask;
water_mask = cloud_mask & (ProfilePhase == 2);
ice_mask   = cloud_mask & ((ProfilePhase == 1) | (ProfilePhase == 3));

% =========================================================
% 2. 几何多层检测（逐廓线）
% =========================================================
CloudIndex = cloud_mask';
[~, LayerHeights] = Fun_Calculate_Layers_LSM(CloudIndex, Alt, minDH);

profile_type = zeros(Nprof,1);
% 0 clear
% 1 water
% 2 ice
% 3 multi (上冰下水)
% 4 mixed

is_thick_upper = ~isnan(CalRow1p0);

for col = valid_cols'

    total_valid = sum(valid_mask(col,:));
    total_cloud = sum(cloud_mask(col,:));

    if total_valid == 0
        continue
    end

    cloud_ratio_profile = total_cloud / total_valid;

    % 单廓线晴空判别
    if cloud_ratio_profile < 0.02
        profile_type(col) = 0;
        continue
    end

    % 计算相态比例
    if total_cloud > 0
        water_ratio = sum(water_mask(col,:)) / total_cloud;
        ice_ratio   = sum(ice_mask(col,:))   / total_cloud;
    else
        profile_type(col) = 0;
        continue
    end

    % -------- 几何多层判断 --------
    layers = LayerHeights{col};
    if ~isempty(layers) && size(layers,1) >= 2
        
        upper = layers(1,:);
        lower = layers(2,:);
        
        u_hi = max(upper); u_lo = min(upper);
        l_hi = max(lower); l_lo = min(lower);
        
        u_mask = (Alt <= u_hi) & (Alt >= u_lo);
        l_mask = (Alt <= l_hi) & (Alt >= l_lo);

        u_hasWater = any(water_mask(col,u_mask));
        u_hasIce   = any(ice_mask(col,u_mask));
        l_hasWater = any(water_mask(col,l_mask));
        l_hasIce   = any(ice_mask(col,l_mask));

        if (u_hasIce && ~u_hasWater) && ...
           (l_hasWater && ~l_hasIce)
            profile_type(col) = 3;
            continue
        end
    end

    % -------- 单相判断 --------
    if water_ratio > 0.75
        profile_type(col) = 1;
    elseif ice_ratio > 0.75
        profile_type(col) = 2;
    else
        profile_type(col) = 4;
    end
end

% =========================================================
% 3. 廓线比例统计
% =========================================================

Nvalid = numel(valid_cols);

clear_frac = mean(profile_type(valid_cols) == 0);
water_frac = mean(profile_type(valid_cols) == 1);
ice_frac   = mean(profile_type(valid_cols) == 2);
multi_frac = mean(profile_type(valid_cols) == 3);

% =========================================================
% 4. 最终判别（75%规则）
% =========================================================

if clear_frac > 0.90
    CloudLabel = 0;
    return
end

if multi_frac > 0.75
    CloudLabel = 3;
    return
end

if ice_frac > 0.75
    CloudLabel = 2;
    return
end

if water_frac > 0.75
    CloudLabel = 1;
    return
end

CloudLabel = 4;

end