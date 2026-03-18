% ZL（zanglin2018@whu.edu.cn)
% 读取的CALIPSO的VFM数据,用VFM生成一个和H8数据[881,1101,Ntimes]大小相同的中国区域的云熟悉分布数据集，并与H8匹配
clc; clear; close all;

ifcorrect = 1;
%% 预设置
% % 研究区域 中国73-135E，3-54N；云南：97-107，21-30%
% Reg.LonMin = 80; %经度
% Reg.LonMax = 170;
% Reg.LatMin = -60; %纬度
% Reg.LatMax = 60;
Reg.LonMin = 73; %经度
Reg.LonMax = 135;
Reg.LatMin = 3; %纬度
Reg.LatMax = 54;
%% 读取数据——根据自己的数据存储位置修改路径
dirH8 = '/PublicData/H8_FY4A_ProAccess/Data/H8_Data/'; %加载葵花数据
fileList_H8 = Fun_filesTraversal([dirH8,'CLM/'],'*_CloudMask.mat'); % 以读取H8的云掩膜
fileNum_H8 = size(fileList_H8,1);

dirCAL='/PublicData/H8_FY4A_ProAccess/Data/CALIPSO_Data/'; %加载CALIPSO VFM数据

VFM_time = [];
Altitude_VFM = [];
VFM_Lon = [];
VFM_Lat = [];
Data_Result = [];
Time_Last = [];

