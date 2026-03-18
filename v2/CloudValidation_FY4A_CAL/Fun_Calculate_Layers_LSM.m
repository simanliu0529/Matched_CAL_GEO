function [MultiLayerFraction, LayerHeights] = Fun_Calculate_Layers_LSM(CloudIndex, Altitude, minDH)
% ==========================================================
% 功能：
%   计算云层分布结构，输出每列云层Top/Base和多层云比例
% 输入：
%   CloudIndex - 云廓线矩阵 (0/1)
%   Altitude   - 高度向量
%   minDH      - 云层间最小高度差阈值
% 输出：
%   MultiLayerFraction - [基于分段判断的比例, 经过minDH筛选后的比例]
%   LayerHeights       - cell，每列包含 [Top Base] 每层高度
% ==========================================================

[m, n] = size(CloudIndex);
B = repmat(Altitude, 1, n);

[rows, cols] = find(CloudIndex);
if isempty(rows)
    grouped_rows = cell(n, 1);
else
    grouped_rows = accumarray(cols, rows, [n, 1], @(x) {sort(x)});
end

LayerHeights = cell(n, 1);
gapped_overlap = false(1, n);

for col = 1:n
    if isempty(grouped_rows{col})
        continue;
    end
    current_rows = grouped_rows{col};

    % 找断层（非连续段）
    gaps = [1; find(diff(current_rows) > 1) + 1];
    ends = [gaps(2:end) - 1; numel(current_rows)];

    start_rows = current_rows(gaps);
    end_rows = current_rows(ends);

    tops = B(start_rows, col);
    bases = B(end_rows, col);

    % 确保Top > Base（从高到低排序）
    [tops, idx] = sort(tops, 'descend');
    bases = bases(idx);

    merged_layers = [tops(:), bases(:)];

    % 若多层，计算层间距并用minDH筛选
    if size(merged_layers, 1) > 1
        spans = merged_layers(1:end-1,2) - merged_layers(2:end,1); % 上层Base - 下层Top
        keep_idx = [true; spans >= minDH]; % 保留第一层以及满足间距的下层
        merged_layers = merged_layers(keep_idx, :);

        if size(merged_layers, 1) > 1
            gapped_overlap(col) = true;
        end
    end

    LayerHeights{col} = merged_layers;
end

% 统计多层云比例
indices = find(any(CloudIndex, 1));
num_columns_with_clouds = length(indices);
if num_columns_with_clouds > 0
    num_columns_with_overlap = sum(cellfun(@(x) size(x,1) > 1, LayerHeights));
    MultiLayerFraction = [num_columns_with_overlap / num_columns_with_clouds, ...
                          num_columns_with_overlap / num_columns_with_clouds];
else
    MultiLayerFraction = [NaN, NaN];
end

end
