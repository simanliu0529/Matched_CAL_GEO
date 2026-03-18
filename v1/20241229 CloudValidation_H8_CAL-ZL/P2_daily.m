% ZL
% 读取的CALIPSO的VFM数据,用VFM生成一个和H8数据[881,1101,Ntimes]大小相同的中国区域的云熟悉分布数据集，并与H8匹配
clc; clear; close all;

%% 预设置
% 研究区域 中国73-135E，3-54N；云南：97-107，21-30%
Reg.LonMin = 80; %经度
Reg.LonMax = 170;
Reg.LatMin = -60; %纬度
Reg.LatMax = 60;
%% 读取数据——根据自己的数据存储位置修改路径
dirH8 = '/data/yangyin/liusiman/H8/'; %加载葵花数据
Outpath = '/data/yangyin/liusiman/H8/Matched_P2_COD2/';
fileList_H8_matched = Fun_filesTraversal([dirH8,'Matched_P1_COD2/'],'*.mat');
fileNum_H8 = size(fileList_H8_matched,1);
for fileH8_i = 1:fileNum_H8
     %% 加载匹配的VFM数据
    % Time_Current = fileList_H8{fileH8_i,3}(1:8);
    MatchedCAL = importdata(fileList_H8_matched{fileH8_i,1});
    % filePath = ['/data/yangyin/liusiman/H8/Matched_P1_uncorrected/MatchedVFM_CloudProperty_', Time_Current, '.mat'];
    H8_Year = fileList_H8_matched{fileH8_i,3}(end-11:end-8);
    H8_Month = fileList_H8_matched{fileH8_i,3}(end-7:end-6);
    H8_Day = fileList_H8_matched{fileH8_i,3}(end-5:end-4);
    Time_Current = [H8_Year,H8_Month,H8_Day];
    NameTimeStr = [H8_Year,H8_Month,H8_Day];
    % % 检查文件是否存在
    % if exist(filePath, 'file')
    %     MatchedCAL = importdata(filePath);
    % else
    %     disp(['文件不存在：', filePath, '，跳过!']);
    %     continue;
    % end
    CloudTop_CAL_95P = MatchedCAL.CloudTop_CAL_95P; % 和H8数据一样的结构
    CloudTop_CAL_COD = MatchedCAL.CloudTop_CAL_COD; % 和H8数据一样的结构
    CloudFraction_CAL = MatchedCAL.CloudFraction_CAL;
    CloudPhase_CAL = MatchedCAL.CloudPhase_CAL;
    CloudPhase_CAL_COD = MatchedCAL.CloudPhase_CAL_COD;
    MultiFraction_CAL = MatchedCAL.MultiFraction_CAL; % 和H8数据一样的结构
    MultiFraction_CAL_COD = MatchedCAL.MultiFraction_CAL_COD; % 和H8数据一样的结构

    % 加载H8的云掩膜，注意这里示例只是有云和无云的二值划分，可加载云相态替换云mask
    H8_Cloud_temp = importdata([dirH8,'CLM/',NameTimeStr,'_CloudMask','.mat']); 
    H8_Lon = H8_Cloud_temp.Lon;
    H8_Lat = H8_Cloud_temp.Lat;
    H8_Cloud_Time = H8_Cloud_temp.Time;
    H8_CloudMask = single(H8_Cloud_temp.Data); % 原始数据1表示晴空
    clear H8_Cloud_temp
    % H8_CloudMask(H8_CloudMask == 1) = 2;
    % H8_CloudMask(H8_CloudMask == 0) = 1;
    % H8_CloudMask(H8_CloudMask == 2) = 0; % 将1定义为云
    % 将数据还原为每天24小时观测，无观测时为NaN
    [H8_Cloud_All,H8_Time_All] = fun_H8Data2AllDay(H8_Cloud_Time,H8_CloudMask);

    %  %% 加载自己制作的云掩膜：*_NotCldy0_Cldy1_Mask，1表示为云
    %  H8_FullCloud_temp = importdata([dirH8,'FullTime_Cloud\',NameTimeStr,'_NotCldy0_Cldy1_Mask','.mat']);
    %  H8_FullCloud_Time = H8_FullCloud_temp.Time;
    %  H8_FullCloudMask = single(H8_FullCloud_temp.Data);
    %  clear H8_FullCloud_temp
    %     % 将数据还原为每天24小时观测，无观测时为NaN
    % [H8_FullCloud_All,~] = fun_H8Data2AllDay(H8_FullCloud_Time,H8_FullCloudMask);

    %% 加载H8的云相态产品
    H8_CLP_temp = importdata([dirH8,'CLP/',NameTimeStr,'_CloudPhase','.mat']);
    H8_CLP_Time = H8_CLP_temp.Time;
    H8_CloudPhase = single(H8_CLP_temp.Data);
    clear H8_CLP_temp
    % 将数据还原为每天24小时观测，无观测时为NaN
    [H8_CLP_All,~] = fun_H8Data2AllDay(H8_CLP_Time,H8_CloudPhase);

    %% 加载H8的云顶高产品，单位为km
    H8_CTH_temp = importdata([dirH8,'CTH/',NameTimeStr,'_CTH','.mat']);
    H8_CTH_Time = H8_CTH_temp.Time;
    H8_CloudTopHeight = single(H8_CTH_temp.Data);
    clear H8_CTH_temp
    % 将数据还原为每天24小时观测，无观测时为NaN
    [H8_CTH_All,~] = fun_H8Data2AllDay(H8_CTH_Time,H8_CloudTopHeight);

    %% 加载太阳天顶角SOZ：*_SOZ,并且SOZ>80°时，定义为夜间数据
    H8_SOZ_temp = importdata([dirH8,'SOZ/',NameTimeStr,'_SOZ','.mat']);
    H8_SOZ_Time = H8_SOZ_temp.Time;
    H8_DayFlag = single(H8_SOZ_temp.Data <= 80); % 1：白天，0：夜间
    clear H8_SOZ_temp
    % 将数据还原为每天24小时观测，无观测时为NaN
    [H8_DayFlag_All,~] = fun_H8Data2AllDay(H8_SOZ_Time,H8_DayFlag);

   

    %% 保存H8和CALIPSO的匹配数据Table
    % 根据需要保存数据，不一定非得全部匹配保存
    Index = ~isnan(CloudPhase_CAL); % CALIPSO沿轨匹配的数据
    H8_Lon2 = repmat(H8_Lon,1,1,length(H8_Time_All));
    H8_Lat2 = repmat(H8_Lat,1,1,length(H8_Time_All));
    MatchedTable = [H8_Lat2(Index),H8_Lon2(Index),H8_DayFlag_All(Index),...
        H8_Cloud_All(Index),H8_CLP_All(Index),H8_CTH_All(Index),... %H8_FullCloud_All(Index)
        CloudTop_CAL_95P(Index),CloudTop_CAL_COD(Index),...
        CloudFraction_CAL(Index),....
        CloudPhase_CAL(Index),CloudPhase_CAL_COD(Index),MultiFraction_CAL(Index),MultiFraction_CAL_COD(Index)];  % MultiFraction_CAL(Index),MultiFraction_CAL_COD(Index)

    DayIndex = MatchedTable(:,3) == 0| isnan(MatchedTable(:,3));
    MatchedTable(DayIndex,:) = NaN; % 将不确定白天夜晚的统计结果置为nan
     
    clear H8_Lon2 H8_Lat2 Index DayIndex
    MatchedTableVar = ['H8_Lat','H8_Lon','H8_DayFlag',...
        'H8_CloudMask','H8_CloudPhase','H8_CloudTopHeight',...
        'CAL_CloudTop_95P','CAL_CloudTop_COD',...
        'CAL_CloudFraction',...
        'CAL_CloudPhase','CAL_CloudPhase_COD','MultiFraction_CAL','MultiFraction_CAL_COD'];
    % Mated_CloudTable.Data = cat(1,Mated_CloudTable.Data,MatchedTable);
    Mated_CloudTable.Data = MatchedTable;
    Mated_CloudTable.VarNames = MatchedTableVar;
    save([Outpath,'Mated_CloudPropertyTable_',Time_Current,'.mat'],'Mated_CloudTable','-v7.3');
    clear Mated_CloudMaskTable
end
