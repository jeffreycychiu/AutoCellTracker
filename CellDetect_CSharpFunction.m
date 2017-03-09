%Prototype for cell detection algorithms for Auto Cell Tracker
%Based off: http://www.mathworks.com/help/images/examples/detecting-a-cell-using-image-segmentation.html

function [cSharpA, cSharpB] = CellDetect_CSharpFunction(imageFolderPath, ROUND_LIMIT, CELL_AREA_MINIMUM, CELL_FUDGE_UPPER_BOUND, CELL_FUDGE_LOWER_BOUND, IMAGE_CROP_X1, IMAGE_CROP_Y1, IMAGE_CROP_X2, IMAGE_CROP_Y2)
%function [cSharpA, cSharpB] = CellDetect_CSharpFunction(imageFolderPath, ROUND_LIMIT, CELL_AREA_MINIMUM, CELL_FUDGE_UPPER_BOUND, CELL_FUDGE_LOWER_BOUND)


cSharpA = 1;
cSharpB = 2;

%DEFINED THRESHOLDS AND VALUES - These should be taken from the C# UI
%ROUND_LIMIT = 0.35;       %Threshold for roundness measurement. 1= perfectly round.
%CELL_AREA_MINIMUM = 500;
%CELL_FUDGE_UPPER_BOUND = 5; %Percentage of cell size allowed larger than median size (+/- % of median size)
%CELL_FUDGE_LOWER_BOUND = 0.5; %Percentage of cell size allowed smaller than median size (+/- % of median size)

%IMAGE_CROP_X1 = 0; %Top left corner of cropping window
%IMAGE_CROP_Y1 = 0; %Top left corner of cropping window
%IMAGE_CROP_X2 = 1391; %Bot right corner of cropping window
%IMAGE_CROP_Y2 = 1039; %Bot right c orner of cropping window

%Get image folder name from C# program:

%imageFolderPath = 'C:\Users\MDL\Google Drive\Grad School Research\Matlab Prototype\Sample Images\Auto cell tracking pics\1';
%imageFolderPath = 'C:\Users\Jeff.JEFF-PC\Google Drive\Grad School Research\Matlab Prototype\Sample Images\lncap for cell tracking software';

%create file name to write the data at the end.
filename = strcat(datestr(datetime), ' Tracked Cells.csv'); %file name for csv save
filename = strrep(filename,':','-');

imageList = dir(fullfile(imageFolderPath,'*bmp'));
%Loop these calculations through each image in the file folder

addpath(imageFolderPath);
imageIndex = 1;

finalImageCellArray = cell(size(imageList));
finalCentroidCellArrayX = cell(size(imageList));
finalCentroidCellArrayY = cell(size(imageList));

croppedImages = cell(size(imageList));

%% Cell detection
for imageName = imageList'
    
    %addpath(genpath('Sample Images'))
    %Add image to path

    imageFileName = imageName.name;
    %image = imread(fullfile(path,imageName.name));
    image = imread(imageName.name);
    image = rgb2gray(image);
    %imshow(image), title('original image')
 
    image = imcrop(image,[IMAGE_CROP_X1,IMAGE_CROP_Y1,IMAGE_CROP_X2,IMAGE_CROP_Y2]);
    croppedImages{imageIndex} = image;
    %imshow(image), title('cropped image')
    
    %Background removal
    background = imopen(image,strel('disk',15));
    image = image - background;

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

    %remove the entries with an area < CELL_AREA_MINUMUM (defined in top)
    BWsmallRemoved = bwareaopen(BWsegmented, CELL_AREA_MINIMUM);
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
    keeperBlobs = circularities > ROUND_LIMIT;
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
    finalCentroidCellArrayX{imageIndex} = centroidListX';
    finalCentroidCellArrayY{imageIndex} = centroidListY';
    imageIndex = imageIndex + 1;
end

