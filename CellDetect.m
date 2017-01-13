
%Prototype for cell detection algorithms for Auto Cell Tracker
%Based off: http://www.mathworks.com/help/images/examples/detecting-a-cell-using-image-segmentation.html
clear all
close all
clc

%DEFINED THRESHOLDS AND VALUES - These should be taken from the C# UI
ROUNDLIMIT = 0.5;       %Threshold for roundness measurement. 1= perfectly round.
CELL_FUDGE_UPPER_BOUND = 1; %Percentage of cell size allowed larger than median size (+/- % of median size)
CELL_FUDGE_LOWER_BOUND = 0.5; %Percentage of cell size allowed smaller than median size (+/- % of median size)
IMAGE_CROP_X1 = 0; %Top left corner of cropping window
IMAGE_CROP_Y1 = 0; %Top left corner of cropping window
IMAGE_CROP_X2 = 1391; %Bot right corner of cropping window
IMAGE_CROP_Y2 = 1039; %Bot right corner of cropping window

%Get image folder name from C# program:
%imageFolderPath = 'C:\Users\Jeff.JEFF-PC\Google Drive\Grad School Research\Matlab Prototype\Sample Images\1';
imageFolderPath = 'C:\Users\MDL\Google Drive\Grad School Research\Matlab Prototype\Sample Images\1';
imageList = dir(fullfile(imageFolderPath,'*bmp'));
%Loop these calculations through each image in the file folder

addpath(imageFolderPath);
imageIndex = 1;

finalImageCellArray = cell(size(imageList));
finalCentroidCellArrayX = cell(size(imageList));
finalCentroidCellArrayY = cell(size(imageList));

for imageName = imageList'
    
    %addpath(genpath('Sample Images'))
    %Add image to path

    imageFileName = imageName.name;
    %image = imread(fullfile(path,imageName.name));
    image = imread(imageName.name);
    image = rgb2gray(image);
    %imshow(image), title('original image')
 
    image = imcrop(image,[IMAGE_CROP_X1,IMAGE_CROP_Y1,IMAGE_CROP_X2,IMAGE_CROP_Y2]);
    %imshow(image), title('cropped image')

    %Edge detection. Use sobel operator to thrsehold the image, then sobel edge detection
    [~, threshold] = edge(image, 'sobel');
    fudgeFactor = 0.5;
    BWs = edge(image, 'sobel', threshold * fudgeFactor);
    %figure, imshow(BWs), title('boundary gradient mask');

    %expand the lines by 3 in each direction using strel function
    se90 = strel('line', 3, 90);
    se0 = strel('line', 3, 0);

    BWsdil = imdilate(BWs, [se90 se0]);
    %figure, imshow(BWsdil), title('dilated gradient mask');

    %Fill holes. Holes defined as where no edge can reach background in this function
    BWdfill = imfill(BWsdil, 'holes');
    %figure, imshow(BWdfill), title('binary image with filled holes');

    %Removes the cells that are connected to the border
    BWnobord = imclearborder(BWdfill, 4);
    %figure, imshow(BWnobord), title('cleared border image');

    %smoothen the objects
    seD = strel('diamond',1);
    BWsegmented = imerode(BWnobord,seD);
    BWsegmented = imerode(BWsegmented,seD);
    %figure, imshow(BWsegmented), title('segmented image');

    %Display the outline overlayed with cells
    BWoutline = bwperim(BWsegmented);
    Segout = image;
    Segout(BWoutline) = 255;
    %figure, imshow(Segout), title('outlined original image');

    %---------End of example from mathworks website--------------

    %Now, there are two problems:
    %1)Small spots are dispersed throughout that are not cells (could be debris or nothing). Maybe solve
    %this problem by setting a minimum threshold limit that will remove the segmented areas that are too
    %small?
    %2)Clumped cells - all together. Maybe we do a size thing again. Find the median size of segmented
    %areas after removing the small ones in step 1. Then set a fudge factor around the median size so
    %that only segmented areas around the median size are kept. This way we don't keep any things that
    %are clumped. Problems with this method could come up when the cells overlap in future images in the
    %series

    %remove the entries with an area < cellAreaMinimum
    cellAreaMinimum = 200;
    BWsmallRemoved = bwareaopen(BWsegmented, cellAreaMinimum);
    %figure, imshow(BWsmallRemoved), title('Small Cell Areas Removed');

    BWoutlineSmallRemoved = bwperim(BWsmallRemoved);
    Segout2 = image;
    Segout2(BWoutlineSmallRemoved) = 255;
    %figure, imshow(Segout2), title('outlined image small removed');

    %Calculate the centroids and areas of the cells
    stats = regionprops(BWsmallRemoved,'area');
    %figure, histogram([stats.Area]), title('Area');

    %Calculate the median of Area. Add a fudge factor to accept cells of the size median +/- fudgefactor
    cellMedian = median([stats.Area]);
    cellSizeFudgeUpper = cellMedian * CELL_FUDGE_UPPER_BOUND;
    cellSizeFudgeLower = cellMedian * CELL_FUDGE_LOWER_BOUND;
    cellSizeUpperLimit = round(cellMedian + cellSizeFudgeUpper);
    cellSizeLowerLimit = round(cellMedian - cellSizeFudgeLower);

    BWmedian = xor(bwareaopen(BWsmallRemoved,cellSizeLowerLimit), bwareaopen(BWsmallRemoved, cellSizeUpperLimit));
    %figure, imshow(BWmedian), title('after median+variability');

    BWmedianOutline = bwperim(BWmedian);
    Segout3 = image;
    Segout3(BWmedianOutline) = 255;
    %figure, imshow(Segout3), title('outlined median fudgefactor');

    %-----Next Steps-----%
    %1)Calculate the "roundness" of the objects - remove if they are under a threshold?
    %2)Find the centroids of each object and record the area
    %3)Iterate the calculations over the series of images. Connect the centroids from one image to the
    %next in series


    se = strel('disk',2);
    %BWstrel = imdilate(BWmedian,se);
    BWstrel = imdilate(BWmedian, [se90 se0]);
    %figure, imshow(BWstrel), title('BWstrel');

    BWstrelOutline = bwperim(BWstrel);
    strelSegout = image;
    strelSegout(BWstrelOutline) = 255;
    %figure, imshow(strelSegout), title('outlined strel');

    %Measure circularity
    %https://www.mathworks.com/help/images/examples/identifying-round-objects.html

    [B,L] = bwboundaries(BWstrel,'noholes');

    measurements = regionprops(L,'Area','Centroid','Perimeter');
    allAreas = [measurements.Area];
    allPerimeters = [measurements.Perimeter];
    circularities = (4*pi*allAreas) ./ allPerimeters.^2;
    keeperBlobs = circularities > ROUNDLIMIT;
    roundObjects = find(keeperBlobs);
    % Compute new binary image with only the small, round objects in it.
    BWroundKept = ismember(L, roundObjects) > 0;
    %figure, imshow(BWroundKept), title('final after round kept');

    BWroundKeptOutline = bwperim(BWroundKept);
    roundKeptSegout = image;
    roundKeptSegout(BWroundKeptOutline) = 255;
    %figure, imshow(roundKeptSegout), title('outlined after round cells kept');
    
    %Get the centroids of the final image
    finalMeasurements = regionprops(BWroundKept, 'Centroid');
    centroidList = [finalMeasurements.Centroid];
    centroidListX = centroidList(1:2:end-1);
    centroidListY = centroidList(2:2:end);
    
    finalImageCellArray{imageIndex} = roundKeptSegout;
    finalCentroidCellArrayX{imageIndex} = centroidListX;
    finalCentroidCellArrayY{imageIndex} = centroidListY;
    imageIndex = imageIndex + 1;
