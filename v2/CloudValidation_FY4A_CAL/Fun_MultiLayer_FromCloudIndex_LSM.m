function [IsMultiLayer] = Fun_MultiLayer_FromCloudIndex_LSM(CloudIndex2, Altitude, minDH, CAL_H, Temp_Altitude, IceCloud_Mask, WaterCloud_Mask)
% ==========================================================
% 2025.11.10编辑
% 功能：
%   根据输入的云相态矩阵计算多层云比例，可选择性地应用COD约束
% 输入：
%   CloudIndex2 - 原始云相态矩阵
%   Altitude    - 高度向量
%   minDH       - 云层间的最小高度差阈值
%   CAL_H       - COD约束高度 (可选)，若为空则不应用约束
% 输出：
%   CloudLayerFlag - 单层/多层云标识
%       0: 单层或无云
%       1: 多层且全水云
%       2: 多层且全冰云
%       3: 多层且混合云（冰+水）
% ==========================================================

% ---- Step 1: 判断是否需要COD约束 ----
if exist('CAL_H','var') && ~isempty(CAL_H)
    % 应用COD约束
    CloudIndex_out = Fun_RefineMatrix_TargetH(CloudIndex2, CAL_H(1));
    COD_applied = true;
else
    % 不应用COD约束
    CloudIndex_out = CloudIndex2;
    COD_applied = false;
end

% ---- Step 2: 计算多层云比例 ----
% Step 1: 计算云层结构（每列Top/Base）
[~, LayerHeights] = Fun_Calculate_Layers_LSM(CloudIndex_out, Altitude, minDH);

% Step 2: 初始化输出标志
IsMultiLayer = 0;

% Step 3: 仅当该列存在多层时，继续判断相态
for col = 1:length(LayerHeights)
    this_col_layers = LayerHeights{col};
    if isempty(this_col_layers) || size(this_col_layers,1) < 2
        continue;
    end
    hasWaterAll = true;
    hasIceAll = true;
    hasMix = false;
    % Step 4: 针对每相邻两层进行相态判断
    % for L = 1:size(this_col_layers,1)-1
    %     upper_top = this_col_layers(L,1);
    %     upper_base = this_col_layers(L,2);
    %     lower_top = this_col_layers(L+1,1);
    %     lower_base = this_col_layers(L+1,2);
    %
    %     % Step 5: 定义层内mask范围（高度在Top和Base之间）
    %     upper_mask = (Temp_Altitude <= upper_top) & (Temp_Altitude >= upper_base);
    %     lower_mask = (Temp_Altitude <= lower_top) & (Temp_Altitude >= lower_base);
    %
    %     % Step 6: 判定各层是否含冰/水云
    %     upper_hasIce = any(IceCloud_Mask(:, upper_mask), 'all');
    %     upper_hasWater = any(WaterCloud_Mask(:, upper_mask), 'all');
    %     lower_hasIce = any(IceCloud_Mask(:, lower_mask), 'all');
    %     lower_hasWater = any(WaterCloud_Mask(:, lower_mask), 'all');
    %
    %     % Step 7: 若上层与下层相态不同 → 标记为多层云
    %     if (upper_hasIce && lower_hasWater) || (upper_hasWater && lower_hasIce)
    %         IsMultiLayer = 1;
    %         break;
    %     end
    %
    % end
    % % 若某列已满足条件，可提前退出
    % if IsMultiLayer
    %     break;
    % end


    for L = 1:size(this_col_layers,1)
        top = this_col_layers(L,1);
        base = this_col_layers(L,2);
        mask = (Temp_Altitude <= top) & (Temp_Altitude >= base);

        upper_hasWater = any(WaterCloud_Mask(mask), 'all');
        upper_hasIce   = any(IceCloud_Mask(mask), 'all');

        if upper_hasWater && ~upper_hasIce
            hasIceAll = false;
        elseif upper_hasIce && ~upper_hasWater
            hasWaterAll = false;
        else
            hasMix = true;
        end
    end

    % Step 5: 根据云相态赋值 IsMultiLayer
    if hasMix
        IsMultiLayer = 3;          % 多层且混合云
    elseif hasWaterAll && ~hasIceAll
        IsMultiLayer = 1;          % 多层全水云
    elseif hasIceAll && ~hasWaterAll
        IsMultiLayer = 2;          % 多层全冰云
    else
        IsMultiLayer = 3;          % 兜底，混合云
    end
end
% % ---- Step 3: 输出提示（可选）----
% if COD_applied
%     disp('已应用 COD 约束进行多层云判定。');
% else
%     disp('未应用 COD 约束，直接进行多层云判定。');
% end

end

