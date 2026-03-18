function [block,TypeText] = vfm_row2block(vfm_row,type)
% Description: Rearanges a vfm row to a 2d grid
% 将一个5515元素VFM重新排列转化为545*15二维矩阵，以用于伪彩色图
% Inputs: vfm_row - an array 1x5515, type - a string (see vfm_type for details)
%         一个1x5515数组
% Outputs: block - 2d array of vfm data, see function vfm_altitude for
%          altitude array information. Altitude array is in similar format as
%          CALIPSO L1 profile data (i.e. it isn't uniform).
%          TypeText - a string (see vfm_type for details)
%          二维vfm数据数组，看函数vfm_altitude可得到海拔数组信息。海拔数组与
%          CALIPSO L1廓线数据形式相同
% Notes: 
% -Uses vfm_type
% -Return type is uint8
% -This low altitude data (< 8km) is stored as 15 profiles 30m vertical by 333m horizontal
% -This corresponds to an array 290x15 packed in a 1d-array 4350 elements long;
%  这相当于装在一维数组中4350元素长的290x15数组;
% ------------------------------------------------------------------------------
% $Log: vfm_row2block.m,v $
% Revision 1.1  2005/03/24 21:10:45  kuehn
% First submission under new directory
%
% ------------------------------------------------------------------------------

className = 'uint8';   %定义8位二进制数

% Get typed array;
if strcmp(type,'AllNew');
    % Combine feature type with ice water
    [AtypedA,TypeText] = vfm_type(vfm_row,'all');
    [AtypedP,TypeText] = vfm_type(vfm_row,'phase');
    [Atyped,TypeText] = mergeIt(AtypedA,AtypedP);
else
    [Atyped,TypeText] = vfm_type(vfm_row,type); %执行
end

%block = ones(290,15,className)*intmax(className);
% For higher altitude data, info will be over-sampled in horizontal dimension
% for 8-20km block it will be 200x15 = 3000 rather than 200x5 = 1000
% for 20-30 km block it will be 55x15 = 825, rather than 55x3 = 165
% 对于更高海拔的数据，信息在水平维度上会被过度采样
% 对于8-20km块，其是200x15 = 3000，而不是200x5 = 1000
% 对于20-30km块，其是55x15 = 825，而不是55x3 = 165
block = ones(55+200+290,15,className)*10; %定义块，每5515扩充
offset = 1;  %抵消数
step = 55;   %步长
indA = 1;    %块中位置
indB = 55; 
for i =1:3,   %20.2-30.1km，每5km，3条廓线
    iLow = offset+step*(i-1);
    iHi = iLow+step-1;
    n = (i-1)*5;
    for k=1:5,           %一根廓线扩充为5根
     block(indA:indB,n+k) = Atyped(iLow:iHi);
    end
end

offset = 165+1;   %抵消数
step = 200;       %步长
indA = 55+1;      %块中位置
indB = 55+200; 
for i =1:5,       %8.2-20.2km，每5km，5条廓线
    iLow = offset+step*(i-1);
    iHi = iLow+step-1;
    n = (i-1)*3;
    for k=1:3,          %一根廓线扩充为3根
     block(indA:indB,n+k) = Atyped(iLow:iHi);
    end
end
% element 1,1 correspond to Alt -0.5km, position -2.5 km from center lat lon.
offset = 1165+1;
step = 290;
indA = 55+200+1; 
indB = 55+200+290; 
for i =1:15,        %-0.5-8.2km，每5km，15条廓线
    iLow = offset+step*(i-1);
    iHi = iLow+step-1;
    block(indA:indB,i) = Atyped(iLow:iHi);
end

function [Atyped,TypeText] = mergeIt(AtypedA,AtypedP)
% 此函数不明其意

TypeText = struct('FieldDescription',{'Feature Type'},...
   'ByteTxt',{{'Invalid','Clear Air','Ice Cloud','Water Cloud', 'Aerosol','Strat Feature',...
   'Surface','Subsurface','No Signal'}});

temp  = uint16(AtypedA >= 3);
Atyped = AtypedA + temp;

temp = uint16(AtypedP >= 2);
Atyped = Atyped + temp;
