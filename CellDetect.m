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
imageFolderPath = 'C:\Users\Jeff.JEFF-PC\Google Drive\Grad School Research\Matlab Prototype\Sample Images\1';
imageList = dir(fullfile(imageFolderPath,'*bmp'));
%Loop these calculations through each image in the file folder

addpath(imageFolderPath);
imageIndex = 1;

finalImageCellArray = cell(size(imageList));

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
    figure, imshow(roundKeptSegout), title('outlined after round cells kept');

    %Get the centroids of the final image
    finalMeasurements = regionprops(BWroundKept, 'Centroid');
    centroidList = [finalMeasurements.Centroid];
    centroidListX = centroidList(1:2:end-1);
    centroidListY = centroidList(2:2:end);
    
    
    finalImageCellArray{imageIndex} = BWroundKept;
    imageIndex = imageIndex + 1;
end
