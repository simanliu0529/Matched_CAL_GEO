 % 将数据还原为每天24小时观测，无观测时为NaN
 function [H8_Cloud_All,H8_Time_All] = fun_H8Data2AllDay(H8_Cloud_Time,H8_CloudMask)
    H8_Cloud_Time_Vec = datevec(H8_Cloud_Time);
    H8_TimeNum = length(unique(H8_Cloud_Time_Vec(:,3)))*24;
    H8_Cloud_Time_Vec(H8_Cloud_Time_Vec == 0);
    H8_Cloud_Time_Vec_diff = [NaN;diff(H8_Cloud_Time_Vec(:,4))];
    [index_a] = find(~isnan(H8_Cloud_Time_Vec_diff) & H8_Cloud_Time_Vec_diff~=1 & H8_Cloud_Time_Vec_diff~=-23);           
    if nargin == 2
        H8_Cloud_All = single(H8_CloudMask);
    else
        H8_Cloud_All = NaN;
    end
    H8_Time_All = H8_Cloud_Time;
    i_Num1 = 0;        
    for gap_i = 1:length(index_a)
        i_Num2 = H8_Cloud_Time_Vec_diff(index_a(gap_i));
        if i_Num2 < 0
            i_Num2 = i_Num2+24;
        end
        if nargin == 2
            H8_Cloud_All = cat(3,H8_Cloud_All(:,:,1:index_a(gap_i)+i_Num1-1),nan(size(H8_CloudMask,1),size(H8_CloudMask,2),i_Num2-1));
            H8_Cloud_All = single(cat(3,H8_Cloud_All,H8_CloudMask(:,:,index_a(gap_i):end)));
        end
        H8_Time_All = [H8_Time_All(1:index_a(gap_i)+i_Num1-1); ...
               (H8_Cloud_Time(index_a(gap_i)-1) + (1:i_Num2-1)/24)'; ...
               H8_Cloud_Time(index_a(gap_i):end)];
        i_Num1 = i_Num1+i_Num2-1;
    end
    LastTimeDiff = 23-H8_Cloud_Time_Vec(end,4); % 判定最后一个时间是否为23点
    if LastTimeDiff ~= 0
       if nargin == 2 
            H8_Cloud_All = single(cat(3,H8_Cloud_All,nan(size(H8_CloudMask,1),size(H8_CloudMask,2),LastTimeDiff))); 
       end
       H8_Time_All = [H8_Time_All;H8_Cloud_Time(end)+(1:1:LastTimeDiff)'/24];
    end
    clear H8_Cloud_Time H8_CloudMask H8_Cloud_Time_Vec H8_Cloud_Time_Vec_diff index_a 
 end