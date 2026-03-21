function [Flag_VFM, Flag_CPro] = Fun_VFM_CPro_Match(Latitude_VFM,Latitude_CPro)
% 获取两个向量的长度
lenA = length(Latitude_VFM);
lenB = length(Latitude_CPro);

% 初始化 Flag
Flag_VFM = zeros(1, lenA);
Flag_CPro = zeros(1, lenB);

% 找到所有相同数值的位置
[commonValues, idxA, idxB] = intersect(Latitude_VFM, Latitude_CPro, 'stable');

% 如果存在相同数值
if ~isempty(commonValues)
    % 计算相同值在 idxA 和 idxB 中的差分
    diffIdxA = [0, diff(idxA)' == 1];
    diffIdxB = [0, diff(idxB)' == 1];
    continuousMask = diffIdxA & diffIdxB;

    % 分组连续段并计算长度
    group = cumsum(~continuousMask);
    groupLengths = accumarray(group(:), 1);
    [maxLen, maxGroup] = max(groupLengths);

    % 找到最大连续段的索引
    maxIndices = find(group == maxGroup);

    % 截取最大连续段
    Latitude_VFM = Latitude_VFM(idxA(maxIndices));
    Latitude_CPro = Latitude_CPro(idxB(maxIndices));
    Flag_VFM(idxA(maxIndices)) = 1;
    Flag_CPro(idxB(maxIndices)) = 1;
else
    % 如果没有相同部分，清空结果
    Latitude_VFM = [];
    Latitude_CPro = [];
end
end