% 函数功能：匹配CALIPSO的CPro消光系数，提取目标COD处的高度
% 输入：
% filepath_CPro：CPro的文件名
% Latitude_VFM：VFM对应的纬度
% Altitude_CAL：VFM读取的CALIPSO高度
% 输出：
% Flag_VFM：和CPro匹配的VFM经纬度范围
% CAL_H：COD=0.02处的高度

function [Flag_VFM, CAL_H, COD,Latitude_CPro] = Fun_Calculate_TargetH(filepath_CPro,TargetCOD,Latitude_VFM,Altitude_CAL,Reg)
    start = [0 0];
    edges = [-9 -9];
    variable = 'Longitude';
    [~,Longitude_CPro] = readHDF(filepath_CPro,variable,start,edges);
    variable = 'Latitude';
    [~,Latitude_CPro] = readHDF(filepath_CPro,variable,start,edges);%

    % variable = 'Column_Optical_Depth_Cloud_532';
    % [~, Column_COD_532] = readHDF(filepath_CPro,variable,start,edges);

    % CPro的经纬度落在目标范围里面的点logic值
    validRange_CPro = Longitude_CPro(:,2) >= Reg.LonMin & Longitude_CPro(:,2) <= Reg.LonMax & Latitude_CPro(:,2) >= Reg.LatMin & Latitude_CPro(:,2) <= Reg.LatMax; %和tbb重叠的经纬度范围。保留中国区域的经纬范围。
    if(sum(validRange_CPro)==0)
        disp('Cpro LatLon is not in ROI LatLon, skip this hdf file!');
        Flag_VFM = [];
        CAL_H = [];
        return;
    end       

    [Flag_VFM, Flag_CPro] = Fun_VFM_CPro_Match(Latitude_VFM,Latitude_CPro(:,2));
    if sum(Flag_VFM) == 0 || sum(Flag_CPro) == 0
        Flag_VFM = [];
        CAL_H = [];
        returen;
    end 

    validRange_CPro = validRange_CPro' & Flag_CPro;
    Latitude_CPro = Latitude_CPro(validRange_CPro,:);
    Longitude_CPro = Longitude_CPro(validRange_CPro,:);
    % Column_COD_532 =  Column_COD_532(validRange_CPro,:);

    %% 读取消光系数，并计算积分COD
    variable = 'Extinction_Coefficient_532';
    [~, CPro_alpha] = readHDF(filepath_CPro,variable,start,edges);
    CPro_alpha = CPro_alpha';
    % CPro数据高度（399 bins）
    Altitude_CPro = hdfread(filepath_CPro,'/metadata', 'Fields',...
        'Lidar_Data_Altitudes');
    Altitude_CPro = Altitude_CPro{1,1}; % 为什么会有{1,1}？因为原来的激光雷达数据高度储存方式是元胞数组型，这里提取出矩阵型。
    % 构建有效值掩码
    validMask = CPro_alpha ~= -9999;
    % 将无效值设为 0（便于计算）
    CPro_alpha(~validMask) = 0;
    COD = -cumtrapz(Altitude_CPro, CPro_alpha);
    COD(CPro_alpha == 0) = NaN;
    % 提取有效空间范围内的COD
    COD = COD(:,validRange_CPro);

    %% 提取目标COD所对应的高度TargetH
    % 初始化结果
    [~, n_profile] = size(COD);
    TargetH = NaN(1, n_profile); % 默认输出为 NaN
    validMask = nansum(COD) > 0;
    % 利用矩阵操作插值
    for col_i = 1:n_profile
        if any(validMask(:, col_i)) % 如果该列有有效值
            % 对有效数据进行去重和排序
            x = COD(:, col_i); % 有效 COD 值
            [x_sorted, uniqueIdx, ic] = unique(x, 'sorted');
            index = ~isnan(x_sorted);
            if sum(index) > 1
                uniqueIdx = uniqueIdx(index);
                x_sorted = x_sorted(index);
                y = Altitude_CPro(uniqueIdx);
                % 插值，允许外延
                TargetH(col_i) = interp1(x_sorted, y, TargetCOD, 'linear', 'extrap');
                % TargetH(col_i) = interp1(x_sorted, y, TargetCOD, 'linear', NaN);
            end
        end
    end
    % TargetH(TargetH<0 | TargetH>30) = NaN;

    %% 根据估计的目标COD所对应的高度TargetH，输出最邻近的Altitude_CAL的高度
    TargetH_rep = repmat(TargetH,size(Altitude_CAL,1),1);
    Altitude_VFM = repmat(Altitude_CAL,1,size(TargetH,2));
    [~, ClosestRow] = min(abs(Altitude_VFM - TargetH), [], 1); % 找到最小差值的索引
    CAL_H(1,:) = Altitude_VFM(sub2ind(size(Altitude_VFM), ClosestRow, 1:size(Altitude_VFM, 2))); % 提取对应值
    CAL_H(2,:) = ClosestRow; % 代表number of bin
    % CAL_H(:,isnan(TargetH)) = NaN;

end
