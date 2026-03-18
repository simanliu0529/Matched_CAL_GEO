clc; clear; close all;
%% 预设置
% 研究区域 中国73-135E，3-54N；云南：97-107，21-30%
Reg.LonMin = 80; %经度
Reg.LonMax = 170;
Reg.LatMin = -60; %纬度
Reg.LatMax = 60;
starttime = datenum('20220901', 'yyyymmdd'); % 时间范围在同一年内
endtime = datenum('20220901', 'yyyymmdd');
correct_flag = 1; % 1--代表进行视差校正  2---代表不进行视差校正
savepath0 = 'F:\FY4AData\Match_CAL_FY4A\';

% --- 匹配阈值设置 ---
% 空间距离阈值：例如，FY4A网格分辨率约为4km，半个格网分辨率取2.5km
DISTANCE_THRESHOLD_KM = 2.5; % 距离阈值 (单位: km)
MaxTimeDiff_hours = 0.5;    % 时间差异阈值 (例如 0.5小时, 即 30分钟)

%% 读取数据——根据自己的数据存储位置修改路径
% dirH8 = '/data/yangyin/liusiman/FYData/FY_4A/'; %加载葵花数据
% fileList_H8 = Fun_filesTraversal([dirH8,'CLM/'],'*_CloudMask.mat'); % 以读取H8的云掩膜
% fileNum_H8 = size(fileList_H8,1);
LatLon = importdata('J:\实验数据\FY4Data\FY4A\CLP\20220901_CloudPhase.mat');
Lon_ori = LatLon.Lon;
Lat_ori = LatLon.Lat;

% 筛选规定区域的经纬度
llFlag = (Reg.LonMin <= Lon_ori & Lon_ori <= Reg.LonMax) & ...
    (Reg.LatMin <= Lat_ori & Lat_ori <= Reg.LatMax);
lonFlag = sum(llFlag, 1) > 0;
latFlag = sum(llFlag, 2) > 0;
% 筛选后的经纬度
FY4A_Lon = Lon_ori(latFlag, lonFlag);
FY4A_Lat = Lat_ori(latFlag, lonFlag);

dirCAL='J:\实验数据\CALIPSO_Data\'; %加载CALIPSO VFM数据

VFM_time = [];
Altitude_VFM = [];
VFM_Lon = [];
VFM_Lat = [];
Data_Result = [];

