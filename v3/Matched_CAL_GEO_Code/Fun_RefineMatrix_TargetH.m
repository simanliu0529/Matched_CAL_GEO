function [CloudIndex] = Fun_RefineMatrix_TargetH(CloudIndex,CAL_H)
% 增加COD约束
    B = CAL_H;
    [m, n] = size(CloudIndex);
    if isnan(B)
        CloudIndex = 0;
    else
        B_clipped = min(max(B, 1), m);
        mask = (1:m)' <= B_clipped;
        CloudIndex(mask, :) = 0;
    end
end