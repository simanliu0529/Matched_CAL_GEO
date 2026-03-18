function [MultiLayerFraction] = Fun_Calculate_Layers(CloudIndex,Altitude,minDH)
    % 预定义
    MultiLayerFraction = nan(1,2);
    
    A = CloudIndex;
    [m, n] = size(A);
    B = repmat(Altitude,1,n);

    % 找到每列中值为1的所有行
    [rows, cols] = find(A);

    % 初始化分组
    if isempty(rows)
        grouped_rows = cell(n, 1); % 若A中没有1，分组为空
    else
        grouped_rows = accumarray(cols, rows, [n, 1], @(x) {sort(x)});
    end

    % 初始化结果
    start_rows = cell(1, n); % 每列中段的起始行号
    end_rows = cell(1, n);   % 每列中段的结束行号
    gapped_overlap = false(1, n); % 标记是否有间隔重叠
    height_spans = cell(1, n); % 每列中相邻间隔的高度跨度

    % 逐列判断
    for col = 1:n
        if ~isempty(grouped_rows{col})
            current_rows = grouped_rows{col}; % 当前列的所有1的行号

            % 找到非连续的段（间隔位置）
            gaps = [1; find(diff(current_rows) > 1) + 1];
            start_rows{col} = current_rows(gaps); % 每段的起始行号
            ends = [gaps(2:end) - 1; numel(current_rows)];
            end_rows{col} = current_rows(ends); % 每段的结束行号

            % 如果段数大于1，则存在间隔重叠
            if numel(start_rows{col}) > 1
                gapped_overlap(col) = true;

                % 计算相邻段之间中间区域的高度跨度
                spans = zeros(numel(start_rows{col}) - 1, 1);
                for i = 1:numel(start_rows{col}) - 1
                    zero_start = end_rows{col}(i) + 1; % 中间0区域的起始行号
                    zero_end = start_rows{col}(i + 1); % 下一个1区域的起始行号
                    spans(i) = B(zero_start, col) - B(zero_end, col); % 高度跨度
                end
                height_spans{col} = spans;
            end
        end
    end

    % 统计有间隔重叠的列数和有云的总廓线
    num_columns_with_overlap = sum(gapped_overlap);
    indices = find(any(A, 1));
    num_columns_with_clouds = length(indices);
    if num_columns_with_clouds > 0
        MultiLayerFraction(1,1) = num_columns_with_overlap./num_columns_with_clouds;
        MultiLayerFraction(1,2) = 0; % 0表示有云，但均为单层云；NaN表示无云
    end
%     if num_columns_with_overlap > 0
%         disp('Start and End rows for each column with gapped overlap and height spans:');
%         for col = 1:n
%             if gapped_overlap(col)
%                 fprintf('Column %d:\n', col);
%                 for i = 1:numel(start_rows{col})
%                     fprintf('  Segment %d: Start: %d, End: %d\n', i, start_rows{col}(i), end_rows{col}(i));
%                 end
%                 fprintf('  Height spans between segments: %s\n', mat2str(height_spans{col}'));
%             end
%         end
%     else
%         disp('No columns with gapped overlap.');
%     end

    if num_columns_with_overlap > 0
%         disp('Start and End rows for each column with gapped overlap and height spans:');
        for col = 1:n
            if gapped_overlap(col)
                height_spans_temp = height_spans{col};
                start_rows_temp = start_rows{col};
                end_rows_temp = end_rows{col};
                for i = 1:numel(height_spans_temp)               
                    if height_spans_temp(i) < minDH
                        start_rows_temp(i+1) = NaN;
                        end_rows_temp(i+1) = NaN;
                        height_spans_temp(i) = NaN;
                    end
                end
                height_spans{col} = height_spans_temp(~isnan(height_spans_temp));
                start_rows{col} = start_rows_temp(~isnan(start_rows_temp));
                end_rows{col} = end_rows_temp(~isnan(end_rows_temp));
                if isempty(height_spans{col})
                   gapped_overlap(col) = 0; 
                end
            end
        end
        num_columns_with_overlap_V1 = sum(gapped_overlap); % 当云层间的间隔小于阈值时，默认为一个云体
        MultiLayerFraction(1,2) = num_columns_with_overlap_V1./num_columns_with_clouds;
    end
end