function maxValues = fun_extractMaxAtRows_LSM(A, indices, col)
    % 从 cell 数组 A 的第 col 列中，提取指定行 indices，对其中数值取最大值
    
    % 取出指定行、指定列的 cell
    extractedValues = A(indices, col);
    
    % 去掉空 cell（避免 COD 约束列中部分为空）
    extractedValues = extractedValues(~cellfun('isempty', extractedValues));
    
    if isempty(extractedValues)
        maxValues = NaN; % 如果全为空，返回 NaN
        return;
    end
    
    % 拼接所有 cell 内容为矩阵
    extractedMatrix = cell2mat(extractedValues');
    
    % 求最大值
    maxValues = max(extractedMatrix(:));
end
