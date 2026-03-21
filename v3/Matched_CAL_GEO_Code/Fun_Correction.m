function [Diff,corrected_data,lon_new,lat_new] = Fun_Correction(flag,Data,lon,lat,CTH)
%H8_CORRECTION 此处显示有关此函数的摘要
%   此处显示详细说明
% 设置视差校正参数
thetaS = 0; % 葵花8号卫星的视纬度
if flag==1
    phiS = 140.7; % 葵花8号卫星的视经度
elseif flag==2
    phiS = 104.7; % 风云4A卫星的视经度
elseif flag==3
    phiS = 133; % 风云4B卫星的视经度
end
[height,width,times] = size(Data);
[Y,X] = meshgrid(1:width,1:height);
corrected_data = nan(size(Data));
% interp_data = nan(size(Data));
Diff = nan(size(Data));
for time = 1:times
    disp(['此文件处理进度',num2str(time),'/',num2str(times)]);
    Hc = CTH(:,:,time);
    data = Data(:,:,time);
    [lat_new, lon_new, diff] = Fun_Correct(lat, lon, thetaS, phiS, Hc);
    % [lat_new, lon_new, diff] = parallaxcorrection1(lat, lon, thetaS, phiS, Hc);
    Diff(:,:,time) = diff;
    parallax_dx= lat_new - lat;
    parallax_dy = lon_new - lon;

    % 检查数据维度一致性
    if ~isequal(size(parallax_dx), size(data)) || ~isequal(size(parallax_dy), size(data))
        error('Dimensions of parallax_dx or parallax_dy do not match cloud_mask.');
    end

    % 应用视差校正
    corrected_data(isnan(Hc)) = data(isnan(Hc)); % 云顶高度为NaN时不进行校正
    new_i = round(X + parallax_dx/0.05);
    new_j = round(Y + parallax_dy/0.05);
    % 修正超出范围的索引
    new_i = max(1, min(height, new_i)); % 限制 new_i 在 [1, height]
    new_j = max(1, min(width, new_j));  % 限制 new_j 在 [1, width]
    valid_mask = X >= 1 & X <= height & Y >= 1 & Y <= width & ~isnan(data);
    % 检查掩码是否为空
    if ~any(valid_mask(:))
        warning('No valid indices for time step %d. Skipping this step.', time);
        continue; % 跳过当前时间步
    end
    valid_mask1 = X >= 1 & X <= height & Y >= 1 & Y <= width ;
    valid_mask2 = new_i >= 1 & new_i <= height & new_j >= 1 & new_j <= width;
    
    % 边界检查
    linear_idx_new = sub2ind([height,width],new_i(valid_mask2),new_j(valid_mask2));
    linear_idx_old = sub2ind([height,width],X(valid_mask1),Y(valid_mask1));
    % 将原始数据映射到新的位置，对数据做校正
    data_new = nan(height,width);
    data_new(linear_idx_new) = data(linear_idx_old);
    data_new(isnan(Hc) & ~isnan(data)) = data(isnan(Hc) & ~isnan(data));
    corrected_data(:,:,time) = data_new;

    % %% 使用插值填补 NaN 值
    % interpolated_data_temp = data_new;
    % nan_mask = isnan(corrected_data(:, :, time)) & ~isnan(data);
    % 
    % % 对云相态插值
    % is_clear = data_new==0;
    % is_water = data_new==1;
    % is_mixed = data_new==2;
    % is_ice = data_new==3;
    % A = [1 1 1; 1 1 1; 1 1 1] / 9;  % 平滑滤波器（均值卷积核）
    % clear = conv2(is_clear, A, 'same');
    % water = conv2(is_water, A, 'same');
    % mixed = conv2(is_mixed, A, 'same');
    % ice = conv2(is_ice, A, 'same');
    % % 根据卷积结果，确定每个位置的主导云相态
    % [~, max_idx] = max(cat(3, clear, water, mixed, ice), [], 3);
    % % 使用 nan_mask 确定需要插值的位置，并填补：
    % interpolated_data_temp(nan_mask & max_idx == 1) = 0;  % 填补晴空
    % interpolated_data_temp(nan_mask & max_idx == 2) = 1;  % 填补水云
    % interpolated_data_temp(nan_mask & max_idx == 3) = 2;  % 填补混合云
    % interpolated_data_temp(nan_mask & max_idx == 4) = 3;  % 填补冰云
    % interp_data(:,:,time) = interpolated_data_temp;
end
end