for correct_flag=1:2
    if correct_flag == 1
        disp('----------------------------------------------------');
        disp('Processing: Spatio-temporal matching with parallax correction (correct_flag = 1)');
    elseif correct_flag == 2
        disp('----------------------------------------------------');
        disp('Processing: Spatio-temporal matching (correct_flag = 2)');
    end
    for time = starttime:1:endtime
        disp(['Handling Time:',datestr(time, 'yyyy-mm-dd')]);
        % 时间间隔是 1 小时 (1/24 天)
        FY4A_Time_All = (time : 1/24 : time + 23/24)';

        %% 匹配CALIPSO
        % 预定义
        RowNum = size(FY4A_Lat,1);
        ColNum = size(FY4A_Lat,2);
        TimeNum = size(FY4A_Time_All,1);
        % 按照需要预定义输出
        CloudTop_CAL_95P = nan*ones(RowNum,ColNum,TimeNum);% 95%分位数的云顶高，标记匹配的CALIPSO廓线是否检测到云，0为无云，1为有云
        CloudTop_CAL_COD = nan*ones(RowNum,ColNum,TimeNum);% 增加COD约束的云顶高，km
        CloudFraction_CAL = nan*ones(RowNum,ColNum,TimeNum);%云分数只是作为一个参考，此处没有更新COD约束的云分数，影响不大
        CloudFraction_CAL_COD = nan*ones(RowNum,ColNum,TimeNum);%更新有COD约束的云分数
        CloudPhase_CAL = nan*ones(RowNum,ColNum,TimeNum); % 云相态——0：晴空、1：水云、2：冰云、3：混合相态
        CloudPhase_CAL_COD = nan*ones(RowNum,ColNum,TimeNum);% 增加COD约束的云相态
        MultiFraction_CAL = nan*ones(RowNum,ColNum,TimeNum);%多层云分数，默认输出为考虑间隔约束的多层云分数
        MultiFraction_CAL_COD = nan*ones(RowNum,ColNum,TimeNum);%增加COD约束的多层云分数

        %%
        % NameTimeStr = [FY4A_Year,'-',FY4A_Month,'-',FY4A_Day];
        NameTimeStr =  datestr(time, 'yyyy-mm-dd');
        DateVector = datevec(time);
        FY4A_Year = DateVector(1);   % 年份 (例如: 2025)
        FY4A_Month = DateVector(2);  % 月份 (例如: 10)
        FY4A_Day = DateVector(3);    % 日期 (例如: 21)
        FY4A_YearStr = num2str(FY4A_Year, '%04d');
        FY4A_MonthStr = num2str(FY4A_Month, '%02d');
        FY4A_DayStr = num2str(FY4A_Day, '%02d');


        % fileList_VFM = Fun_filesTraversal([dirCAL,'VFM/',FY4A_YearStr,FY4A_MonthStr,'\'],['*',NameTimeStr,'*.hdf']); % VFM按年份保存
        fileList_VFM = Fun_filesTraversal([dirCAL,'VFM/'],['*',NameTimeStr,'*.hdf']); % VFM按年份保存

        fileNum_CAL = size(fileList_VFM,1);
        %% 检查 VFM 文件数量，如果为 0 则跳过当前 FY4A 日期的处理
        if fileNum_CAL == 0
            % 提示信息
            disp(['Warning:Skip ', NameTimeStr, '，Because no related VFM file。']);

            % 跳过当前 FY4A 日期循环的剩余部分
            continue;
        end

        for file_i = 1:fileNum_CAL

            %% 读取CALIPSO VFM
            disp(['File ',num2str(file_i),' ',fileList_VFM{file_i,3}]);
            Year_temp = fileList_VFM{file_i,3}(31:34); %VFM文件的年
            Month_temp = fileList_VFM{file_i,3}(36:37);%VFM文件的月
            Day_temp = fileList_VFM{file_i,3}(39:40);%VFM文件的月
            if ~strcmp(Year_temp,FY4A_YearStr) || ~strcmp(Month_temp,FY4A_MonthStr) || ~strcmp(Day_temp,FY4A_DayStr)
                continue;
            end
            Longitude_VFM = single(hdfread(fileList_VFM{file_i,1},'/Longitude'));%初次读入经度1D，3616个经度
            Latitude_VFM = single(hdfread(fileList_VFM{file_i,1},'/Latitude'));%初次读入经度1D，3616个纬度。

            %VFM的经纬度落在H8范围里面的点logic值
            validRange_VFM = Longitude_VFM >= Reg.LonMin & Longitude_VFM <= Reg.LonMax & Latitude_VFM >= Reg.LatMin & Latitude_VFM <= Reg.LatMax; %和tbb重叠的经纬度范围。保留中国区域的经纬范围。
            if(sum(validRange_VFM)==0)
                disp('VFM LatLon is not in ROI LatLon, skip this hdf file!');
                continue;
            end

            % CALIPSO 时间变量
            Profile_Time = hdfread(fileList_VFM{file_i,1}, '/Profile_Time');%读入时间
            dateUTC_Apro = convertTAITime(Profile_Time); %CAPLISO time 转为UTC time。

            % CALIPSO 高度变量
            Altitude = hdfread(fileList_VFM{file_i,1}, '/metadata', 'Fields', 'Lidar_Data_Altitudes', 'FirstRecord',1 ,'NumRecords',1); %每个大点处Vertical上有583个点。
            Altitude = Altitude{1,1};

            %% 匹配CALIPSO的CPro消光系数，提取目标COD处的高度
            % Name_substr = fileList_VFM{file_i,3}(end-14:end);
            Name_substr = fileList_VFM{file_i,3}(end-21:end);
            % filepath_CPro = [];
            % filepath_CPro = [[dirCAL,'CPro\',FY4A_YearStr,FY4A_MonthStr,'\'],strcat('CAL_LID_L2_05kmCPro-Standard-V4-51.',Year_temp,'-',Month_temp,'-',Day_temp,Name_substr)];
            filepath_CPro = [[dirCAL,'CPro\'],strcat('CAL_LID_L2_05kmCPro-Standard-V4-51.',Year_temp,'-',Month_temp,'-',Day_temp,Name_substr)];

            TargetCOD = 0.2; % 预定义目标光学厚度
            if ~isempty(filepath_CPro)
                [Flag_VFM, CAL_H, ~,Latitude_CPro] = Fun_Calculate_TargetH(filepath_CPro,TargetCOD,Latitude_VFM,Altitude,Reg);
                validRange_VFM = validRange_VFM & Flag_VFM';
                % 如果 VFM 文件中没有数据点落入 ROI 范围
                if sum(validRange_VFM) == 0
                    disp(['注意：跳过文件 ', fileList_VFM{file_i,1}, '，无 VFM 廓线落入 ROI 范围。']);
                    continue; % 跳到 for 循环的下一个文件
                end
            else
                CAL_H = [];
            end

            %% 更新 VFM范围
            VFM_Lon = Longitude_VFM(validRange_VFM); %截取ROI范围内经度
            VFM_Lat = Latitude_VFM(validRange_VFM);%截取ROI范围内纬度
            VFM_time = dateUTC_Apro(validRange_VFM); %每个点对应的时间。
            Altitude_VFM = cat(1,Altitude_VFM,repmat(Altitude',sum(validRange_VFM),1)); %每个点对应一个廓线共583个垂直点。[983 by 583],每一行重复。

            %% 提取CALIPSO云顶高、云分数、多层云标识及其占比，并平均至5km
            type = 'all'; %phase
            start = [0 0];
            edges = [-9 -9];
            block = Fun_Read_VFM(fileList_VFM{file_i,1},validRange_VFM,type,start,edges,0); %[N*15,545]
            start_extend = repmat(block(:,1),[1,32]);
            end_extend = repmat(block(:,end),[1,6]);
            block = [start_extend,block,end_extend];
            block_5km = block;
            block_5km = round(block_5km);
            block_5km = uint8(block_5km);
            Mean_Horizontal = 15;  % 水平平均到5km
            % 有云顶高肯定代表有云，不需要单独保存CAL_Mask
            % VFM_CloudFration有2列，第1列：云分数 = 云廓线./有效廓线数量；第2列：有效廓线数量
            % VFM_CloudTop有4列，第1列：5km范围内最高云顶高；第2列：5km范围内TOP5%云顶高；
            % 第3列：5km范围内平均云顶高；第4列：5km范围内满足COD约束的云顶高；
            % VFM_MultiLayerF，5km范围内多层云分数 = 多层云廓线./云廓线
            % 有2个元胞，第1个元胞未做COD限制的多层云；第2个元胞满足COD约束的多层云，即从COD的起始点位以下是否存在多层云
            % 2个元胞均包含2列，第1列：未做限制的多层云分数；第2列：满足最小云间隔约束的多层云分数
            [~,VFM_CloudFration,VFM_CloudTop,~] = Fun_VFM_CloudPhaseCloudTop_HorizonRes_LSM...
                (block_5km,Mean_Horizontal,1,1,type,Altitude,CAL_H);

            %% 提取CALIPSO云相态，并平均至5km
            type = 'phase'; %
            start = [0 0];
            edges = [-9 -9];
            block = Fun_Read_VFM(fileList_VFM{file_i,1},validRange_VFM,type,start,edges,0); %[N*15,545]
            start_extend = repmat(block(:,1),[1,32]);
            end_extend = repmat(block(:,end),[1,6]);
            block = [start_extend,block,end_extend];
            block_5km = block;
            block_5km = round(block_5km);
            block_5km = uint8(block_5km);
            Mean_Horizontal = 15;  % 水平平均到5km
            % VFM_CloudPhase有2列，第1列：所以云bin的统计；第2列：满足COD约束的云相态，即从COD的起始点位以下的云相态
            [VFM_CloudPhase,~,~,VFM_MultiFraction] = Fun_VFM_CloudPhaseCloudTop_HorizonRes_LSM...
                (block_5km,Mean_Horizontal,1,1,type,Altitude,CAL_H);


            % 视差矫正 (如果未启用矫正，则等于 VFM_Lat)
            if correct_flag==1
                [VFM_Lat_new,VFM_Lon_new,s] = Fun_ParallaxCorrection(VFM_Lat, VFM_Lon, VFM_CloudTop(:,4), 2);
                VFM_Lat_new(isnan(VFM_Lat_new)) = VFM_Lat(isnan(VFM_Lat_new));
                VFM_Lon_new(isnan(VFM_Lon_new)) = VFM_Lon(isnan(VFM_Lon_new));
                diff1 = VFM_Lat_new-VFM_Lat;
                diff2 =VFM_Lon_new-VFM_Lon;
                s1 = diff1*5;
                s2 = diff2*5;
                sbat = sqrt(s1.^2+s2.^2);
                disp(['Maximum Offset：',num2str(max(s./1000)),'km']);
                disp(['Maximum Offset：',num2str(max(sbat)),'km']);
                savepath = [savepath0,'AfterCorrection\'];
                correctflag_str = 'Corrected';
            elseif correct_flag==2
                VFM_Lat_new = VFM_Lat;
                VFM_Lon_new = VFM_Lon;
                savepath = [savepath0,'BeforeCorrection\'];
                correctflag_str = '';
            end

            % 若目录不存在，则创建
            if ~exist(savepath, 'dir')
                mkdir(savepath);
            end

            %% 调用封装的匹配函数
            [Index_All_unique, Index_VFM_Original] = Fun_match_SpatioTemporal_Optimized(...
                FY4A_Lon, FY4A_Lat, FY4A_Time_All, ...
                VFM_Lon_new, VFM_Lat_new, VFM_time, ...
                DISTANCE_THRESHOLD_KM, MaxTimeDiff_hours);

            % 检查是否有有效匹配
            if isempty(Index_All_unique)
                disp('No valid spatiotemporal matches found in this CALIPSO file.');
                continue;
            end

            % ZY备忘有用的检索语句 v=Lon_tbb(sub2ind(size(Lon_tbb),Index_All(:,1),Index_All(:,2)));
            for grid_i = 1:size(Index_All_unique,1) %遍历每一个唯一的匹配的 FY4A 网格点
                gridLat = Index_All_unique(grid_i,1);
                gridLon = Index_All_unique(grid_i,2);
                gridTime = Index_All_unique(grid_i,3);

                % 找到所有匹配到当前 FY4A 网格点 (Index_All_unique 的第 grid_i 行) 的 VFM 廓线
                % Index_VFM_Original 中的值等于 grid_i 的那些元素，就是匹配到该网格点的 VFM 廓线索引。
                Index_Profile = find(Index_VFM_Original == grid_i);

                % ... (数据赋值逻辑不变) ...

                % 云顶高
                CloudTop_CAL_95P(gridLat,gridLon,gridTime) = nanmean(VFM_CloudTop(Index_Profile,2));
                CloudTop_CAL_COD(gridLat,gridLon,gridTime) = nanmean(VFM_CloudTop(Index_Profile,4));

                % 最大云分数
                CloudFraction_CAL(gridLat,gridLon,gridTime) = fun_extractMaxAtRows_LSM(VFM_CloudFration,Index_Profile,1);
                CloudFraction_CAL_COD(gridLat,gridLon,gridTime) = fun_extractMaxAtRows_LSM(VFM_CloudFration,Index_Profile,3);

                % 多层云分数
                % MultiFraction_CAL(gridLat,gridLon,gridTime) = mode(cell2mat(cellfun(@(x) x(1), VFM_MultiFraction(Index_Profile,1), 'UniformOutput', false)));
                % MultiFraction_CAL_COD(gridLat,gridLon,gridTime) = mode(cell2mat(cellfun(@(x) x(1), VFM_MultiFraction(Index_Profile,2), 'UniformOutput', false)));
                vals = cell2mat(cellfun(@(x) x(1), VFM_MultiFraction(Index_Profile,1), 'UniformOutput', false));
                if isempty(vals)
                    MultiFraction_CAL(gridLat,gridLon,gridTime) = NaN;
                else
                    % 若存在混合云(3)，标记为3；否则取最大类别
                    if any(vals == 3)
                        MultiFraction_CAL(gridLat,gridLon,gridTime) = 3;
                    else
                        MultiFraction_CAL(gridLat,gridLon,gridTime) = mode(vals);
                    end
                end
                vals_COD = cell2mat(cellfun(@(x) x(1), VFM_MultiFraction(Index_Profile,2), 'UniformOutput', false));

                if isempty(vals_COD)
                    MultiFraction_CAL_COD(gridLat,gridLon,gridTime) = NaN;
                else
                    if any(vals_COD == 3)
                        MultiFraction_CAL_COD(gridLat,gridLon,gridTime) = 3;
                    else
                        MultiFraction_CAL_COD(gridLat,gridLon,gridTime) = mode(vals_COD);
                    end
                end

                % 云相态
                % ... (CloudPhase_CAL 和 CloudPhase_CAL_COD 的赋值逻辑不变) ...
                VFM_CloudPhase_temp = VFM_CloudPhase(Index_Profile,1);%云相位特征
                if length(unique(VFM_CloudPhase_temp)) == 1
                    CloudPhase_CAL(gridLat,gridLon,gridTime) = unique(VFM_CloudPhase_temp);
                elseif length(unique(VFM_CloudPhase_temp)) == 2 && sum(unique(VFM_CloudPhase_temp)==0)>=1
                    CloudPhase_CAL(gridLat,gridLon,gridTime) = max(unique(VFM_CloudPhase_temp));
                elseif length(unique(VFM_CloudPhase_temp)) > 2
                    CloudPhase_CAL(gridLat,gridLon,gridTime) = 3;
                end

                VFM_CloudPhase_temp = VFM_CloudPhase(Index_Profile,2);%COD约束的云相态
                if length(unique(VFM_CloudPhase_temp)) == 1
                    CloudPhase_CAL_COD(gridLat,gridLon,gridTime) = unique(VFM_CloudPhase_temp);
                elseif length(unique(VFM_CloudPhase_temp)) == 2 && sum(unique(VFM_CloudPhase_temp)==0)>=1
                    CloudPhase_CAL_COD(gridLat,gridLon,gridTime) = max(unique(VFM_CloudPhase_temp));
                elseif length(unique(VFM_CloudPhase_temp)) > 2
                    CloudPhase_CAL_COD(gridLat,gridLon,gridTime) = 3;
                end
            end

        end
        %% 将数据保存
        if file_i == fileNum_CAL %假如到最后一个文件了就存储
            % Time_Current = fileList_H8{fileH8_i,3}(1:8);
            Time_Current = datestr(time, 'yyyymmdd');
            Data_Result.Lon = FY4A_Lon;
            Data_Result.Lat = FY4A_Lat;
            Data_Result.Time = FY4A_Time_All;
            Data_Result.CloudTop_CAL_95P = CloudTop_CAL_95P; % 和静止卫星数据一样的结构
            Data_Result.CloudTop_CAL_COD = CloudTop_CAL_COD; % 和静止卫星数据一样的结构
            Data_Result.CloudFraction_CAL = CloudFraction_CAL;
            Data_Result.CloudFraction_CAL_COD = CloudFraction_CAL_COD;
            Data_Result.CloudPhase_CAL = CloudPhase_CAL; % 和H8数据一样的结构
            Data_Result.CloudPhase_CAL_COD = CloudPhase_CAL_COD; % 和H8数据一样的结构
            Data_Result.MultiFraction_CAL = MultiFraction_CAL;
            Data_Result.MultiFraction_CAL_COD = MultiFraction_CAL_COD; % 和H8数据一样的结构
            save([savepath,correctflag_str,'MatchedVFM_CloudProperty_',Time_Current,'.mat'],'Data_Result','-v7.3');
            Data_Result=[];
        end
    end
end