function [tfdirect,tfgeom,tfdiff,timingdata] = EDmakefirstordertfs(firstorderpathdata,...
    controlparameters,envdata,doaddsources,sources,receivers,edgedata)
% EDmakefirstordertfs calculates the direct sound, specular reflection, and
% first-order diffraction.
%
% Input parameters:
%   firstorderpathdata      Struct generated by EDfindconvexGApaths
%   controlparameters       Input struct; fields .frequencies and .Rstart 
%                           are used here
%   envdata                 Input struct; field .cair is used here
%   doaddsources            0 or 1
%   sources                 Matrix, [nsources,3]
%   receivers               Matrix, [nreceivers,3]
%   edgedata                Struct generated by EDfindedgedata
% 
% Output parameters:
%   tfdirect,tfgeom,tfdiff  Matrices, size [nfrequencies,nreceivers,nsources]
%                           (if doaddsources = 0) or [nfrequencies,nreceivers]
%                           (if doaddsources = 1)
%   timingdata              Vector, [1,3], containing times for the direct
%                           sound, spec. reflections, and first-order diffraction
%                           component generations
%   
% Uses functions EDcoordtrans2, EDwedge1st_fd
% 
% Peter Svensson 12 Jan. 2018 (peter.svensson@ntnu.no)
%
% [tfdirect,tfgeom,tfdiff,timingdata] = EDmakefirstordertfs(firstorderpathdata,...
%     controlparameters,envdata,doaddsources,sources,receivers,edgedata)

% 12 Jan. 2018 First complete version. Much simplified version of the
%                           previous ESIE2maketfs. Edgehits not handled
%                           yet.

timingdata = zeros(1,3);

nfrequencies = length(controlparameters.frequencies);
[nreceivers,nsources] = size(squeeze(firstorderpathdata.diffpaths(:,:,1)));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Direct sound

t00 = clock;

if doaddsources == 1
    tfdirect = zeros(nfrequencies,nreceivers);
else
    tfdirect = zeros(nfrequencies,nreceivers,nsources);
end

% alldists will be a matrix of size [nreceivers,nsources]

if firstorderpathdata.ncomponents(1) > 0
    ncomponents = size(firstorderpathdata.directsoundlist(:,1),1);

    distvecs = sources(firstorderpathdata.directsoundlist(:,1),:) - ...
        receivers(firstorderpathdata.directsoundlist(:,2),:);

    if ncomponents == 1
       alldists = norm(distvecs);
    else
        alldists = sqrt( sum(distvecs.^2,2) ); 
    end

    maxrecnumber = max( firstorderpathdata.directsoundlist(:,2) );

    kvec = 2*pi*controlparameters.frequencies(:)/envdata.cair;

    if ncomponents > nfrequencies
        for ii = 1:nfrequencies   
           alltfs = exp(-1i*kvec(ii)*alldists)./alldists;
           if doaddsources == 1
               tfdirect(ii,1:maxrecnumber) = accumarray(firstorderpathdata.directsoundlist(:,2),alltfs);
           else
              tfdirect(ii,firstorderpathdata.directsoundlist(:,2),firstorderpathdata.directsoundlist(:,1)) = alltfs;
           end

        end
    else
       for ii = 1:ncomponents 
            alltfs = exp(-1i*kvec*alldists(ii))./alldists(ii);
           if doaddsources == 1
              tfdirect(:,firstorderpathdata.directsoundlist(ii,2)) = ...
                  tfdirect(:,firstorderpathdata.directsoundlist(ii,2)) + alltfs;
           else
              tfdirect(:,firstorderpathdata.directsoundlist(ii,2),firstorderpathdata.directsoundlist(ii,1)) = alltfs;
           end
       end
    end
end

timingdata(1) = etime(clock,t00);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Specular reflections

t00 = clock;

if doaddsources == 1
    tfgeom = zeros(nfrequencies,nreceivers);
else
    tfgeom = zeros(nfrequencies,nreceivers,nsources);
end

if firstorderpathdata.ncomponents(2) > 0

    ncomponents = size(firstorderpathdata.specrefllist(:,1),1);

    distvecs = firstorderpathdata.specreflIScoords - ...
        receivers(firstorderpathdata.specrefllist(:,2),:);

    if ncomponents == 1
       alldists = norm(distvecs);
    else
        alldists = sqrt( sum(distvecs.^2,2) );
    end

    maxrecnumber = max( firstorderpathdata.specrefllist(:,2) );

    for ii = 1:nfrequencies    
        alltfs = exp(-1i*kvec(ii)*alldists)./alldists;
        if doaddsources == 1
            tfgeom(ii,1:maxrecnumber) = accumarray(firstorderpathdata.specrefllist(:,2),alltfs);
        else
            tfgeom(ii,firstorderpathdata.specrefllist(:,2),firstorderpathdata.specrefllist(:,1)) = alltfs;
        end
    end

end

timingdata(2) = etime(clock,t00);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Diffraction

t00 = clock;

if doaddsources == 1
    tfdiff = zeros(nfrequencies,nreceivers);
else
    tfdiff = zeros(nfrequencies,nreceivers,nsources);
end

iv = find(firstorderpathdata.edgeisactive);

sou_vs_edges = sign(squeeze(sum(firstorderpathdata.diffpaths,1)));
if size(sou_vs_edges,2) == 1
    sou_vs_edges = sou_vs_edges.';
end
rec_vs_edges = sign(squeeze(sum(firstorderpathdata.diffpaths,2)));
if size(rec_vs_edges,2) == 1
    rec_vs_edges = rec_vs_edges.';
end

for ii = 1:length(iv)
    cylcoordS = zeros(nsources,3);
    cylcoordR = zeros(nreceivers,3);

    edgenumber = iv(ii);
    edgecoords = [edgedata.edgestartcoords(edgenumber,:);edgedata.edgeendcoords(edgenumber,:)];

    sourceandreceivercombos = squeeze(firstorderpathdata.diffpaths(:,:,edgenumber));
    iv2 = find(sourceandreceivercombos);
    [Rnumber,Snumber] = ind2sub([nreceivers,nsources],iv2);

    ivS = find(sou_vs_edges(:,edgenumber));
    ivR = find(rec_vs_edges(:,edgenumber));
    [rs,thetas,zs,rr,thetar,zr] = EDcoordtrans2(sources(ivS,:),receivers(ivR,:),edgecoords,edgedata.edgenvecs(edgenumber,:));
    
    cylcoordS(ivS,:) = [rs thetas zs];
    cylcoordR(ivR,:) = [rr thetar zr];
    
    
    for jj = 1:length(iv2)
        [tfnew,singularterm] = EDwedge1st_fd(envdata.cair,controlparameters.frequencies,edgedata.closwedangvec(edgenumber),...
            cylcoordS(Snumber(jj),1),cylcoordS(Snumber(jj),2),cylcoordS(Snumber(jj),3),...
            cylcoordR(Rnumber(jj),1),cylcoordR(Rnumber(jj),2),cylcoordR(Rnumber(jj),3),...
            edgedata.edgelengthvec(edgenumber)*[0 1],'n',controlparameters.Rstart,[1 1]);                  
        if doaddsources == 1
            tfdiff(:,Rnumber(jj)) =  tfdiff(:,Rnumber(jj)) + tfnew;                       
        else
            tfdiff(:,Rnumber(jj),Snumber(jj)) =  tfdiff(:,Rnumber(jj),Snumber(jj)) + tfnew;           
        end
    end
            
end

timingdata(3) = etime(clock,t00);



