function [Out_CloudPhase,Out_CloudFration,Out_CloudTop,Out_MultiLayerF] = Fun_VFM_CloudPhaseCloudTop_HorizonRes...
    (In_Data,In_Intervel,Start_Index,Dim_Index,In_Type,Altitude,CAL_H)
%%
% In_Data：
% Dim_Index: 1 代表row；2代表column
% VFM转换为5 km输出
% 15 根廓线中，只要存在云，就全部认为是云
% 云之外，15 根廓线中，只要存在气溶胶，就全部认为是气溶胶
% In_Intervel==15
% 2025.11.10 修改了多层云标识的判别方式，0--单层云 1--多层水云 2--多层冰云 3--真正的多层云（上冰下水或者上水下冰）
% 2025.11.11 增加了云分数的有COD约束的判断

%%
In_Data = single(In_Data);
if Dim_Index == 1
    Internal_Data = In_Data(Start_Index:end,:);
elseif Dim_Index==2
    Internal_Data = In_Data(:,Start_Index:end);
    Internal_Data = Internal_Data';
end
[len_pro,len_bin] = size(Internal_Data);
Intervel_5km = In_Intervel;
if iscell(Altitude)
    Altitude = cell2mat(Altitude);
end
%%
if length(In_Intervel)==1 % 等间隔
    if strcmp(In_Type,'phase') %{'Unknown/Not Determined','Ice','Water','HO'}
        len_pro_mean = ceil(len_pro/Intervel_5km);
        Out_Counter_Temp = single(zeros(len_pro_mean,1));
        Out_CloudPhase = single(zeros(len_pro_mean,2)); % 第一列保存无筛选数据，第二列保存COD约束的数据
        template = 0;                    % 每个cell存放一个标量（长度为1），保持一致性
        Out_MultiLayerF = repmat({template}, len_pro_mean, 2);

        for i=1:len_pro_mean
            if sum(Out_Counter_Temp)+Intervel_5km <= len_pro
                Temp_Num = Intervel_5km;
                Temp_Data = Internal_Data(1+(i-1)*Temp_Num:i*Temp_Num,:);
            else
                Temp_Num = len_pro-sum(Out_Counter_Temp);
                Temp_Data = Internal_Data(sum(Out_Counter_Temp):end,:);
            end
            Out_Counter_Temp(i,1) = Temp_Num;
            WaterCloud_Mask = (Temp_Data==2);
            IceCloud_Mask = (Temp_Data==1 | Temp_Data==3); % 5km范围内云的相态简单定义

            if sum(sum(WaterCloud_Mask))>0 && sum(sum(IceCloud_Mask))>0
                Out_CloudPhase(i,1) = 3; % 混合相态云
            elseif sum(sum(WaterCloud_Mask))== 0 && sum(sum(IceCloud_Mask))> 0
                Out_CloudPhase(i,1) = 2; % 冰云
            elseif sum(sum(WaterCloud_Mask))> 0 && sum(sum(IceCloud_Mask))== 0
                Out_CloudPhase(i,1) = 1; % 水云
            elseif sum(sum(WaterCloud_Mask))== 0 && sum(sum(IceCloud_Mask))==0
                Out_CloudPhase(i,1) = 0; % 晴空
            end

            %% ==== 多层云识别（考虑相态差异）====
            CloudIndex = Temp_Data==1 | Temp_Data==2 | Temp_Data==3;
            Temp_Altitude = repmat(Altitude',size(Temp_Data,1),1);
            minDH = 0.1; % 云层间距阈值（100m）
            CloudIndex2 = CloudIndex';
            [IsMultiLayer1] = Fun_MultiLayer_FromCloudIndex_LSM(CloudIndex2, Altitude, minDH,[], Temp_Altitude, IceCloud_Mask, WaterCloud_Mask);
            Out_MultiLayerF{i,1} = IsMultiLayer1;

            if ~isempty(CAL_H)
                % 增加COD约束
                [WaterCloud_Mask] = Fun_RefineMatrix_TargetH(WaterCloud_Mask,CAL_H(1,i));
                [IceCloud_Mask] = Fun_RefineMatrix_TargetH(IceCloud_Mask,CAL_H(1,i));
                if sum(sum(WaterCloud_Mask))>0 && sum(sum(IceCloud_Mask))>0
                    Out_CloudPhase(i,2) = 3; % 混合相态云
                elseif sum(sum(WaterCloud_Mask))== 0 && sum(sum(IceCloud_Mask))> 0
                    Out_CloudPhase(i,2) = 2; % 冰云
                elseif sum(sum(WaterCloud_Mask))> 0 && sum(sum(IceCloud_Mask))== 0
                    Out_CloudPhase(i,2) = 1; % 水云
                elseif sum(sum(WaterCloud_Mask))== 0 && sum(sum(IceCloud_Mask))==0
                    Out_CloudPhase(i,2) = 0; % 晴空
                end
                % 对多层云标识增加COD约束
                [IsMultiLayer2] = Fun_MultiLayer_FromCloudIndex_LSM(CloudIndex2, Altitude, minDH, CAL_H(1,i), Temp_Altitude, IceCloud_Mask, WaterCloud_Mask);
                Out_MultiLayerF{i,2} = IsMultiLayer2;
            end

            % if ~isempty(CAL_H)
            %     [IsMultiLayer2] = Fun_MultiLayer_FromCloudIndex_LSM(CloudIndex2, Altitude, minDH, CAL_H(1,i), Temp_Altitude, IceCloud_Mask, WaterCloud_Mask);
            %     Out_MultiLayerF{i,2} = IsMultiLayer2;
            % end
        end
        Out_CloudFration = [];
        Out_CloudTop = [];
        % Out_MultiLayerF = [];
    end

    %%
    if strcmp(In_Type,'all') %{'Unknown/Not Determined','Ice','Water','HO'}
        len_pro_mean = ceil(len_pro/Intervel_5km);
        Out_Counter_Temp = single(zeros(len_pro_mean,1));
        Out_CloudFration = cell(len_pro_mean,3);
        Out_CloudTop = nan(len_pro_mean,4);
        % template = [0, 0];
        % Out_MultiLayerF = repmat({template},len_pro_mean,2);
        %%
        for i=1:len_pro_mean
            if sum(Out_Counter_Temp)+Intervel_5km <= len_pro
                Temp_Num = Intervel_5km;
                Temp_Data = Internal_Data(1+(i-1)*Temp_Num:i*Temp_Num,:);
            else
                Temp_Num = len_pro-sum(Out_Counter_Temp);
                Temp_Data = Internal_Data(sum(Out_Counter_Temp):end,:);
            end

            %统计地表以上每一高度层的云分数占比
            % bits 1-3 Feature Type
            % 0 = invalid (bad or missing data)
            % 1 = "clear air"
            % 2 = cloud
            % 3 = aerosol
            % 4 = stratospheric feature
            % 5 = surface
            % 6 = subsurface
            % 7 = no signal (totally attenuated)
            CloudIndex = Temp_Data==2;
            Temp_Data_Fraction = sum(CloudIndex,1)./sum(~(Temp_Data==5|Temp_Data==6|Temp_Data==7),1);
            %             {'Invalid','Clear Air','Cloud','Aerosol','Strat Feature','Surface','Subsurface','No Signal'}
            Out_CloudFration{i,1} = Temp_Data_Fraction';
            Temp_TotalValid = sum(~(Temp_Data==5|Temp_Data==6|Temp_Data==7),1);
            Out_CloudFration{i,2} = Temp_TotalValid';
            % 增加有COD约束的云分数判断
            if ~isempty(CAL_H)
                if len_pro_mean == length(CAL_H)
                    [CloudIndex_a] = Fun_RefineMatrix_TargetH(CloudIndex',CAL_H(1,i));
                    Temp_Data2 = Temp_Data';
                    Temp_Data_Fraction_COD = sum(CloudIndex_a,2)./sum(~(Temp_Data2==5|Temp_Data2==6|Temp_Data2==7),2);
                    Out_CloudFration{i,3} = Temp_Data_Fraction_COD;
                end
            end

            % 统计云顶高
            Temp_CloudTop = nan(size(Temp_Data,1),1);
            Temp_Altitude = repmat(Altitude',size(Temp_Data,1),1);
            [row, col] = find(CloudIndex == 1);
            [~, uniqueRowIdx] = unique(row, 'first');
            firstColIdx = col(uniqueRowIdx);
            Temp_CloudTop(row(uniqueRowIdx)) = Temp_Altitude(sub2ind(size(Temp_Altitude), row(uniqueRowIdx), firstColIdx));
            Out_CloudTop(i,1) = prctile(Temp_CloudTop, 100);%取最大值
            Out_CloudTop(i,2) = prctile(Temp_CloudTop, 95);%取上5%分位数
            Out_CloudTop(i,3) = nanmean(Temp_CloudTop);%取平均值
            if ~isempty(CAL_H)
                if len_pro_mean == length(CAL_H)
                    Out_CloudTop(i,4) = CAL_H(1,i); % 取COD近似为0.02处的云顶高
                end
            end

            % %% 输出多层云分数，当多层云分数大于0时，则为多层云；等于0时，则为单层云
            % minDH = 0.1; % 云层之间的间隔差大于100m,才被判定为多层云
            % CloudIndex2 = CloudIndex';
            % Temp_MultiLayerF = Fun_Calculate_Layers(CloudIndex2,Altitude,minDH);
            % Out_MultiLayerF{i,1} = Temp_MultiLayerF;
            % if ~isempty(CAL_H)
            %     % 增加COD约束
            %     [CloudIndex2] = Fun_RefineMatrix_TargetH(CloudIndex2,CAL_H(1,i));
            %     Temp_MultiLayerF = Fun_Calculate_Layers(CloudIndex2,Altitude,minDH);
            %     Out_MultiLayerF{i,2} = Temp_MultiLayerF;
            % end

            % %% ==== 多层云识别（考虑相态差异）====
            % minDH = 0.1; % 云层间距阈值（100m）
            % CloudIndex2 = CloudIndex';
            % [IsMultiLayer1] = Fun_MultiLayer_FromCloudIndex_LSM(CloudIndex2, Altitude, minDH,[], Temp_Altitude, IceCloud_Mask, WaterCloud_Mask);
            % Out_MultiLayerF{i,1} = IsMultiLayer1;
            % if ~isempty(CAL_H)
            %     [IsMultiLayer2] = Fun_MultiLayer_FromCloudIndex_LSM(CloudIndex2, Altitude, minDH, CAL_H(1,i), Temp_Altitude, IceCloud_Mask, WaterCloud_Mask);
            %     Out_MultiLayerF{i,2} = IsMultiLayer2;
            % end
        end

        Out_CloudPhase = [];
        Out_MultiLayerF = [];
    end
end
