function maxValues = fun_extractMaxAtRows(A, indices)
  % 提取每个元胞中指定行号的元素
    extractedValues = cellfun(@(x) x, A(indices,1), 'UniformOutput', false);
    
    % 将元胞中的提取元素转换为一个矩阵，每个矩阵按列排列
    extractedMatrix = cell2mat(extractedValues');
    
    % 计算提取出的所有行的最大值
    maxValues = max(max(extractedMatrix, [], 1));
end