lat = 54:-0.05:3;
lon = 73:0.05:135;
[H8_Lon,H8_Lat] = meshgrid(lon,lat);
for fileH8_i = 1:fileNum_H8
% for fileH8_i = 104
    H8_Cloud_temp = importdata(fileList_H8{fileH8_i,1});%把某波段某月的mat文件读出来
    H8_Year = fileList_H8{fileH8_i,3}(1:4);
    H8_Month = fileList_H8{fileH8_i,3}(5:6);
    H8_Day = fileList_H8{fileH8_i,3}(7:8);
    % 输入的云掩膜应该是完成视差校正的结果
    % H8_Lon = H8_Cloud_temp.Lon; 
    % H8_Lat = H8_Cloud_temp.Lat;
    H8_Cloud_Time = H8_Cloud_temp.Time;
    clear H8_Cloud_temp
    % 将数据还原为每天24小时观测，无观测时为NaN
    [~,H8_Time_All] = fun_H8Data2AllDay(H8_Cloud_Time);    
   
    %% 匹配CALIPSO
    % 预定义
    RowNum = size(H8_Lat,1);
    ColNum = size(H8_Lat,2);
    TimeNum = size(H8_Time_All,1);
    % 按照需要预定义输出
    CloudTop_CAL_95P = nan*ones(RowNum,ColNum,TimeNum);% 95%分位数的云顶高，标记匹配的CALIPSO廓线是否检测到云，0为无云，1为有云
    CloudTop_CAL_COD = nan*ones(RowNum,ColNum,TimeNum);% 增加COD约束的云顶高，km
    CloudFraction_CAL = nan*ones(RowNum,ColNum,TimeNum);%云分数只是作为一个参考，此处没有更新COD约束的云分数，影响不大
    CloudPhase_CAL = nan*ones(RowNum,ColNum,TimeNum); % 云相态——0：晴空、1：水云、2：冰云、3：混合相态
    CloudPhase_CAL_COD = nan*ones(RowNum,ColNum,TimeNum);% 增加COD约束的云相态
    MultiFraction_CAL = nan*ones(RowNum,ColNum,TimeNum);%多层云分数，默认输出为考虑间隔约束的多层云分数
    MultiFraction_CAL_COD = nan*ones(RowNum,ColNum,TimeNum);%增加COD约束的多层云分数
    
    %%
    NameTimeStr = [H8_Year,'-',H8_Month,'-',H8_Day];
    fileList_VFM = Fun_filesTraversal([dirCAL,'VFM/'],['*',NameTimeStr,'*.hdf']); % VFM按年份保存
    fileNum_CAL = size(fileList_VFM,1);
    
    for file_i = 1:fileNum_CAL
        %% 读取CALIPSO VFM
        disp(['File ',num2str(file_i),' ',fileList_VFM{file_i,3}]);
        Year_temp = fileList_VFM{file_i,3}(31:34); %VFM文件的年
        Month_temp = fileList_VFM{file_i,3}(36:37);%VFM文件的月
        Day_temp = fileList_VFM{file_i,3}(39:40);%VFM文件的月
        if ~strcmp(Year_temp,H8_Year) || ~strcmp(Month_temp,H8_Month) || ~strcmp(Day_temp,H8_Day)
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
        Name_substr = fileList_VFM{file_i,3}(end-21:end);
        % filepath_CPro = [];
        filepath_CPro = [[dirCAL,'CPro/'],strcat('CAL_LID_L2_05kmCPro-Standard-V4-51.',Year_temp,'-',Month_temp,'-',Day_temp,Name_substr)]; 
        TargetCOD = 0.02; % 预定义目标光学厚度
        if ~isempty(filepath_CPro)
            [Flag_VFM, CAL_H, ~,Latitude_CPro] = Fun_Calculate_TargetH(filepath_CPro,TargetCOD,Latitude_VFM,Altitude,Reg);
            validRange_VFM = validRange_VFM & Flag_VFM'; 
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
        [~,VFM_CloudFration,VFM_CloudTop,VFM_MultiFraction] = Fun_VFM_CloudPhaseCloudTop_HorizonRes...
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
        [VFM_CloudPhase,~,~] = Fun_VFM_CloudPhaseCloudTop_HorizonRes...
            (block_5km,Mean_Horizontal,1,1,type,Altitude,CAL_H); 
        
        %% 视差矫正 使用满足COD约束的云顶高进行视差校正 输入第四个参数flag=1时为H8，flag=2时为FY4A，flag=3时为FY4B
        if ifcorrect == 1
            VFM_Lat_new = VFM_Lat;
            VFM_Lon_new = VFM_Lon;
            correct_name = '_uncorrected';
        else
            [VFM_Lat_new,VFM_Lon_new] = Fun_ParallaxCorrection(VFM_Lat, VFM_Lon, VFM_CloudTop(:,2), 1);
            VFM_Lat_new(isnan(VFM_CloudTop(:,2))) = VFM_Lat(isnan(VFM_CloudTop(:,2)));
            VFM_Lon_new(isnan(VFM_CloudTop(:,2))) = VFM_Lon(isnan(VFM_CloudTop(:,2)));
            correct_name = '';
            diff1 = VFM_Lat_new-VFM_Lat;
            diff2 =VFM_Lon_new-VFM_Lon;
            s1 = diff1*5;
            s2 = diff2*5;
            s = sqrt(s1.^2+s2.^2);
            disp(['最大偏移量：',num2str(max(s))]);
        end
        %% CALIPSO每条廓线对应的网格索引——最邻近匹配原则
        % 经度匹配
        H8_Lon2 = repmat(H8_Lon(1,:),length(VFM_Lon_new),1);
        VFM_Lon2 = repmat(VFM_Lon_new,1,size(H8_Lon,2));
        diff_Lon = abs(H8_Lon2-VFM_Lon2); %某一行为某一个VFM经度和所有H8经度的差。
        [~,Index_Lon] = min(diff_Lon,[],2); %对每一个VFM的经度，和它最接近的H8经度的index
        Index_Lon = single(Index_Lon);
        % 纬度匹配
        H8_Lat2 = repmat(H8_Lat(:,1)',length(VFM_Lat_new),1);
        VFM_Lat2 = repmat(VFM_Lat_new,1,size(H8_Lat,1));
        diff_Lat = abs(H8_Lat2-VFM_Lat2);
        [~,Index_Lat] = min(diff_Lat,[],2);%%对每一个VFM的纬度，和它最接近的H8纬度的index
        Index_Lat = single(Index_Lat);
        % 时间匹配
        H8_Time2 = repmat(H8_Time_All',length(VFM_time),1);
        VFM_time2 = repmat(VFM_time,1,length(H8_Time_All));
        diff_Time = abs(H8_Time2-VFM_time2);%某一行为某一个VFM时间和所有H8时间的差。
        [Min_DiffTime,Index_Time] = min(diff_Time,[],2);%对每一个VFM时间，和它最接近的H8时间的index。
        Index_Time(Min_DiffTime>0.5/24) = NaN; % 30min为限制
        if sum(isnan(Index_Time)) == length(Index_Time); continue; end
        Index_Time = single(Index_Time);
        Index_All = [Index_Lat,Index_Lon,Index_Time]; %每个VFM点，H8的经纬度和时间索引。
        Index_All_unique = unique(Index_All,'rows'); %去掉重复行。对某个VFM点，和它最接近的是某经纬度时刻的H8数据，对另一个VFM点，和它最接近的还是这个经纬度时刻的H8。
       
        % ZY备忘有用的检索语句 v=Lon_tbb(sub2ind(size(Lon_tbb),Index_All(:,1),Index_All(:,2)));
        for grid_i = 1:size(Index_All_unique,1) %遍历每一个匹配的点
            gridLat = Index_All_unique(grid_i,1);
            gridLon = Index_All_unique(grid_i,2);
            gridTime = Index_All_unique(grid_i,3);         
            if  ~isnan(gridTime)            
                Index_Profile = find(sum(abs(Index_All-Index_All_unique(grid_i,:)),2)==0); %找到了几个VFM大点
                
                % 云顶高
                CloudTop_CAL_95P(gridLat,gridLon,gridTime) = nanmean(VFM_CloudTop(Index_Profile,2)); % 5km内的上95%分位数，单位km
                CloudTop_CAL_COD(gridLat,gridLon,gridTime) = nanmean(VFM_CloudTop(Index_Profile,4)); % 5km内顾及COD约束的云顶高，单位km
                
                % 最大云分数:取值范围为0~1
                CloudFraction_CAL(gridLat,gridLon,gridTime) = fun_extractMaxAtRows(VFM_CloudFration,Index_Profile);
                
                % 多层云分数——5km内考虑最小云层间隔
                MultiFraction_CAL(gridLat,gridLon,gridTime) = nanmean(cell2mat(cellfun(@(x) x(2), VFM_MultiFraction(Index_Profile,1), 'UniformOutput', false)));
                MultiFraction_CAL_COD(gridLat,gridLon,gridTime) = nanmean(cell2mat(cellfun(@(x) x(2), VFM_MultiFraction(Index_Profile,2), 'UniformOutput', false)));
                
                % 云相态——0：晴空、1：水云、2：冰云、3：混合相态
                VFM_CloudPhase_temp = VFM_CloudPhase(Index_Profile,1);%云相位特征
                if length(unique(VFM_CloudPhase_temp)) == 1
                    CloudPhase_CAL(gridLat,gridLon,gridTime) = unique(VFM_CloudPhase_temp);
                elseif length(unique(VFM_CloudPhase_temp)) == 2 && sum(unique(VFM_CloudPhase_temp)==0)>=1 % 部分云填充，做云像元处理
                    CloudPhase_CAL(gridLat,gridLon,gridTime) = max(unique(VFM_CloudPhase_temp));
                elseif length(unique(VFM_CloudPhase_temp)) > 2 % 多类型云，将像元简单定义为混合相态
                    CloudPhase_CAL(gridLat,gridLon,gridTime) = 3;
                end
                
                 % COD约束的云相态——0：晴空、1：水云、2：冰云、3：混合相态
                VFM_CloudPhase_temp = VFM_CloudPhase(Index_Profile,2);%云相位特征
                if length(unique(VFM_CloudPhase_temp)) == 1
                    CloudPhase_CAL_COD(gridLat,gridLon,gridTime) = unique(VFM_CloudPhase_temp);
                elseif length(unique(VFM_CloudPhase_temp)) == 2 && sum(unique(VFM_CloudPhase_temp)==0)>=1 % 部分云填充，做云像元处理
                    CloudPhase_CAL_COD(gridLat,gridLon,gridTime) = max(unique(VFM_CloudPhase_temp));
                elseif length(unique(VFM_CloudPhase_temp)) > 2 % 多类型云，将像元简单定义为混合相态
                    CloudPhase_CAL_COD(gridLat,gridLon,gridTime) = 3;
                end               
            end  
        end
   

        %% 将数据保存
        if file_i == fileNum_CAL %假如到最后一个文件了就存储
            Time_Current = fileList_H8{fileH8_i,3}(1:8);
            Data_Result.Lon = H8_Lon;
            Data_Result.Lat = H8_Lat;
            Data_Result.Time = H8_Time_All;
            Data_Result.CloudTop_CAL_95P = CloudTop_CAL_95P; % 和H8数据一样的结构
            Data_Result.CloudTop_CAL_COD = CloudTop_CAL_COD; % 和H8数据一样的结构
            % Data_Result.CloudTop_CAL_COD_Corrected = CloudTop_CAL_COD_Corrected; % 和H8数据一样的结构
            Data_Result.CloudFraction_CAL = CloudFraction_CAL;
            Data_Result.CloudPhase_CAL = CloudPhase_CAL; % 和H8数据一样的结构
            Data_Result.CloudPhase_CAL_COD = CloudPhase_CAL_COD; % 和H8数据一样的结构
            % Data_Result.CloudPhase_CAL_COD_Corrected = CloudPhase_CAL_COD_Corrected;
            Data_Result.MultiFraction_CAL = MultiFraction_CAL;
            Data_Result.MultiFraction_CAL_COD = MultiFraction_CAL_COD; % 和H8数据一样的结构            
            % save(['/data/yangyin/liusiman/H8/Matched_P1_COD_before/MatchedVFM_CloudProperty_',Time_Current,'.mat'],'Data_Result','-v7.3');
            save(['/data62/yangying/H8_matched_P1/MatchedVFM_CloudProperty_',Time_Current,'.mat'],'Data_Result','-v7.3');
            Data_Result=[];
            
          %% 保存H8和CALIPSO的匹配数据Table——函数P2
%            Index = ~isnan(ClouTop_CAL);
%            H8_Lon2 = repmat(H8_Lon,1,1,length(H8_Time_All));
%            H8_Lat2 = repmat(H8_Lat,1,1,length(H8_Time_All));
%            MatchedTable = [H8_Lat2(Index),H8_Lon2(Index),H8_DayFlag_All(Index),H8_Cloud_All(Index),H8_FullCloud_All(Index),ClouTop_CAL(Index)];
%            clear H8_Lon2 H8_Lat2
%            MatchedTableVar = ['H8_Lat','H8_Lon','DayFlag','H8_CloudMask','FullCloudMask','CAL_CloudTop'];
%            Mated_CloudTable.Data = MatchedTable;
%            Mated_CloudTable.VarNames = MatchedTableVar;
%            save(['.\Result\Mated_CloudMaskTable_',Time_Current,'.mat'],'Mated_CloudTable','-v7.3');
%            clear Mated_CloudMaskTable           
        end
    end
end
