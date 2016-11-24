function h=gpsdown(varargin)
%-------------------------------------------------------------------------------
% [system] : GpsTools
% [module] : data downloader
% [func]   : gps data and products downloader
% [argin]  : (opt)
%                prmfile : batch download parameter file
%                      addrs  = gps data/products source address url list
%                      dates  = start date [year,month,day]
%                      datee  = end date   [year,month,day]
%                      times  = start time [hour,min]
%                      timee  = end time   [hour,min]
%                     (rcvs)  = stations/centers list
%                     (ldir)  = local directory
%                     (login) = login user name
%                     (passwd)= login password
%                     (downf) = don't download existing file
%                     (stopf) = stop if download error
% [argout] : h  = figure handle
% [note]   : keywords in source address and local address replaced as follows
%               %S -> station/centre code (UPPER case)
%               %s -> station/centre code (lower case)
%               %G -> GSI station code (tail 4 chars)
%               %Y -> year        (1990-0
%               %y -> year        (00-99)
%               %m -> month       (01-12)
%               %d -> day         (01-31)
%               %n -> day of year (001-366)
%               %h -> hour        (00-23)
%               %ha-> 3H hour     (00,03,06,...,21)
%               %hb-> 6H hour     (00,06,12,18)
%               %hc-> 12H hour    (00,12)
%               %H -> hour code   (a,b,c,...,x)
%               %t -> minute      (00,15,30,45)
%               %g -> 3H hour     (02,05,08,...,23)
%               %f -> 3H sequence no (1=00,2=03,...,8=21)
%               %W -> gpsweek no. (0000-9999)
%               %D -> day of gpsweek (0-6)
%               %M -> iers bulletin month (1- )
%               %N -> sequence no (0000-9999)
%               %P -> install path
%               %RO-> rinex obs   (%s%n0.%yo)
%               %RD-> rinex cobs  (%s%n0.%yd)
%               %RN-> rinex nav (GPS) (%s%n0.%yn)
%               %RG-> rinex nav (GLONASS) (%s%n0.%yg)
%               %RM-> rinex met   (%s%n0.%ym)
%               %RS-> rinex sum   (%s%n0.%ys)
%               %{s1|s2|s3|...|sn}->strings s1,s2,s,...,sn
% [version]: $Revision: 32 $ $Date: 06/07/21 18:57 $
%            Copyright(c) 2004-2006 by T.Takasu, all rights reserved
% [history]: 04/11/15  0.1  new
%            04/12/05  0.2  use 'gut' gui common routines
%            05/03/01  0.3  use gfilepath.m, stop using exfilepath.m
%            05/05/16  0.4  replace keyword in local directory
%                           add keyword %{...}
%                           add hours,minutes range setting
%            05/08/25  0.5  fix bug to extend keyword of %h %H %t
%            06/07/01  0.6  add multiple selection of data sources
%-------------------------------------------------------------------------------
if nargin<1, h=GpsDownGui;
elseif strcmp(varargin{1}(1:2),'cb'), feval(varargin{:});
else GpsDownBatch(varargin{1}), end

% gui downloader ---------------------------------------------------------------
function h=GpsDownGui
dirs=pwd; login='anonymous'; passwd='';
h=gut('newfig','gtdown',['Data/Products Downloader'],[600,400,0,-50],...
      [mfilename,' cbExit']);
if isempty(h), return, end
hours={}; for n=0:23, hours={hours{:},sprintf('%2d',n)}; end
gut('newtext','',[5,378,175,20],'Data/Products (Source)',2);
gut('newpopm','cat',[3,362,178,22],...
    {'Observation Data','Products','Earth Rotation Parameters','Others'},...
    {},[mfilename,' cbDownloadCat']);
gut('newlist','src',[2,2,180,356],{''},{},2,[mfilename,' cbDownloadSrc']);
gut('newtext','',[188,378,405,20],'Address',2);
gut('newedit','addr',[188,363,405,21],'',1);
gut('newtext','txt1',[189,335,189,20],'Start - End Date/Time',2);
gut('newtext','txt3',[189,264,100,20],'Sequence No');
gut('newymd','dates',[189,320,116,20],[2004,1,1],'');
gut('newymd','datee',[189,296,116,20],[2004,1,1],'');
gut('newtable','times',[307,320,70,20],1,2,[0,0]);
gut('newtable','timee',[307,296,70,20],1,2,[0,0]);
gut('newtable','seqno',[270,267,107,20],1,2,[1,1]);
gut('newtext','',[188,243,188,20],'Login User',2);
gut('newedit','login',[188,228,189,21],login,1);
gut('newtext','',[188,207,188,20],'Password',2);
gut('newedit','passwd',[188,192,189,21],passwd,1);
gut('newtext','',[188,171,188,20],'Local Directory',2);
gut('newdedit','ldir',[188,156,200,21],dirs);
gut('newchk','unzip',[188,131,180,20],'Unzip/Uncompact Files');
gut('newchk','downf',[188,113,180,20],'Skip Existing Files');
gut('newchk','stopf',[188,95,180,20],'Abort on Download Error');
gut('setval','unzip',1), gut('setval','downf',1)
gut('newtext','txt4',[390,335,205,20],'Stations',2);
gut('newlist','rcvs',[390,96,205,245],{},{},2,'');
h1=gut('newtext','msg1',[188,68,405,20],'',2);
h2=gut('newtext','msg2',[188,49,405,20],'',2);
set(h1,'foregroundcolor','b');
set(h2,'fontname',gut('getfont','f'),'fontsize',8);
gut('newprog','downprog',[188,34,405,15],[0,0.7,1]);
gut('newbtnh','btns',[186,4,410,23],...
    {'Files...','Stations...','Log...','Download','Close'},...
    {[mfilename,' cbFile'],[mfilename,' cbRcv'],[mfilename,' cbLog'],...
     [mfilename,' cbDownload'],[mfilename,' cbExit']});
gut('setudata','addr',ReadDataSrc);
cbDownloadCat
[path,file]=fileparts(which(mfilename));
LoadPrm(fullfile(path,'settings','prm_gpsdown.mat'))

% callback on category change --------------------------------------------------
function cbDownloadCat
addrs=gut('getudata','addr'); if isempty(addrs), return, end
cat=get(gut('geth','cat'),'value'); list={};
for n=1:size(addrs,1), if addrs{n,1}==cat, list={list{:},addrs{n,2}}; end, end
set(gut('geth','src'),'string',list,'userdata',list,'value',1)
cbDownloadSrc

% callback on source change ----------------------------------------------------
function cbDownloadSrc
addrs=gut('getudata','addr'); if isempty(addrs), return, end
n=get(gut('geth','cat'),'value'); m=get(gut('geth','src'),'value');
i=find([addrs{:,1}]==n); addrs=addrs(i(m),3); if isempty(addrs), return, end
addr=addrs{1}; if length(addrs)>1, addr=[addr,' ...']; end
gut('setstring','addr',addr);
pat1={'%Y','%y','%m','%d','%n','%h','%H','%t','%g','%f','%W','%D','%M','%R','%EA'};
tag1={'txt1','txt2','dates_1','dates_2','dates_3','datee_1','datee_2','datee_3',...
      'times_1_1','times_1_2','timee_1_1','timee_1_2'};
pat2={'%N'};
tag2={'txt3','seqno_1_1','seqno_1_2'};
pat3={'%S','%s','%G','%R'};
tag3={'txt4','rcvs'};
enagui(addrs,pat1,tag1);
enagui(addrs,pat2,tag2);
enagui(addrs,pat3,tag3);

function enagui(addrs,pats,tags)
for n=1:length(addrs)
    for m=1:length(pats)
        if ~isempty(findstr(addrs{n},pats{m})), gut('setena',tags); return; end
    end
end
gut('setdis',tags);

% callback on station list -----------------------------------------------------
function cbRcv
label=gut('getstring','rcvs');
list={}; for n=1:length(label), list={list{:},strtok(label{n})}; end
[list,ok,label]=editlist('Stations',list,'rcv');
if ok, gut('setlist','rcvs',label,{}); end

% callback on download ---------------------------------------------------------
function cbDownload
label1='Download'; label2='Abort';
for n=1:5, btns(n)=gut('geth',['btns_',num2str(n)]); end
for n=1:2, msgs(n)=gut('geth',['msg',num2str(n)]); end
downprog=gut('geth','downprog');

if strcmp(get(btns(4),'string'),label2)
    set(btns(4),'string',label1,'enable','off')
    return
end
addrs=gut('getudata','addr'); if isempty(addrs), return, end
n=get(gut('geth','cat'),'value'); m=get(gut('geth','src'),'value');
i=find([addrs{:,1}]==n); addrs=addrs(i(m),3);
addr=gut('getstring','addr');
s=gut('gettime','dates');
e=gut('gettime','datee');
ts=gut('gettable','times');
te=gut('gettable','timee');
seqno=gut('gettable','seqno');
login=gut('getstring','login');
passwd=gut('getstring','passwd');
ldir=gut('getstring','ldir');
unzip=gut('getval','unzip');
downf=gut('getval','downf');
stopf=gut('getval','stopf');
rcvs=gut('getstring','rcvs');
fig=gcf; gut('setdisall',fig);
set(btns(1),'enable','on')
set(btns(4),'enable','on','string',label2)
set(msgs(1),'enable','on','string','');
set(msgs(2),'enable','on','string','');
[paths,ldirs]=DownloadFiles(addrs,rcvs,datenum(s(1),s(2),s(3),ts(1),ts(2),0),...
                            datenum(e(1),e(2),e(3),te(1),te(2),0),seqno,ldir);
stats=' ';
gut('setprog','downprog',0)
if isempty(paths)
    set(msgs(1),'string','no download file')
else
    stat=0; sstat='done'; ts=now; no=[0,0,0]; bytes=0; 
    for m=1:length(paths)
        if strcmp(get(btns(4),'string'),label1)|(stopf&stat<0)
            sstat='aborted'; break
        end
        set(msgs(1),'string',paths{m})
        stats=[stats(max(1,end-64):end),'_'];
        set(msgs(2),'string',stats)
        if exist(ldirs{m})~=7, [r,d,e]=fileparts(ldirs{m}); mkdir(r,[d,e]); end
        for k=1:3
            [host,file]=strtok(paths{m},'/');
            [stat,msg,log,b]=ftpget(host,login,passwd,file,ldirs{m},~downf,unzip);
            if k<3&stat==-3
                if strcmp(get(btns(4),'string'),label1), break, end
                stats(end)=num2str(k); set(msgs(2),'string',stats)
                pause(15);
            else break, end
        end
        bytes=bytes+b;
        dv=datevec(now); t=sprintf('%02d:%02d:%02.0f: ',dv(4:6));
        switch stat,
        case  0, stats(end)='o'; no(1)=no(1)+1;
        case  1, stats(end)='.'; no(3)=no(3)+1;
        case -1, stats(end)='x'; no(2)=no(2)+1;
        otherwise, stats(end)='X'; no(2)=no(2)+1; end
        set(msgs(2),'string',stats)
        gut('setprogh',downprog,m/length(paths))
        logs=[get(btns(3),'userdata'),char(10),t,paths{m},' : ',msg];
        logs=logs(max(end-80000,1):end);
        set(btns(3),'userdata',logs);
    end
    set(msgs(1),'string',['download ',sstat,' ',Stats(no,bytes,ts,now)])
    gpsfiles('cbUpdate');
end
set(btns(4),'string',label1)
gut('setenaall',fig);
cbDownloadSrc

% download statistics ----------------------------------------------------------
function s=Stats(no,bytes,ts,te)
rate=bytes/1024/((te-ts)*86400);
s=sprintf('(ok=%d error=%d exist=%d rate=%.1fKB/s)',no,rate);

% callback on files ------------------------------------------------------------
function cbFile
dt=gut('gettime','dates'); rcvs=gut('getstring','rcvs');
if ~isempty(rcvs), rcv=strtok(rcvs{1}); else rcv=''; end
dirs=gfilepath('',gut('getstring','ldir'),dt,rcv);
gpsfiles; gpsfiles('cbUpdate',dirs);

% callback on log --------------------------------------------------------------
function cbLog
log=get(gcbo,'userdata'); str={}; n=0;
while 1
    [s,log]=strtok(log,char(10)); n=n+1; str{n}=s;
    if isempty(log), if n>1000, str=str(end-1000:end); end, break, end
end
gut('newviewer','gdownlog','Download Log',[600,400],'str',str);

% callback on close ------------------------------------------------------------
function cbExit
[path,file]=fileparts(which(mfilename));
SavePrm(fullfile(path,'settings','prm_gpsdown.mat'));
closereq

% callback on update -----------------------------------------------------------
function cbUpdate(dirs)
gut('setstring','ldir',dirs);

% save settings ----------------------------------------------------------------
function SavePrm(file)
ctg=get(gut('geth','cat'),'value');
src=get(gut('geth','src'),'value'); srcs=gut('getstring','src'); src=srcs(src);
dates=gut('gettime','dates');
datee=gut('gettime','datee');
times=gut('gettable','times');
timee=gut('gettable','timee');
seqno=gut('gettable','seqno');
addr=gut('getstring','addr');
login=gut('getstring','login');
passwd=gut('getstring','passwd');
ldir=gut('getstring','ldir');
unzip=gut('getval','unzip');
downf=gut('getval','downf');
stopf=gut('getval','stopf');
rcvs=gut('getstring','rcvs');
save(file,'ctg','src','dates','datee','times','timee','seqno','addr','login',...
     'passwd','ldir','downf','stopf','unzip','rcvs')

% load settings ----------------------------------------------------------------
function LoadPrm(file)
ctg=[]; addr=''; prm=[]; times=[0,0]; timee=[0,0]; seqno=[1,1]; unzip=1;
downf=1; stopf=0;
if exist(file), load(file), end
if ~isempty(ctg)
    set(gut('geth','cat'),'value',ctg);
    cbDownloadCat
    gut('setsel','src',src)
    gut('setstring','rcvs',rcvs)
    gut('settime','dates',dates)
    gut('settime','datee',datee)
    gut('settable','times',times)
    gut('settable','timee',timee)
    gut('settable','seqno',seqno)
    gut('setstring','addr',addr)
    gut('setstring','login',login);
    gut('setstring','passwd',passwd);
    gut('setstring','ldir',ldir);
    gut('setval','unzip',unzip);
    gut('setval','downf',downf);
    gut('setval','stopf',stopf);
elseif ~isempty(prm)
    gut('setstring','rcvs',prm.rcvs)
end
% extend file path -------------------------------------------------------------
function [paths,ldirs]=DownloadFiles(addrs,rcvs,dates,datee,seqno,ldir)
paths=cell(400000,1); ldirs=cell(400000,1); np=0;
name={}; path={}; 
for n=1:length(rcvs), name{n}=strtok(rcvs{n}); end
for n=1:length(addrs)
    p=findstr(addrs{n},'ftp://');
    if ~isempty(p), path={path{:},addrs{n}(p+6:end)}; end
end
ds=floor(dates); ts=round(mod(dates,1)*24*60)/60;
de=floor(datee); te=round(mod(datee,1)*24*60)/60;
for d=ds:de
    day=datevec(d);
    if d==ds, tts=ts; else tts=0; end
    if d==de, tte=te; else tte=23.999; end
    for n=1:length(path)
        if ~isempty(findstr(path{n},'%N'))
            for m=seqno(1):seqno(2)
                paths{np+1}=strrep(path{n},'%N',sprintf('%04d',m));
                ldirs{np+1}=ldir; np=np+1;
            end
        elseif isempty(name)
            if isempty([findstr(path{n},'%s'),findstr(path{n},'%S'),...
                        findstr(path{n},'%G'),findstr(path{n},'%R')])
                [ps,ld]=exttime(gfilepath('',path{n},day(1:3),''),...
                                gfilepath('',ldir,day(1:3),''),tts,tte);
                nn=length(ps); paths(np+(1:nn))=ps; ldirs(np+(1:nn))=ld;
                np=np+nn;
            end
        else
            for m=1:length(name)
                [ps,ld]=exttime(gfilepath('',path{n},day(1:3),name{m}),...
                                gfilepath('',ldir,day(1:3),name{m}),tts,tte);
                nn=length(ps); paths(np+(1:nn))=ps; ldirs(np+(1:nn))=ld;
                np=np+nn;
            end
        end
    end
end
paths=paths(1:np); ldirs=ldirs(1:np);
[p,i]=unique(paths); i=sort(i); paths=paths(i); ldirs=ldirs(i);

% ext keyword %{} --------------------------------------------------------------
function paths=extstrs(paths)
ps={};
for n=1:length(paths)
    p=findstr(paths{n},'%{');
    if ~isempty(p)
        q=findstr(paths{n}(p+1:end),'}');
        if ~isempty(q)
            strs=paths{n}(p+2:p+q-1);
            while 1
                [s,strs]=strtok(strs,'|');
                ps={ps{:},[paths{n}(1:p-1),s,paths{n}(p+q+1:end)]};
                if isempty(strs), break, end
            end
        end
    else
        ps={ps{:},paths{n}};
    end
end
paths=ps;

% extend date/time -------------------------------------------------------------
function [paths,ldirs]=exttime(path,ldir,ts,te)
paths={}; ldirs={}; n=0; if isempty(path), return, end
if ~isempty(findstr(path,'%ha'))
    for h=ceil(ts/3)*3:3:te
        n=n+1;
        paths{n}=strrep(path,'%ha',sprintf('%02d',h));
        ldirs{n}=strrep(ldir,'%ha',sprintf('%02d',h));
    end
elseif ~isempty(findstr(path,'%hb'))
    for h=ceil(ts/6)*6:6:te
        n=n+1;
        paths{n}=strrep(path,'%hb',sprintf('%02d',h));
        ldirs{n}=strrep(ldir,'%hb',sprintf('%02d',h));
    end
elseif ~isempty(findstr(path,'%hc'))
    for h=ceil(ts/12)*12:12:te
        n=n+1;
        paths{n}=strrep(path,'%hc',sprintf('%02d',h));
        ldirs{n}=strrep(ldir,'%hc',sprintf('%02d',h));
    end
elseif ~isempty([findstr(path,'%h'),findstr(path,'%H'),findstr(path,'%t')])
    for h=ceil(ts):te
        f=strrep(path,'%h',sprintf('%02d',h));
        f=strrep(f,'%H',sprintf('%c','a'+h));
        l=strrep(ldir,'%h',sprintf('%02d',h));
        l=strrep(l,'%H',sprintf('%c','a'+h));
        if findstr(path,'%t')
            if h==ceil(ts),  ms=mod(ts,1)*60; else ms=0; end
            if h==floor(te), me=mod(te,1)*60; else me=59.999; end
            for t=floor(ms/15)*15:15:me
                n=n+1;
                paths{n}=strrep(f,'%t',sprintf('%02d',t));
                ldirs{n}=strrep(l,'%t',sprintf('%02d',t));
            end
        else
            n=n+1; paths{n}=f; ldirs{n}=l;
        end
    end
elseif ~isempty(findstr(path,'%f'))
    for h=ceil(ts/3)*3:3:te
        n=n+1;
        paths{n}=strrep(path,'%f',sprintf('%d',h/3+1));
        ldirs{n}=strrep(ldir,'%f',sprintf('%d',h/3+1));
    end
elseif ~isempty(findstr(path,'%g'))
    for h=ceil(ts/3)*3+2:3:te
        n=n+1;
        paths{n}=strrep(path,'%g',sprintf('%02d',h));
        ldirs{n}=strrep(ldir,'%g',sprintf('%02d',h));
    end
else paths={path}; ldirs={ldir}; end

while ~isempty(paths)&~isempty(findstr(paths{1},'%{'))
    ps={}; ld={};
    for n=1:length(paths)
        pss=extstrs(paths(n));
        ps={ps{:},pss{:}};
        for m=1:length(pss), ld={ld{:},ldirs{n}}; end
    end
    paths=ps; ldirs=ld;
end

% read data source parameters --------------------------------------------------
function addrs=ReadDataSrc
addrs={};
[dirs,f]=fileparts(which(mfilename));
dirs=fullfile(dirs,'data');
file=fullfile(dirs,'prm_gpssrcs.m');
if exist(file), wd=cd; cd(dirs); addrs=feval('prm_gpssrcs'); cd(wd); end
if isempty(addrs)
    gut('errdlg',['no download source definitions file : ',file]);
end

% batch downloader -------------------------------------------------------------
function GpsDownBatch(prmfile)
addrs={}; rcvs={}; ldir=''; login='anonymous'; passwd='IEUser@';
dates=[2000,1,1];datee=[2000,1,1];
eval(prmfile)
Msg(['Data/Products Downloader']);
dates=datenum(dates(1),dates(2),dates(3));
datee=datenum(datee(1),datee(2),datee(3));
for n=1:length(addr)
    [host,files,days,names]=DownloadFiles(addr{n},rcvs,dates,datee);
    for k=1:length(files)
        disp(['downloading : ',host,files{k}])
        ld=gfilepath(ldir,'',days(k,:),names{k},1);
        [stat,msg,log]=ftpget(host,login,passwd,files{k},ld,downf);
        if stat~=0, disp(['download error : ',msg]), if stopf, break, end, end
    end
end