% pause
% close all
%  
% set(0,'DefaultFigureWindowStyle','docked');
% 
% for i=1:length(imageList)
%     figure, imshow(finalImageCellArray{i});
%     hold on
%     plot(finalCentroidCellArrayX{i},finalCentroidCellArrayY{i},'.');
% end
%-----END OF CELL DETECTION. NEXT SECTION IS TRACKING-----%


%% Do the tracking of cells. Using Kalman Filter + Hungarian assignment algorithm


%% Kalman Filter Update Equations
%Coefficent matrices for the physics of the system. Here both the state and measurement are
%position. Use speed and acceleration for the model. 2Dimensions (X,Y)

%define starting frame. Change this later to be user configurable. 
startFrame = 1;

%time step. It should be constant so it doesn't matter, but the magnitude probably matters if we want speed in real units
dt = 1;         

%initialize state and input as 0's
posX = 0; posY = 0; velX = 0; velY = 0;
accel = 0; %perhaps this should have accelX and accelY?

%define noise magnitudes. What does this mean?
posNoiseMagX = 0.1;
posNoiseMagY = 0.1;
accelNoiseMag = 0.1;

%The position variance in x and y initialized, in terms of pixels.
variancePosX = 25;
variancePosY = variancePosX;
varianceVelX = 200;
varianceVelY = varianceVelX;


%Convert process noise into covariance matrix Don't really understand this
%Ez = [posNoiseMagX 0; 0 posNoiseMagY];      %Noise of position detection on image of X and Y are uncorrelated (0 covariance)
Ez = [variancePosX 0; 0 variancePosY];      %Noise of position detection on image of X and Y are uncorrelated (0 covariance)
% Ex = [dt^4/4 0 dt^3/2 0; ...
%     0 dt^4/4 0 dt^3/2; ...
%     dt^3/2 0 dt^2 0; ...
%     0 dt^3/2 0 dt^2].*accelNoiseMag^2; % Ex convert the process noise (stdv) into covariance matrix

%Ex = [variancePosX 0 0 0;0 variancePosY 0 0; 0 0 varianceVelX 0; 0 0 0 varianceVelY];
Ex = eye(4)*variancePosX;
P = Ex;  % estimate of initial Hexbug position variance (covariance matrix)

%state matrix (position, speed)
X = [posX; posY; velX; velY];
X_est = X; %estimate of X

%acceleration input
u = accel;

A = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1];
B = [dt^2/2; dt^2/2; dt ; dt];
H = [1 0 0 0; 0 1 0 0];

%Find the frame with the most detected cells. Used to create empty arrays later   
%[maxNumCells, maxIndex] = max(cellfun('size', finalCentroidCellArrayX, 1));
maxNumCells = 1000;

%% initize result variables
Q_loc_meas = []; % the fly detecions  extracted by the detection algo
%% initize estimation variables for two dimensions
Q = [finalCentroidCellArrayX{startFrame} finalCentroidCellArrayY{startFrame} zeros(length(finalCentroidCellArrayX{startFrame}),1) zeros(length(finalCentroidCellArrayY{startFrame}),1)]';
Q_estimate = nan(4,maxNumCells);
Q_estimate(:,1:size(Q,2)) = Q;  %estimate of initial location estimation of where the flies are(what we are updating)
Q_loc_estimateX= nan(maxNumCells); %  position estimate
Q_loc_estimateY = nan(maxNumCells); %  position estimate
P_estimate = P;  %covariance estimator

strk_trks = zeros(1,maxNumCells);  %counter of how many strikes a track has gotten
nD = size(finalCentroidCellArrayX{1},1); %initize number of detections
nF =  find(isnan(Q_estimate(1,:))==1,1)-1 ; %initize number of track estimates

%% TODO: ADAPT EVERYTHING UNDER THIS LINE

