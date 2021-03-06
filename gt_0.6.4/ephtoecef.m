function [ephs,sigs]=ephtoecef(td,time,ephs,sigs,prm,sats,dirs,fb,tunit)
%-------------------------------------------------------------------------------
% [system] : GpsTools
% [module] : transform coordinates of satellite ephemeris
% [func]   : transform coordinates of satellite ephemeris (eci to ecef)
% [argin]  : td   = date (mjd-gpst)
%            time = time vector (sec)
%            ephs = satellite ephemeris (eci)
%            sigs = satellite ephemeris standard deviation (eci)
%            prm  = estimation parameter
%            sats = satellites
%            dirs = estimated data directory
%            fb   = forward/backward
%            tunit = processing unit time (hr) (for 'ephf','ephb')
% [argout] : ephs = satellite ephemeris (ecef)
%            sigs = satellite ephemeris standard deviation (ecef)
% [note]   :
% [version]: $Revision: 16 $ $Date: 2008-12-12 15:49:30 +0900 (金, 12 12 2008) $
%            Copyright(c) 2004-2008 by T.Takasu, all rights reserved
% [history]: 05/04/12   0.1  new
%            05/04/29   0.2  support prm.nutmodel
%            05/06/28   0.3  use readerp() for reading erp estimation
%            08/12/11   0.4  utc_tai is computed by prm_utc_tai instead of prm
%-------------------------------------------------------------------------------
srcs={'','igs','igu','bulb','bula'};
if isfield(prm.src,'erp'), erpsrc=prm.src.erp; else erpsrc=srcs{prm.est.erp}; end
if isfield(prm,'nutmodel'), nutmodel=prm.nutmodel; else nutmodel=''; end

for n=1:length(time)
    utc_tai=prm_utc_tai(td+time(n)/86400,1);
    tu=td+(time(n)+19+utc_tai)/86400;
    if prm.est.erp==0
        erp_value=prm.erp;
    elseif prm.est.erp==1
        erp_value=readerp(tu,prm.dirs.est,['erp',fb],tunit);
        erp_value(4:5)=prm.erp(4:5);
    else
        erp_value=readerp(tu,prm.dirs.erp,erpsrc);
    end
    if prm.erpvar, erp_value(1:3)=erp_value(1:3)+erpvar(tu,utc_tai); end
    
    [U,q,q,gmst,dx,dy,du]=ecsftoecef(tu,erp_value,utc_tai,nutmodel);
    for m=1:length(sats)
        ephs(n,4:6,m)=ephs(n,4:6,m)*U'+ephs(n,1:3,m)*du';   % vel(ecef)
        ephs(n,1:3,m)=ephs(n,1:3,m)*U';                     % pos(ecef)
        sigs(n,1:3,m)=sqrt(diag(U*diag(sigs(n,1:3,m).^2)*U'))';
        sigs(n,4:6,m)=sqrt(diag(U*diag(sigs(n,4:6,m).^2)*U'))';
    end
end
