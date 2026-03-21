function [COD_All, ProfileIndices] = Fun_ReadCOD_AllProfiles(filepath_CPro, Latitude_VFM, Altitude_CAL, Reg)
% FUN_READCOD_ALLPROFILES 读取所有廓线的完整COD数据
%
% 输入:
%   filepath_CPro  - CPro文件路径
%   Latitude_VFM  - VFM廓线纬度向量
%   Altitude_CAL  - CALIPSO高度向量
%   Reg           - 区域范围结构体
%
% 输出:
%   COD_All       - COD数据矩阵 [N_altitude, N_profiles]，每列是一根廓线的COD
%   ProfileIndices - 有效廓线的索引（相对于原始VFM数据）

start = [0 0];
edges = [-9 -9];

% 读取经纬度
variable = 'Longitude';
[~, Longitude_CPro] = readHDF(filepath_CPro, variable, start, edges);
variable = 'Latitude';
[~, Latitude_CPro_Raw] = readHDF(filepath_CPro, variable, start, edges);

% 检查范围
validRange_CPro = Longitude_CPro(:,2) >= Reg.LonMin & ...
                  Longitude_CPro(:,2) <= Reg.LonMax & ...
                  Latitude_CPro_Raw(:,2) >= Reg.LatMin & ...
                  Latitude_CPro_Raw(:,2) <= Reg.LatMax;

if sum(validRange_CPro) == 0
    COD_All = [];
    ProfileIndices = [];
    return;
end

% 匹配 VFM 和 CPro
[Flag_VFM, Flag_CPro] = Fun_VFM_CPro_Match(Latitude_VFM, Latitude_CPro_Raw(:,2));

if sum(Flag_VFM) == 0 || sum(Flag_CPro) == 0
    COD_All = [];
    ProfileIndices = [];
    return;
end

validRange_CPro = validRange_CPro(:) & Flag_CPro(:);
ProfileIndices = find(Flag_VFM);  % 返回匹配的VFM廓线索引

% 读取消光系数，并计算积分COD
variable = 'Extinction_Coefficient_532';
[~, CPro_alpha] = readHDF(filepath_CPro, variable, start, edges);
CPro_alpha = CPro_alpha'; % 转置后维度为 [高度 x 廓线数]

% CPro数据高度
Altitude_CPro = hdfread(filepath_CPro, '/metadata', 'Fields', 'Lidar_Data_Altitudes');
if iscell(Altitude_CPro)
    Altitude_CPro = Altitude_CPro{1,1};
end

% 构建有效值掩码
validMask_Data = CPro_alpha ~= -9999;

% 将无效值设为 0（便于积分）
CPro_alpha(~validMask_Data) = 0;

% 积分计算 COD
COD = -cumtrapz(Altitude_CPro, CPro_alpha);

% 提取有效空间范围内的COD
COD_All = COD(:, validRange_CPro);

end