%for each frame
for t = startFrame:length(imageList)
    
    % load the image
    img_tmp = croppedImages{t};
    img = img_tmp(:,:,1);
    % make the given detections matrix
    Q_loc_meas = [finalCentroidCellArrayX{t} finalCentroidCellArrayY{t}];
    
    %% do the kalman filter
    % Predict next state of the flies with the last state and predicted motion.
    nD = size(finalCentroidCellArrayX{t},1); %set new number of detections
    for F = 1:nF
        Q_estimate(:,F) = A * Q_estimate(:,F) + B * u;
    end
    
    %predict next covariance
    P = A * P* A' + Ex;
    % Kalman Gain
    K = P*H'*inv(H*P*H'+Ez);
    
    
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
    MAX_DISTANCE_MOVED = 50;
    rej = [];
    for F = 1:nF
        if asgn(F) > 0
            rej(F) =  est_dist(F,asgn(F)) < MAX_DISTANCE_MOVED ;
        else
            rej(F) = 0;
        end
    end
    asgn = asgn.*rej;
    
        
    %apply the assingment to the update
    k = 1;
    for F = 1:length(asgn)
        if asgn(F) > 0
            Q_estimate(:,k) = Q_estimate(:,k) + K * (Q_loc_meas(asgn(F),:)' - H * Q_estimate(:,k));
        end
        k = k + 1;
    end
    
    % update covariance estimation.
    P =  (eye(4)-K*H)*P;
    
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
    
    MAX_TRACK_STRIKES = 2;
    %if a track has a strike greater than 6, delete the tracking. i.e.
    %make it nan first vid = 3
    bad_trks = find(strk_trks > MAX_TRACK_STRIKES);
    Q_estimate(:,bad_trks) = NaN;
    
    %%{
    %clf
%     img = croppedImages{t};
%     figure, imshow(img);
%     hold on;
%     plot(finalCentroidCellArrayX{t}(:),finalCentroidCellArrayY{t}(:),'or'); % the actual tracking
%     T = size(Q_loc_estimateX,2);
%     Ms = [3 5]; %marker sizes
%     c_list = ['r' 'b' 'g' 'c' 'm' 'y']
%     for Dc = 1:nF
%         if ~isnan(Q_loc_estimateX(t,Dc))
%             Sz = mod(Dc,2)+1; %pick marker size
%             Cz = mod(Dc,6)+1; %pick color
%             if t < 21
%                 st = t-1;
%             else
%                 st = 19;
%             end
%             tmX = Q_loc_estimateX(t-st:t,Dc);
%             tmY = Q_loc_estimateY(t-st:t,Dc);
%             plot(tmX,tmY,'o-','markersize',Ms(Sz),'color',c_list(Cz),'linewidth',3)
%             
%             axis off
%         end
%     end
    %pause(1)
    %}
    
    t
    
end
% 
%% Output the tracked cells in terms of...csv maybe? Columns: Cell ID#|Frame|X Pos|Y Pos

trackedCellsX = cell(size(imageList));
trackedCellsY = cell(size(imageList));
numEntry = 1;
exportOutput = [];

for i=1:nF
    numFramesTracked = sum(~isnan(Q_loc_estimateX(:,i)));
    trackedCellsX{i} = nan(numFramesTracked,1);
    trackedCellsY{i} = nan(numFramesTracked,1);
    
    for j=1:nF
        if isnan(Q_loc_estimateX(j,i))
            break
        end
        numEntry = numEntry + 1;
        
        trackedCellsX{i}(j) = Q_loc_estimateX(j,i);
        trackedCellsY{i}(j) = Q_loc_estimateY(j,i);

        exportOutput(numEntry,1) = i;
        exportOutput(numEntry,2) = j;
        exportOutput(numEntry,3) = Q_loc_estimateX(j,i);
        exportOutput(numEntry,4) = Q_loc_estimateY(j,i);
        
        
    end

end

csvwrite(fullfile(imageFolderPath,filename),exportOutput);

end