end


% set(0,'DefaultFigureWindowStyle','docked');
% for i=1:length(imageList)
%     figure, imshow(finalImageCellArray{i});
%     hold on
%     plot(finalCentroidCellArrayX{i},finalCentroidCellArrayY{i},'.');
% end

%% Do the tracking of cells. Using Kalman Filter + Hungarian assignment algorithm

dt = 1;         %time step. It should be constant so it doesn't matter, but the 

%% Kalman Filter Update Equations
%Coefficent matrices for the physics of the system. Here both the state and measurement are
%position. Use speed and acceleration for the model. 2Dimensions (X,Y)

%initialize state and input as 0's
posX = 0; posY = 0; velX = 0; velY = 0;
accel = 0;
%define noise magnitudes
posNoiseMagX = 0.1;
posNoiseMagY = 0.1;
accelNoiseMag = 1;

%Convert process noise into covariance matrix
Ez = [posNoiseMagX 0; 0 posNoiseMagY];
Ex = [dt^4/4 0 dt^3/2 0; ...
    0 dt^4/4 0 dt^3/2; ...
    dt^3/2 0 dt^2 0; ...
    0 dt^3/2 0 dt^2].*accelNoiseMag^2; % Ex convert the process noise (stdv) into covariance matrix
P = Ex;  % estimate of initial Hexbug position variance (covariance matrix)

%state matrix (position, speed)
X = [posX; posY; velX; velY];
X_est = X; %estimate of X

%acceleration input
u = accel;

A = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1];
B = [dt^2/2; dt^2/2; dt ; dt];
C = [1 0 0 0; 0 1 0 0];

