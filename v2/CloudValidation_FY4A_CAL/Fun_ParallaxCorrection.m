function [lat_new, lon_new,s] = Fun_ParallaxCorrection(lat, lon, Hc, flag)
    % 输入：
    % lat - 真云纬度 (度)
    % lon - 真云经度 (度)
    % Hc - 云顶高度 (千米)
    % flag - 卫星标记
    % 输出：
    % lat_new - 观测云纬度 (度)
    % lon_new - 观测云经度 (度)
    
    % 将输入的经纬度从度转换为弧度
    lat_s = 0; % 葵花8号卫星的视纬度
    if flag==1
        lon_s = 140.7; % 葵花8号卫星的视经度
    elseif flag==2
        lon_s = 104.7; % 风云4A卫星的视经度
    elseif flag==3
        lon_s = 133; % 风云4B卫星的视经度
    end
    Hc = Hc.*1000;
    lat=deg2rad(lat);
    lon=deg2rad(lon);
    lat_s=deg2rad(lat_s);
    lon_s=deg2rad(lon_s);
    Requator = 6378100; 
    Rpole = 6356600;
    Rob = Requator / Rpole;
    Rs = 42157000;
    Re = Requator ./ sqrt(cos(lat).^2 + (Rob.^2) * sin(lat).^2);
    Xa = (Re+Hc) .* cos(lat) .* sin(lon);
    Ya = (Re+Hc) .* sin(lat);
    Za = (Re+Hc) .* cos(lat) .* cos(lon);
    Xs = Rs .* cos(lat_s) .* sin(lon_s);
    Ys = Rs .* sin(lat_s);
    Zs = Rs .* cos(lat_s) .* cos(lon_s);
    B = (Requator / Rpole)^2;
    a = (Xs - Xa).^2 + (Zs - Za).^2 + B .* (Ys - Ya).^2;
    b = 2 * (Xs .* (Xa - Xs) + Zs .* (Za - Zs) + B .* Ys .* (Ya - Ys));
    c = Xs.^2 + Zs.^2 + B .* Ys.^2 - Requator.^2;
    A = (-b - sqrt(b.^2 - 4 .* a .* c)) ./ (2 .* a);
    
    Xc = Xs + A .* (Xa - Xs);
    Yc = Ys + A .* (Ya - Ys);
    Zc = Zs + A .* (Za - Zs);
    Xc = real(Xc); Yc = real(Yc); Zc = real(Zc);

    lat_new = atan2(Yc ,sqrt(Xc.^2 + Zc.^2));
    lon_new = atan2(Xc , Zc);
    % 计算大圆距离
    delta_sigma = acos(sin(lat) .* sin(lat_new) + cos(lat) .* cos(lat_new) .* cos(lon_new - lon));

    s = Re .* delta_sigma;
    s = real(s);
    lon_new=rad2deg(lon_new);
    lat_new=rad2deg(lat_new);
end

