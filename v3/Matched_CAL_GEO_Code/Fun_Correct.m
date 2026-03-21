function [thetaC, phiC,s] = Fun_Correct(thetaA, phiA, thetaS, phiS, Hc)
% 此函数为视差矫正的第一种方法
    % 输入：
    % thetaA - 真云纬度 (度)
    % phiA - 真云经度 (度)
    % thetaS - 卫星纬度 (度，通常为0)
    % phiS - 卫星经度 (度)
    % Rs - 卫星到地心的距离 (米)
    % Hc - 云顶高度 (千米)
    % L - 卫星到观测云的距离
    % 输出：
    % thetaC - 观测云纬度 (度)
    % phiC - 观测云经度 (度)
    % s - 观测云和真云之间的位置偏差
    % 将输入的经纬度从度转换为弧度
    Hc = Hc.*1000;
    thetaA=deg2rad(thetaA);
    phiA=deg2rad(phiA);
    thetaS=deg2rad(thetaS);
    phiS=deg2rad(phiS);
    Requator = 6378100; 
    Rpole = 6356600;
    Rob = Requator / Rpole;
    Rs = 42157000;
    Re = Requator ./ sqrt(cos(thetaA).^2 + (Rob.^2) * sin(thetaA).^2);
    Xa = (Re+Hc) .* cos(thetaA) .* sin(phiA);
    Ya = (Re+Hc) .* sin(thetaA);
    Za = (Re+Hc) .* cos(thetaA) .* cos(phiA);
    Xs = Rs .* cos(thetaS) .* sin(phiS);
    Ys = Rs .* sin(thetaS);
    Zs = Rs .* cos(thetaS) .* cos(phiS);
    B = (Requator / Rpole)^2;
    a = (Xs - Xa).^2 + (Zs - Za).^2 + B .* (Ys - Ya).^2;
    b = 2 * (Xs .* (Xa - Xs) + Zs .* (Za - Zs) + B .* Ys .* (Ya - Ys));
    c = Xs.^2 + Zs.^2 + B .* Ys.^2 - Requator.^2;
    A = (-b - sqrt(b.^2 - 4 .* a .* c)) ./ (2 .* a);
    
    Xc = Xs + A .* (Xa - Xs);
    Yc = Ys + A .* (Ya - Ys);
    Zc = Zs + A .* (Za - Zs);
    Xc = real(Xc); Yc = real(Yc); Zc = real(Zc);

    thetaC = atan2(Yc ,sqrt(Xc.^2 + Zc.^2));
    phiC = atan2(Xc , Zc);
   
    % 计算大圆距离
    delta_sigma = acos(sin(thetaA) .* sin(thetaC) + cos(thetaA) .* cos(thetaC) .* cos(phiC - phiA));

    s = Re .* delta_sigma;
    s = real(s);
    phiC=rad2deg(phiC);
    thetaC=rad2deg(thetaC);
end