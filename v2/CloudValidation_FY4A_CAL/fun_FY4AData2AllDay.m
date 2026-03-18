function [H8_Cloud_All, H8_Time_All] = fun_FY4AData2AllDay(H8_Cloud_Time, H8_CloudMask)
    % 输入：
    % H8_Cloud_Time - datenum 格式的时间向量
    % H8_CloudMask  - 对应时间序列的云掩膜（行×列×时间）
    % 输出：
    % H8_Cloud_All  - 填充后完整 24 小时的云掩膜（NaN 表示无观测）
    % H8_Time_All   - 对应 24 小时时间向量

    % 1️⃣ 获取时间范围
    start_day = floor(min(H8_Cloud_Time));
    end_day   = floor(max(H8_Cloud_Time));
    total_days = end_day - start_day + 1;

    % 2️⃣ 构建完整 24 小时时间轴
    H8_Time_All = (start_day : 1/24 : end_day + 23/24)';  % 每小时一个时间点
    H8_Time_All = H8_Time_All(1 : total_days * 24);

    % 3️⃣ 预分配输出矩阵
    [m, n, ~] = size(H8_CloudMask);
    H8_Cloud_All = nan(m, n, length(H8_Time_All), 'single');

    % 4️⃣ 填充对应时次
    for i = 1:length(H8_Cloud_Time)
        % 找到该时间在完整时间轴中的位置（误差<1分钟）
        idx = find(abs(H8_Time_All - H8_Cloud_Time(i)) < 1/1440, 1);
        if ~isempty(idx)
            H8_Cloud_All(:,:,idx) = single(H8_CloudMask(:,:,i));
        end
    end
end