%% initize result variables
Q_loc_meas = []; % the fly detecions  extracted by the detection algo
%% initize estimation variables for two dimensions
Q = [finalCentroidCellArrayX{1}' finalCentroidCellArrayY{1}' zeros(length(finalCentroidCellArrayX{1}),1) zeros(length(finalCentroidCellArrayY{1}),1)]';
Q_estimate = nan(4,2000);
Q_estimate(:,1:size(Q,2)) = Q;  %estimate of initial location estimation of where the flies are(what we are updating)
Q_loc_estimateY = nan(2000); %  position estimate
Q_loc_estimateX= nan(2000); %  position estimate
P_estimate = P;  %covariance estimator
strk_trks = zeros(1,2000);  %counter of how many strikes a track has gotten
nD = size(finalCentroidCellArrayX{1},2); %initize number of detections
nF =  find(isnan(Q_estimate(1,:))==1,1)-1 ; %initize number of track estimates

%% TODO: ADAPT EVERYTHING UNDER THIS LINE

%for each frame
for t = S_frame:length(f_list)-1 
    
    % load the image
    img_tmp = double(imread(f_list(t).name));
    img = img_tmp(:,:,1);
    % make the given detections matrix
    Q_loc_meas = [X{t} Y{t}];
    
    %% do the kalman filter
    % Predict next state of the flies with the last state and predicted motion.
    nD = size(X{t},1); %set new number of detections
    for F = 1:nF
        Q_estimate(:,F) = A * Q_estimate(:,F) + B * u;
    end
    
    %predict next covariance
    P = A * P* A' + Ex;
    % Kalman Gain
    K = P*C'*inv(C*P*C'+Ez);
    
    
    %% now we assign the detections to estimated track positions
    %make the distance (cost) matrice between all pairs rows = tracks, coln =
    %detections
    est_dist = pdist([Q_estimate(1:2,1:nF)'; Q_loc_meas]);
    est_dist = squareform(est_dist); %make square
    est_dist = est_dist(1:nF,nF+1:end) ; %limit to just the tracks to detection distances
    
    [asgn, cost] = assignmentoptimal(est_dist); %do the assignment with hungarian algo
    asgn = asgn';
    
    % ok, now we check for tough situations and if it's tough, just go with estimate and ignore the data
    %make asgn = 0 for that tracking element
    
    %check 1: is the detection far from the observation? if so, reject it.
    rej = [];
    for F = 1:nF
        if asgn(F) > 0
            rej(F) =  est_dist(F,asgn(F)) < 50 ;
        else
            rej(F) = 0;
        end
    end
    asgn = asgn.*rej;
    
        
    %apply the assingment to the update
    k = 1;
    for F = 1:length(asgn)
        if asgn(F) > 0
            Q_estimate(:,k) = Q_estimate(:,k) + K * (Q_loc_meas(asgn(F),:)' - C * Q_estimate(:,k));
        end
        k = k + 1;
    end
    
    % update covariance estimation.
    P =  (eye(4)-K*C)*P;
    
    %% Store data
    Q_loc_estimateX(t,1:nF) = Q_estimate(1,1:nF);
    Q_loc_estimateY(t,1:nF) = Q_estimate(2,1:nF);
    
    %ok, now that we have our assignments and updates, lets find the new detections and
    %lost trackings
    
    %find the new detections. basically, anything that doesn't get assigned
    %is a new tracking
    new_trk = [];
    new_trk = Q_loc_meas(~ismember(1:size(Q_loc_meas,1),asgn),:)';
    if ~isempty(new_trk)
        Q_estimate(:,nF+1:nF+size(new_trk,2))=  [new_trk; zeros(2,size(new_trk,2))];
        nF = nF + size(new_trk,2);  % number of track estimates with new ones included
    end
    
    
    %give a strike to any tracking that didn't get matched up to a
    %detection
    no_trk_list =  find(asgn==0);
    if ~isempty(no_trk_list)
        strk_trks(no_trk_list) = strk_trks(no_trk_list) + 1;
    end
    
    %if a track has a strike greater than 6, delete the tracking. i.e.
    %make it nan first vid = 3
    bad_trks = find(strk_trks > 6);
    Q_estimate(:,bad_trks) = NaN;
    
    %%{
    clf
    img = imread(f_list(t).name);
    imshow(img);
    hold on;
    plot(Y{t}(:),X{t}(:),'or'); % the actual tracking
    T = size(Q_loc_estimateX,2);
    Ms = [3 5]; %marker sizes
    c_list = ['r' 'b' 'g' 'c' 'm' 'y']
    for Dc = 1:nF
        if ~isnan(Q_loc_estimateX(t,Dc))
            Sz = mod(Dc,2)+1; %pick marker size
            Cz = mod(Dc,6)+1; %pick color
            if t < 21
                st = t-1;
            else
                st = 19;
            end
            tmX = Q_loc_estimateX(t-st:t,Dc);
            tmY = Q_loc_estimateY(t-st:t,Dc);
            plot(tmY,tmX,'.-','markersize',Ms(Sz),'color',c_list(Cz),'linewidth',3)
            axis off
        end
    end
    %pause(1)
    %}
    
    t
    
end

