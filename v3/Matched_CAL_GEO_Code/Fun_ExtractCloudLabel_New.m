function CloudLabel = Fun_ExtractCloudLabel_New( ...
    ProfileData, ProfilePhase, Altitude, CalRow1p0, MinProfileCount, minDH)

% 0=晴空, 1=水云, 2=冰云, 3=多层云(仅上冰下水且几何>=2层), 4=Mixed/uncertain
%
% 前提：
% - ProfileData 已经过 COD<0.2 的薄云过滤（被清掉的上方变成 clear=1）
% - 云bin: ProfileData==2
% - 水相: ProfilePhase==2
% - 冰相: ProfilePhase==1或3
% - CalRow1p0：从顶向下累计COD首次达到1.0的行号；达不到则 NaN（表示“上层冰较薄<1.0”）

if nargin < 5 || isempty(MinProfileCount), MinProfileCount = 10; end
if nargin < 6 || isempty(minDH), minDH = 1.0; end

[Nprof, Nalt] = size(ProfileData);
Alt = double(Altitude(:));           % Nalt×1
CalRow1p0 = CalRow1p0(:);
if numel(CalRow1p0) < Nprof, CalRow1p0(Nprof,1) = NaN; end

% -------- 有效bin（排除0/5/6/7；1=clear要算有效）--------
valid_mask = (ProfileData ~= 0) & (ProfileData ~= 5) & (ProfileData ~= 6) & (ProfileData ~= 7);
row_valid_cnt = sum(valid_mask, 2);
valid_row = row_valid_cnt > 0;

if sum(valid_row) < MinProfileCount
    CloudLabel = 4; return;
end

cloud_mask = (ProfileData == 2) & valid_mask;
water_mask = cloud_mask & (ProfilePhase == 2);
ice_mask   = cloud_mask & ((ProfilePhase == 1) | (ProfilePhase == 3));

TotValidBin = sum(valid_mask, 'all');
TotCloudBin = sum(cloud_mask, 'all');
if TotValidBin == 0
    CloudLabel = 4; return;
end
clear_bin_ratio = 1 - TotCloudBin / TotValidBin;

% 云bin内部纯度（用于单相判别）
if TotCloudBin > 0
    water_bin_ratio = sum(water_mask, 'all') / TotCloudBin;
    ice_bin_ratio   = sum(ice_mask,   'all') / TotCloudBin;
else
    water_bin_ratio = 0; ice_bin_ratio = 0;
end

% =========================================================
% 1) 几何多层判别：>=2层分离（minDH） + 只认“上冰下水”
% =========================================================
% 注意：Fun_Calculate_Layers_LSM 期望 CloudIndex 为 Nalt×Nprof（每列一根廓线）
CloudIndex = cloud_mask';  % Nalt×Nprof (逻辑)
[~, LayerHeights] = Fun_Calculate_Layers_LSM(CloudIndex, Alt, minDH);

% per-profile 类型：
% 0: 非几何多层（<2层）
% 1: 几何多层 且 上下两层都水
% 2: 几何多层 且 上下两层都冰
% 3: 几何多层 且 上冰下水（你要的“多层云”）
% 4: 几何多层 但层内/层间混合或不清晰
ptype = zeros(Nprof,1);

% 上层厚冰(>=1.0)指示（用于你原来的“厚冰主导判冰云像素”逻辑）
is_thick_upper = ~isnan(CalRow1p0);

for col = 1:Nprof
    if ~valid_row(col), continue; end

    layers = LayerHeights{col};
    if isempty(layers) || size(layers,1) < 2
        ptype(col) = 0; % 非几何多层
        continue;
    end

    % 取最上两层（Fun_Calculate_Layers_LSM 已按 top 降序）
    upper = layers(1,:); % [Top Base] 高度值
    lower = layers(2,:);

    % 将高度范围标准化：hi > lo
    u_hi = max(upper(1), upper(2)); u_lo = min(upper(1), upper(2));
    l_hi = max(lower(1), lower(2)); l_lo = min(lower(1), lower(2));

    u_mask = (Alt <= u_hi) & (Alt >= u_lo); % Nalt×1
    l_mask = (Alt <= l_hi) & (Alt >= l_lo);

    % 在该层高度范围内，判断该廓线是否含水/冰
    u_hasWater = any(water_mask(col, u_mask));
    u_hasIce   = any(ice_mask(col,   u_mask));
    l_hasWater = any(water_mask(col, l_mask));
    l_hasIce   = any(ice_mask(col,   l_mask));

    % 仅当层内“单相”才算清晰；否则归为4
    u_pureWater = u_hasWater && ~u_hasIce;
    u_pureIce   = u_hasIce   && ~u_hasWater;
    l_pureWater = l_hasWater && ~l_hasIce;
    l_pureIce   = l_hasIce   && ~l_hasWater;

    if (u_pureIce && l_pureWater)
        ptype(col) = 3; % 上冰下水
    elseif (u_pureWater && l_pureWater)
        ptype(col) = 1; % 多层全水（按你要求最终仍归水云）
    elseif (u_pureIce && l_pureIce)
        ptype(col) = 2; % 多层全冰（最终仍归冰云）
    else
        ptype(col) = 4; % 层内/层间混合，不清晰
    end
end

% 统计比例（按“廓线占比”）
valid_cols = find(valid_row);
p_multi_iw = mean(ptype(valid_cols) == 3);               % 上冰下水 几何多层
p_thickIce = mean((ptype(valid_cols) == 3 | ptype(valid_cols) == 2) & is_thick_upper(valid_cols)); 
% ↑ 这里把“上层厚冰”作为冰云主导证据：上冰下水或全冰多层，且能到1.0

% 同时统计“上冰下水且上层薄(<1.0)”比例（可选强化）
p_iw_thin = mean((ptype(valid_cols) == 3) & ~is_thick_upper(valid_cols));

% =========================================================
% 2) 最终判别顺序（按你原规则 + 新几何限制）
% =========================================================

% (A) 多层云：必须几何>=2层且上冰下水占比>75%
%     另外保留你原来的“上层较薄(<1.0)”倾向：要求 p_iw_thin 也>75%（你若不想要可删）
if p_multi_iw > 0.75 && (p_iw_thin / max(p_multi_iw, eps)) > 0.75
    CloudLabel = 3; return;
end

% (B) 冰云像素：上层厚冰(>=1.0)主导>75%（被动卫星更敏感上层冰）
if p_thickIce > 0.75
    CloudLabel = 2; return;
end



% (D) 水/冰：单相纯度>75%
if TotCloudBin > 0
    if water_bin_ratio > 0.75
        CloudLabel = 1; return;
    end
    if ice_bin_ratio > 0.75
        CloudLabel = 2; return;
    end
end

% (C) 晴空：过滤0.2薄云后，非云>=90%
cloud_frac_2d = TotCloudBin / TotValidBin;
% 例如：云量<2% 才允许判 clear
if clear_bin_ratio >= 0.90 && cloud_frac_2d < 0.02
    CloudLabel = 0; return;
end
CloudLabel = 4;
end
