% ZL
% 读取的CALIPSO的VFM数据,用VFM生成一个和FY4A数据[881,1101,Ntimes]大小相同的中国区域的云熟悉分布数据集，并与FY4A匹配
clc; clear; close all;

%% 预设置
% 研究区域 中国73-135E，3-54N；云南：97-107，21-30%
Reg.LonMin = 73; %经度
Reg.LonMax = 135;
Reg.LatMin = 3; %纬度
Reg.LatMax = 54;

%% 读取数据——根据自己的数据存储位置修改路径
dirFY4 = '/PublicData/FY4CloudProductData/FY4A/'; %加载葵花数据
dirMatch = '/PublicData/CAL_FY4_MatchData/FY4A/';
Outpath0 = '/PublicData/CAL_FY4_MatchData/FY4A/Matched_P2_CloudType/';
vers = {'AfterCorrection/','BeforeCorrection/'};
for i=1
    ver = vers{i};
    Outpath = [Outpath0,ver];
    if ~exist(Outpath,'dir'), mkdir(Outpath); end

    fileList_FY4_matched = Fun_filesTraversal([dirMatch,ver],'*.mat'); % 以读取FY4A的云掩膜
    fileNum_FY4 = size(fileList_FY4_matched,1);
    for fileFY4_i = 1:fileNum_FY4
    % for fileFY4_i = 1:254
        %% 加载匹配的VFM数据
        MatchedCAL = importdata(fileList_FY4_matched{fileFY4_i,1});%把某波段某月的mat文件读出来
        FY4_Year = fileList_FY4_matched{fileFY4_i,3}(end-11:end-8);
        FY4_Month = fileList_FY4_matched{fileFY4_i,3}(end-7:end-6);
        FY4_Day = fileList_FY4_matched{fileFY4_i,3}(end-5:end-4);
        Time_Current = [FY4_Year,FY4_Month,FY4_Day];
        NameTimeStr = [FY4_Year,FY4_Month,FY4_Day];
        disp(['Handling Time:',NameTimeStr,'......']);
        % % filePath = ['/data/yangyin/liusiman/FYData/FY_4A/Matched_P1_uncorrected_new/MatchedVFM_CloudProperty_', Time_Current, '.mat'];
        % % % 检查文件是否存在
        % % if exist(filePath, 'file')
        % %     MatchedCAL = importdata(filePath);
        % % else
        % %     disp(['文件不存在：', filePath, '，跳过!']);
        % %     continue;
        % % end
        % % CloudTop_CAL_95P = MatchedCAL.CloudTop_CAL_95P; % 和FY4A数据一样的结构
        % % CloudTop_CAL_COD = MatchedCAL.CloudTop_CAL_COD; % 和FY4A数据一样的结构
        % % CloudFraction_CAL = MatchedCAL.CloudFraction_CAL;
        % % CloudFraction_CAL_COD = MatchedCAL.CloudFraction_CAL_COD;
        CloudPhase_CAL = MatchedCAL.CloudPhase_CAL;
        % % CloudPhase_CAL_COD = MatchedCAL.CloudPhase_CAL_COD;
        % % MultiFraction_CAL = MatchedCAL.MultiFraction_CAL; % 和FY4A数据一样的结构
        % % MultiFraction_CAL_COD = MatchedCAL.MultiFraction_CAL_COD; % 和FY4A数据一样的结构
        % 
        % 
        % % 加载FY4A的云掩膜，注意这里示例只是有云和无云的二值划分，可加载云相态替换云mask
        % FY4_Cloud_temp = importdata([dirFY4,'CLM/',NameTimeStr,'_CloudMask','.mat']);%把某波段某月的mat文件读出来
        LatLon = importdata('/PublicData/CAL_FY4_MatchData/FY4A/China_FY4A_LatLon.mat');
        FY4_Lon = LatLon.Lon;
        FY4_Lat = LatLon.Lat;
        % 
        % FY4_Cloud_Time = FY4_Cloud_temp.Time;
        % FY4_CloudMask = single(FY4_Cloud_temp.Data); % 原始数据3表示晴空
        % clear FY4_Cloud_temp
        % % FY4_CloudMask(FY4_CloudMask == 1) = 2;
        % % FY4_CloudMask(FY4_CloudMask == 0) = 1;
        % % FY4_CloudMask(FY4_CloudMask == 2) = 0; % 将1定义为云
        % % 将数据还原为每天24小时观测，无观测时为NaN
        % [FY4_Cloud_All,FY4_Time_All] = fun_FY4AData2AllDay(FY4_Cloud_Time,FY4_CloudMask);
        % 
        % %% 加载FY4A的云相态产品
        % FY4_CLP_temp = importdata([dirFY4,'CLP/',NameTimeStr,'_CloudPhase','.mat']);
        % FY4_CLP_Time = FY4_CLP_temp.Time;
        % FY4_CloudPhase = single(FY4_CLP_temp.Data);
        % clear FY4_CLP_temp
        % % 将数据还原为每天24小时观测，无观测时为NaN
        % [FY4_CLP_All,~] = fun_FY4AData2AllDay(FY4_CLP_Time,FY4_CloudPhase);
        % 
        % %% 加载FY4A的云顶高产品，单位为km
        % FY4_CTH_temp = importdata([dirFY4,'CTH/',NameTimeStr,'_CloudTopHeight','.mat']);
        % FY4_CTH_Time = FY4_CTH_temp.Time;
        % FY4_CloudTopHeight = single(FY4_CTH_temp.Data);
        % clear FY4_CTH_temp
        % % 将数据还原为每天24小时观测，无观测时为NaN
        % [FY4_CTH_All,~] = fun_FY4AData2AllDay(FY4_CTH_Time,FY4_CloudTopHeight);


        %% 加载地表类型
        CLT = importdata([dirFY4,'CLT/',NameTimeStr,'_CloudType','.mat']);
        FY4A_CloudType = single(CLT.Data); % 和H8数据一样的结构
        FY4A_CLT_Time = CLT.Time;
        % [lat_size, lon_size] = size(landtype);  % 获取纬度和经度的大小
        % landtype_3D = repmat(landtype, [1, 1, 24]);
        clear CLT
        [FY4A_CLT_All,~] = fun_FY4AData2AllDay(FY4A_CLT_Time,FY4A_CloudType);

        %% 加载太阳天顶角SOZ：*_SOZ,并且SOZ>80°时，定义为夜间数据
        FY4_SOZ_temp = importdata([dirFY4,'FY4A_SOZ/',NameTimeStr,'_SOZ','.mat']);
        FY4_SOZ_Time = FY4_SOZ_temp.Time;
        FY4_SOZ = single(FY4_SOZ_temp.Data);
        % FY4_DayFlag = single(FY4_SOZ_temp.Data <= 70); % 1：白天，0：夜间
        % clear FY4_SOZ_temp
        % 将数据还原为每天24小时观测，无观测时为NaN
        [FY4_SOZ_All,~] = fun_FY4AData2AllDay(FY4_SOZ_Time,FY4_SOZ);

        %% 保存FY4A和CALIPSO的匹配数据Table
        % 根据需要保存数据，不一定非得全部匹配保存
        Index = ~isnan(CloudPhase_CAL); % CALIPSO沿轨匹配的数据
        FY4_Lon2 = repmat(FY4_Lon,1,1,24);
        FY4_Lat2 = repmat(FY4_Lat,1,1,24);
        MatchedTable = [FY4_Lat2(Index),FY4_Lon2(Index),FY4_SOZ_All(Index),...
            FY4A_CLT_All(Index)];

        DayIndex = isnan(MatchedTable(:,1));
        MatchedTable(DayIndex,:) = NaN; % 将no China的统计结果置为nan

        clear FY4_Lon2 FY4_Lat2 Index DayIndex
        MatchedTableVar = ['FY4A_Lat','FY4A_Lon','FY4A_SOZ',...
            'FY4A_CLT_All'];
        Mated_CloudTable.Data = MatchedTable;
        Mated_CloudTable.VarNames = MatchedTableVar;
        save([Outpath,'Mated_CloudTypeTable_',Time_Current,'.mat'],'Mated_CloudTable','-v7.3');
        clear Mated_CloudTable
    end
end