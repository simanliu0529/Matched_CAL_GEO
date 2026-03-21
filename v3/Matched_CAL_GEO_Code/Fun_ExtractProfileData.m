function [ProfileData, ProfilePhase, CalRow0p2, CalRow1p0, dbg] = Fun_ExtractProfileData( ...
    VFM_Block_All, VFM_Block_Phase, ProfileIndices, Altitude, CAL_H_0p2, CAL_H_1p0)

ProfileIndices = double(ProfileIndices(:));
Nmatch = numel(ProfileIndices);

nRows = size(VFM_Block_All, 1);
nAlt  = size(VFM_Block_All, 2);

ProfileData  = ones(Nmatch, nAlt, 'like', VFM_Block_All);
ProfilePhase = zeros(Nmatch, nAlt, 'like', VFM_Block_Phase);

CalRow0p2 = nan(Nmatch,1);
CalRow1p0 = nan(Nmatch,1);

cutUpper = false;
if nargin >= 4 && ~isempty(Altitude)
    cutUpper = Altitude(1) > Altitude(end); % true: 高->低
end

dbg = struct('Nmatch',Nmatch,'nRows',nRows,'nAlt',nAlt,'cutUpper',cutUpper);

for i = 1:Nmatch
    r = ProfileIndices(i);
    if r < 1 || r > nRows, continue; end

    ProfileData(i,:)  = VFM_Block_All(r,:);
    ProfilePhase(i,:) = VFM_Block_Phase(r,:);

    if ~isempty(CAL_H_0p2) && size(CAL_H_0p2,2) >= r
        CalRow0p2(i) = CAL_H_0p2(2,r);
    end
    if ~isempty(CAL_H_1p0) && size(CAL_H_1p0,2) >= r
        CalRow1p0(i) = CAL_H_1p0(2,r);
    end

    % 可选：在提取阶段就把 <0.2 薄云清掉（建议清掉，后面判断“晴空90%”才一致）
    if ~isnan(CalRow0p2(i)) && CalRow0p2(i)>=1 && CalRow0p2(i)<=nAlt
        if cutUpper
            ProfileData(i, 1:CalRow0p2(i))  = 1;
            ProfilePhase(i,1:CalRow0p2(i))  = 0;
        else
            ProfileData(i, CalRow0p2(i):end) = 1;
            ProfilePhase(i,CalRow0p2(i):end) = 0;
        end
    end
end

% ProfileData = ProfileData';
% ProfilePhase = ProfilePhase';

end
