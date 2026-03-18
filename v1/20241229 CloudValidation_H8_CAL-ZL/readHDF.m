function [info var]=readHDF(filename,parameter,start,edges,stride)
% Function readHDF
% 此函数经过修改适合MATLAB R2018b高版本hdf数据的读取（zmd）。
% Uses the low-level hdf (hdfsd) routines to read data from a hdf data file.
% Inputs:
% filename (string)  - The name of the file to read. The entire path should be supplied
%                      unless the file is in the current working directory.
% parameter(string ) - This is the name of the SDS that you want to read in.
%
% Optional inputs:
%
% start  (vector)    - This contains the staring index to begin reading for each
%                      dimension (e.g. [0 0] for the beginning of the file).
% edges (vector)     - The number of elements to read in for each dimension. If any of the
%                      values for edges is -9 it will read in all the values for that
%                      dimension.
% stride (vector)    - The number of elements to skip for each dimension. 

%
% Example:
% To read in the first 100x583 elements from an sds do the following,
% >[info data] = readHDF('/Users/JoeUser/Data/MY_HDF_FILENAME.hdf,'MY_SDS_NAME_HERE',[0 0],[100 583]);
%% 预处理
if exist('start')
start_1 = fliplr(start);
end
if exist('edges')
edges_1 = fliplr(edges);
end
if exist('stride')
stride_1 = fliplr(stride);
end




info.stat = 0;
var = '';

if nargin ~= 2 & nargin ~=4 & nargin ~=5,
    error('Either 2 or 4 inputs are required');
end

if  (~exist(filename,'file'))
    error('The file %s does not exist!',filename);
    return;
end

try
%     import matlab.io.hdfeos.*
    import matlab.io.hdf4.*
%     sd_id = hdfsd('start',filename,'DFACC_RDONLY'); % matlab.io.hdfeos.sd %
    sdID = sd.start(filename,'DFACC_RDONLY');
    [ndatasets,ngatts] = sd.fileInfo(sdID);
%         [ndatasets, nglobal_atts, stat] = hdfsd('fileinfo',sd_id);
    if ndatasets == 0,
        info.stat = -2;
        var = '';
        fprintf('Error: No data sets were found in the file:\n%s\n',filename);
        hdfml('closeall');
        return;
    end
catch
    hdfml('closeall');
    error('The file %s could not be opened.',filename);
end


try
    % Find the sds in the file
    iSDS = -1;
    iSDS = sd.nameToIndex(sdID,parameter);
    %     iSDS = hdfsd('nametoindex',sd_id,parameter);
    if iSDS == -1,
        info.stat = -3;
        var = '';
        fprintf('The dataset(%s) in file could not be found:\n%s\n',parameter,filename);
        stat = sd.endAccess(sdID);
%         stat = hdfsd('end',sd_id);
        return;
    end
    sdsID = sd.select(sdID,iSDS);
    %     sds_id = hdfsd('select',sd_id,iSDS);
    [name,dims,datatype,nattrs] = sd.getInfo(sdsID);
    ds_name = name;
    ds_ndims = length(dims);   % 总维数
%     ds_dims = fliplr(dims);    % 各维数的长度///////////
    ds_dims = dims;    % 各维数的长度///////////
    ds_type = datatype;
    ds_atts = nattrs;
%     [ds_name, ds_ndims, ds_dims, ds_type, ds_atts, stat] = hdfsd('getinfo',sds_id);

    
    %    for i=1:ndatasets,
    %        sds_id = hdfsd('select',sd_id,i);
    %        [ds_name, ds_ndims, ds_dims, ds_type, ds_atts, stat] = hdfsd('getinfo',sds_id);
    %        if (stat ~=0)
    %            info.stat = stat;
    %            var = '';
    %            fprintf('Error: An error was encountered while trying to getinfo from`the sds (%d)\n in the file %s.\n',sds_id,filename);
    %            hdfml('closeall');
    %            return;
    %        end
    %        if strcmp(ds_name, parameter),
    %            iSDS = i;
    %            break;
    %        end;
    %        stat = hdfsd('endaccess',sds_id);
    %    end
    %    if iSDS == -1,
    %	info.stat = -3;
    %        var = '';
    %        fprintf('The dataset(%s) in file could not be found:\n%s\n',parameter,filename);
    %        hdfml('closeall');
    %	return;
    %    end
catch
    hdfml('closeall');
    error('An error was encountered while trying to read and select a dataset\nfrom file %s',filename);
end

% Determine the size of the SDS
info.nElements = max(ds_dims);

if nargin ==2,
    ds_start = zeros(1,ds_ndims); % Creates the vector [0 0]
    ds_stride = [];
    ds_edges = ds_dims;
elseif nargin >= 4,
    if ~exist('stride')
        ds_stride = [];
        stride_1 = ones(size(start_1));
    end
    
    if length(start_1) ~= ds_ndims,
        start_1
        ds_ndims
        error('The number of start indices are incorrect');
    end
    
    if length(edges_1) ~= ds_ndims,
        edges_1
        ds_ndims
        error('The number of end indices are incorrect');
    end
    
    for i=1:ds_ndims,
        if start_1(i) > ds_dims(i)
            fprintf('start(%d)=%d > %d\n',i,start_1(i),ds_dims(i))
            error('The start index exceeds the number of elements in the dimension. ');
        end
        % This is a special case that will read to the end of the file
        if (edges_1(i) == -9)
            edges_1(i)  = floor((ds_dims(i) - start_1(i))/stride_1(i));
        end
        %[start(i) edges(i) stride(i)]
        foo2 = (start_1(i)+edges_1(i))/stride_1(i);
        if foo2 > ds_dims(i)
            fprintf('(start(%d) + edges(%d) )=%d > %d\n',i,i,start_1(i)+edges_1(i),ds_dims(i))
            error('The number of elements to read exceeds the number of elements in the dimension.');
        end
    end
    
    ds_start = start_1;
    ds_stride = stride_1;
    ds_edges = edges_1;
else
    error('Wrong number of arguments');  % Should never happen
end

% Save the sds information
info.ds_name = ds_name;
info.ds_ndims = ds_ndims;
info.ds_dims = ds_dims;
info.ds_type = ds_type;
info.ds_attr = ds_atts;
info.ds_start = ds_start;
info.ds_edges = ds_edges;
info.ds_stride = ds_stride;

% Read the data
% import matlab.io.hdf4.*
var = sd.readData(sdsID,ds_start,ds_edges);
% var = sd.readData(sdsID);
% ,ds_start,ds_edges,ds_stride
% [var, stat] = hdfsd('readdata',sdsID,ds_start,ds_stride,ds_edges);


% Reverse the data rows->columns, this now how hdfread would present it.
% This is only for backward compatibility witht the previous version of readHDF
if info.ds_ndims == 2,
    var = var';
end

% ***** get SDS attribute info, shamelessly copied from hdfsdsinfo.m
info2 = hdf_sdsinfo(info,sdsID);
if isfield(info2,'Attributes')
    info.Attr = info2.Attributes;
end
info.Type = info2.Type;
info.Dims = info2.Dims;

% Close access to the file
sd.endAccess(sdsID);
sd.close(sdID);
% stat = hdfsd('endaccess',sds_id);
% stat = hdfsd('end',sd_id);


function sdinfo = hdf_sdsinfo(info,sdsID)

%Get lots of info
%[sdsName, rank, dimSizes, sddataType, nattrs, status] = hdfsd('getinfo',sdsID);
sdsName = info.ds_name;
rank    = info.ds_ndims;
dimSizes= info.ds_dims;
sddataType = info.ds_type;
nattrs  = info.ds_attr;

%hdfwarn(status)

%Get SD attribute information. The index for readattr is zero based.
if nattrs>0
  arrayAttribute = repmat(struct('Name', '', 'Value', []), [1 nattrs]);
  for i = 1:nattrs
    import matlab.io.hdf4.*
    [arrayAttribute(i).Name,attrDataType,nelts] = sd.attrInfo(sdsID,i-1);
%     [arrayAttribute(i).Name,attrDataType,count,status] = hdfsd('attrinfo',sdsID,i-1);
%     hdfwarn(status)
    arrayAttribute(i).Value = sd.readAttr(sdsID,i-1);
%     [arrayAttribute(i).Value, status] = hdfsd('readattr',sdsID,i-1);
%     hdfwarn(status)
  end
else
  arrayAttribute = [];
end

IsScale = sd.isCoordVar(sdsID);
% IsScale = logical(hdfsd('iscoordvar',sdsID));

%If it is not a dimension scale, get dimension information
%Dimension numbers are 0 based (?)
if IsScale == 0
  
  Scale = cell(1, rank);
  dimName = cell(1, rank);
  DataType = cell(1, rank);
  Size = cell(1, rank);
  Name = cell(1, rank);
  Value = cell(1, rank);
  Attributes = cell(1, rank);
  
  for i=1:rank
    dimID = sd.getDimID(sdsID,i-1);
%     dimID = hdfsd('getdimid',sdsID,i-1);
    %Use sizes from SDgetinfo because this size may be Inf
    [dimName{i},sizeDim,DataType{i},nattrs] = sd.dimInfo(dimID);
%     [dimName{i}, sizeDim,DataType{i}, nattrs, status] = hdfsd('diminfo',dimID);
%     hdfwarn(status)
    if strcmp(DataType{i},'none')
      Scale{i} = 'none';
    elseif isinf(sizeDim)
      Scale{i} = 'unknown';
    else
      try
        Scale{i} = getDimScale(dimID);
%         Scale{i} = hdfsd('getdimscale',dimID);
      catch
        Scale{i} = 'none';
      end
    end
    Size{i} = dimSizes(i);
    if nattrs>0
      for j=1:nattrs
          [Name{j},dataType,count] = sd.attrInfo(sdID,idx);
% 	[Name{j},dataType,count,status] = hdfsd('attrinfo',dimID,j-1);
	hdfwarn(status)
    Value{j} = sd.readAttr(dimID,j-1);
% 	[Value{j}, status] = hdfsd('readattr',dimID,j-1);
	hdfwarn(status)
      end
      Attributes{i} = struct('Name',Name(:),'Value',Value(:));
    else
      Attributes = [];
    end
  end
  dims = struct('Name',dimName(:),'DataType',DataType(:),'Size',Size(:),'Scale',Scale(:),'Attributes',Attributes(:));
else
  dims = [];
end

%Get any associated annotations
% tag = hdfml('tagnum','DFTAG_NDG');
% if anID ~= -1
%   [label,desc] = hdfannotationinfo(anID,tag,ref);
%   if isempty(label) || isempty(desc)
%     tag = hdfml('tagnum','DFTAG_SD');
%     [label,desc] = hdfannotationinfo(anID,tag,ref);
%   end
% end

% %Close interfaces
% status = hdfsd('endaccess',sdsID);
% hdfwarn(status)

%Populate output structure
% sdinfo.Name = sdsName;
% sdinfo.Index = index;
% sdinfo.Rank = rank;
% sdinfo.DataType = sddataType;
if ~isempty(arrayAttribute)
  sdinfo.Attributes = arrayAttribute;
end
if ~isempty(dims)
  sdinfo.Dims = dims;
end
%sdinfo.Label = label;
%dinfo.Description = desc;
%sdinfo.IsScale = IsScale;
sdinfo.Type = 'Scientific Data Set';


function hdfwarn(status)
%Use the last error generated by the HDF library as a warning.

%   Copyright 1984-2006 The MathWorks, Inc.
%   $Revision: 1.1.6.4 $  $Date: 2006/03/13 19:46:43 $

if status==-1
  error_code = hdfhe('value',1);
  if strncmpi(hdfhe('string',error_code),'no error',8)
    msg = sprintf('The NCSA HDF library reported an unknown error.');
  else
    msg = sprintf('The NCSA HDF library reported the following error: \n%s', ...
                  hdfhe('string',error_code));
  end
  warning('MATLAB:hdfwarn:generic', '%s', msg)
end