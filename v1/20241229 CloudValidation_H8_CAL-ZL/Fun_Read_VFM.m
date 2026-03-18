function Out_VFM= Fun_Read_VFM...
    (filepath_VFM,validRange_VFM,type,start,edges,stride)
%%
% fillmethod
% 函数说明：三倍标准差以外直接去除
% Out_Data
% Out_Count
%%
parameter='Feature_Classification_Flags';
% start=[0 0];
% edges=[-9 -9];
if start==0
    start=[0,0];
end
if edges==0
    edges=[-9 -9];
end
if stride==0
    stride=[1 1];
end
%%
% [info, var]=readHDF(filepath_VFM,parameter);  %,start,edges,stride
[info, var]=readHDF(filepath_VFM,parameter,start,edges,stride);  %,start,edges,stride
VFM_CAL=var;
if any(validRange_VFM==0)
    VFM_CAL=VFM_CAL(validRange_VFM,:);
end
% type='all';
[block,TypeText] = vfm_row2block(VFM_CAL(1,:),type);
len_VFM=size(VFM_CAL,1);

for i =2:len_VFM
    block=cat(2,block,vfm_row2block(VFM_CAL(i,:),type));
    %在指定的维数方向上连接数组，这里是行
    %将所有block顺序行连接
end
block=block';

%%
% 545 各bin增加到 583 个bin，保持和LEVEL1数据一致
% start_extend=repmat(block(:,1),[1,33]);
% end_extend=repmat(block(:,end),[1,5]);
% block=[start_extend,block,end_extend];
%%
Out_VFM=block; % [NumofHorizontalPoints*15, NumofVerticalPoints_545]
