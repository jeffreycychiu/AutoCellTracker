using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.IO;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using System.Runtime.InteropServices;
using MahApps.Metro.Controls;
using Microsoft.Win32;
using Ookii.Dialogs.Wpf;
using Emgu.CV;
using Emgu.Util;
using Emgu.CV.Structure;
using AutoCellTracker;
using MathWorks.MATLAB.NET.Arrays;
using MathWorks.MATLAB.NET.Utility;


namespace AutoCellTracker
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml 
    /// </summary>
    public partial class MainWindow : MetroWindow
    {
        public int numImages = 0;
        public int currentImage = 0;
        List<String> imageFilePath = new List<string>();
        //List<Emgu.CV.IImage> imageList = new List<Emgu.CV.IImage>();
        public List<Emgu.CV.Image<Bgr,Byte>> imageList = new List<Emgu.CV.Image<Bgr, Byte>>();
        public List<Emgu.CV.Image<Bgr, Byte>> imageListCopy = new List<Emgu.CV.Image<Bgr, Byte>>();

        //create parameters class with all the values for tracking/cropping etc
        Parameters parameters = new Parameters();

        MLApp.MLApp matlab = new MLApp.MLApp();

        //Use for path - put the matlab script .m file here
        //string startupPath = System.IO.Directory.GetCurrentDirectory();
        string startupPath = @"'C:\Users\MDL\Google Drive\Grad School Research\Matlab Prototype'";
        
        public MainWindow()
        {
            InitializeComponent();
        }

        private void selectFolder_Click(object sender, RoutedEventArgs e)
        {
            //Select the folder which all the images are kept

            VistaFolderBrowserDialog dialog = new VistaFolderBrowserDialog();
            dialog.Description = "Navigate to folder containing images";
            dialog.UseDescriptionForTitle = true; // This applies to the Vista style dialog only, not the old dialog.
            if (!VistaFolderBrowserDialog.IsVistaFolderDialogSupported)
                MessageBox.Show(this, "Because you are not using Windows Vista or later, the regular folder browser dialog will be used. Please use Windows Vista to see the new dialog.", "Sample folder browser dialog");
            if ((bool)dialog.ShowDialog(this))
            {
                folderTextBlock.Text = dialog.SelectedPath;
                btnTrack.IsEnabled = true;
            }
                

            try
            {
                DirectoryInfo directoryInfo = new DirectoryInfo(dialog.SelectedPath);

                //Searches folder for bitmap (.bmp) files. Loads an array with file names, and counts the total number of bmp files
                numImages = 0;
                currentImage = 0;

                //TODO: Add support for other image formats
                imageFilePath.Clear();
                imageFilePath.TrimExcess();
                foreach (var imageFile in directoryInfo.GetFiles("*.bmp"))
                {
                    imageFilePath.Add(imageFile.FullName);
                    numImages++;
                }
            }
            catch (ArgumentException)
            {
                MessageBox.Show("Error: Folder not selected");
            }

            //Load images - create a list of EmguCV IImages
            imageList.Clear();
            imageList.TrimExcess();

            for (int i = 0; i < numImages; i++)
            {
                Image<Bgr, Byte> image = new Image<Bgr, Byte>((imageFilePath[i]));
                imageList.Add(image);
            }

            if (numImages > 0)
            {
                //create copy of the image list so that it can be re-loaded if need be
                imageListCopy.Clear();
                imageListCopy.TrimExcess();
                foreach(var image in imageList)
                {
                    imageListCopy.Add(image);
                }

                updateImage();
                btnNext.IsEnabled = true;
                btnPrev.IsEnabled = true;
            }

        }

        public void updateImage()
        {
            //May have memory leak here - need to fix
            BitmapSource imageBitmapSoruce = ToBitmapSource(imageList[currentImage]);
            imageDisplay.Source = imageBitmapSoruce;
            numImagesTextBlock.Text = "Image: " + (currentImage + 1) + "/" + numImages.ToString();
        }

        public void nextImage()
        {
            currentImage++;
            if (currentImage > (numImages - 1))
                currentImage = 0;
            updateImage();
        }

        public void prevImage()
        {
            currentImage--;
            if (currentImage < 0)
                currentImage = numImages - 1;
            updateImage();
        } 

        private void btnNext_Click(object sender, RoutedEventArgs e)
        {
            nextImage();
        }

        private void btnPrev_Click(object sender, RoutedEventArgs e)
        {
            prevImage();
        }

        private void btnFlyoutSettings_Click(object sender, RoutedEventArgs e)
        {
            flyoutSettings.IsOpen = true;
        }

        //Crops all of the pictures in the folders. Creates a new list of cropped Images
        private void btnCrop_Click(object sender, RoutedEventArgs e)
        {
            //Popup message box of the coordinates to crop. Given in x1,y1,x2,y2. Will draw a rectangle from top left (x1,y1) to bottom right(x2,y2)
            flyoutSettings.IsOpen = false;
            //open crop window
            cropWindow cropWindow = new cropWindow();
            cropWindow.Show();

            //Enable the red rectangle that shows the cropping box. Get the cropping box size from the new Crop Window
            
        }

        private void btnSave_Click(object sender, RoutedEventArgs e)
        {
            //TEMPORARY - using this button to test the matlab function integration


        }

                private void btnTrack_Click(object sender, RoutedEventArgs e)
        {
            //Change MATLAB to the directory where the function is located - make sure user installs it in the correct location

            matlab.Execute(@"cd " + startupPath);

            string imageFolderPath = folderTextBlock.Text;

            double roundLimit = parameters.roundLimit;
            double cellAreaMinimum = parameters.cellAreaMinimum;
            double cellFudgeUpperBound = parameters.cellFudgeUpperBound;
            double cellFudgeLowerBound = parameters.cellFudgeLowerBound;
            int maxDistanceMoved = parameters.maxDistanceMoved;
            int maxTrackStrikes = parameters.maxTrackStrikes;
            int minNumberTracks = parameters.minNumberTracks;
            int cropWindowX1 = parameters.cropWindowX1;
            int cropWindowY1 = parameters.cropWindowY1;
            int cropWindowX2 = parameters.cropWindowX2;
            int cropWindowY2 = parameters.cropWindowY2;

            //Reload images from the original copied list after folder selection
            imageList.Clear();
            imageList.TrimExcess();
            foreach (var image in imageListCopy)
            {
                imageList.Add(image);
            }

            //Crop the images in the image list first
            for (int i = 0; i < numImages; i++)
            {
                imageList[i].ROI = new System.Drawing.Rectangle(cropWindowX1, cropWindowY1, cropWindowX2, cropWindowY2);
                Image<Bgr, byte> croppedImage = new Image<Bgr, Byte>(cropWindowX2 - cropWindowX1, cropWindowY2 - cropWindowY1);
                croppedImage = imageList[i].Copy();
                imageList[i] = croppedImage;
            }
            
            rectCrop.Opacity = 0;
          
            object result = null;

            //Run the MATLAB function
            matlab.Feval("CellDetect_CSharpFunction", 1, out result, imageFolderPath, roundLimit, cellAreaMinimum, cellFudgeUpperBound, cellFudgeLowerBound, cropWindowX1, cropWindowY1, cropWindowX2, cropWindowY2, maxDistanceMoved, maxTrackStrikes, minNumberTracks);

            object[] res = result as object[];

            double[,] cellArray = (double[,])res[0]; // Get the 2d array of cell num/pic num/x location/y location

            // Read the values from the 2D array and plot them on top of the image
            int circleRadius = 2; //radius of the circles in the plot
            int circleThickness = 2;
            int lineThickness = 2;
            Bgr cellColour = new Bgr(System.Drawing.Color.Black);

            //generate random line colours for each different tracked cell
            Random random = new Random();
            Bgr lineColour = new Bgr(random.Next(256), random.Next(256), random.Next(256));
            
            int imageNum = 1;
            foreach ( var cellImage in imageList)
            {
                for ( int i = 0; i < cellArray.GetLength(0); i++ )
                {
                    if (cellArray[i,1] <= imageNum) //Draw the tracked points only up to the picture number in the series
                    {
                        //Draw a circle at the indicated spot
                        float centerX = (float)cellArray[i, 2];
                        float centerY = (float)cellArray[i, 3];
                        System.Drawing.PointF center = new System.Drawing.PointF(centerX, centerY);
                        CircleF circle = new CircleF(center, circleRadius);

                        cellImage.Draw(circle, cellColour, circleThickness);

                        if (i >= 1 && cellArray[i, 0] == cellArray[i - 1, 0]) //draw a connecting line between two points of the same tracked cell
                        {
                            System.Drawing.PointF prevCenter = new System.Drawing.PointF((float)cellArray[i - 1, 2], (float)cellArray[i - 1, 3]);
                            LineSegment2DF line = new LineSegment2DF(prevCenter, center);
                            cellImage.Draw(line, lineColour, lineThickness);
                        }
                        else
                        {
                            lineColour = new Bgr(random.Next(256), random.Next(256), random.Next(256));
                        }
                    }
                    
                }
                imageNum++;
            }

            updateImage();
            btnRemoveTrack.IsEnabled = true;

            //----TRY TO RUN IT AS A COMPILED DLL FOR SPEEED: Delayed for now just running MLapp in beginning of program---


            //AutoCellTrackerMatlab obj = null;
            //MWNumericArray output = null;
            //MWArray[] result = null;

            //try
            //{
            //    obj = new AutoCellTrackerMatlab();

            //    result = obj.CellDetect_CSharpFunction(2, imageFolderPath, roundLimit, cellAreaMinimum, cellFudgeUpperBound, cellFudgeLowerBound, cropWindowX1, cropWindowY1, cropWindowX2, cropWindowY2);
            //    output = (MWNumericArray)result[0];
            //    Console.WriteLine("dll output: " + output);
            //}
            //catch
            //{
            //    throw;
            //}

        }

        private void btnTrackSettings_Click(object sender, RoutedEventArgs e)
        {
            flyoutTrackSettings.IsOpen = !flyoutTrackSettings.IsOpen;
        }

        private void btnApplyTrackSettings_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                parameters.roundLimit = double.Parse(textBoxRoundLimit.Text);
                parameters.cellAreaMinimum = double.Parse(textBoxCellAreaMinimum.Text);
                parameters.cellFudgeLowerBound = double.Parse(textBoxCellFudgeLower.Text);
                parameters.cellFudgeUpperBound = double.Parse(textBoxCellFudgeUpper.Text);
                parameters.maxDistanceMoved = int.Parse(textBoxMaxDistancePerFrame.Text);
                parameters.maxTrackStrikes = int.Parse(textBoxMaxLostTracks.Text);
                parameters.minNumberTracks = int.Parse(textBoxMinNumTracks.Text);
                parameters.cropWindowX1 = int.Parse(textBoxCropX1.Text);
                parameters.cropWindowY1 = int.Parse(textBoxCropY1.Text);
                parameters.cropWindowX2 = int.Parse(textBoxCropX2.Text);
                parameters.cropWindowY2 = int.Parse(textBoxCropY2.Text);
                
            }
            catch (FormatException ex)
            {
                MessageBox.Show("Error parsing values:\n" + ex);
            }

        }

        //Parameters that are used to pass to the matlab program. Determines the settings of the image processing code
        public class Parameters
        {
            public double roundLimit { get; set; }
            public double cellAreaMinimum { get; set; }
            public double cellFudgeUpperBound { get; set; }
            public double cellFudgeLowerBound { get; set; }
            public int maxDistanceMoved { get; set; }
            public int maxTrackStrikes { get; set; }
            public int minNumberTracks { get; set; }
            public int cropWindowX1 { get; set; }
            public int cropWindowY1 { get; set; }
            public int cropWindowX2 { get; set; }
            public int cropWindowY2 { get; set; }

            //Default constructor
            public Parameters()
            {   
                //Default values     
                roundLimit = 0.35;
                cellAreaMinimum = 500;
                cellFudgeUpperBound = 5;
                cellFudgeLowerBound = 0.5;
                maxDistanceMoved = 50;
                maxTrackStrikes = 2;
                minNumberTracks = 4;

                //default cropping window for the software on the microscope "Donatello"
                cropWindowX1 = 0;
                cropWindowY1 = 0;
                cropWindowX2 = 1393;
                cropWindowY2 = 1041;

            }

        }

        /// <summary>
        /// Delete a GDI object
        /// </summary>
        /// <param name="o">The poniter to the GDI object to be deleted</param>
        /// <returns></returns>
        [DllImport("gdi32")]
        private static extern int DeleteObject(IntPtr o);

        /// <summary>
        /// Convert an IImage to a WPF BitmapSource. The result can be used in the Set Property of Image.Source
        /// </summary>
        /// <param name="image">The Emgu CV Image</param>
        /// <returns>The equivalent BitmapSource</returns>
        public static BitmapSource ToBitmapSource(IImage image)
        {
            using (System.Drawing.Bitmap source = image.Bitmap)
            {
                IntPtr ptr = source.GetHbitmap(); //obtain the Hbitmap

                BitmapSource bs = System.Windows.Interop.Imaging.CreateBitmapSourceFromHBitmap(
                    ptr,
                    IntPtr.Zero,
                    Int32Rect.Empty,
                    System.Windows.Media.Imaging.BitmapSizeOptions.FromEmptyOptions());

                DeleteObject(ptr); //release the HBitmap
                return bs;
            }
        }

        /// <summary>
        /// Scroll through next/previous images on left/right arrow key press. NOT CURRENTLY WORKING
        /// </summary>
        private void imageDisplay_KeyDown(object sender, KeyEventArgs e)
        {
            Console.WriteLine("imageDisplay key down");
            if (e.Key == Key.Left)
            {
                prevImage();
            }
                
            else if (e.Key == Key.Right)
                nextImage();
        }

        private void borderImage_KeyDown(object sender, KeyEventArgs e)
        {
            Console.WriteLine("border key down");
            if (e.Key == Key.Left)
                prevImage();
            else if (e.Key == Key.Right)
                nextImage();
        }

        private void btnShowCropBox_Click(object sender, RoutedEventArgs e)
        {
            rectCrop.Opacity = 100;

            double userCropWidth = double.Parse(textBoxCropX2.Text) - double.Parse(textBoxCropX1.Text);
            double userCropHeight = double.Parse(textBoxCropY2.Text) - double.Parse(textBoxCropY1.Text);

            rectCrop.Width = (userCropWidth / imageList[currentImage].Width * imageDisplay.ActualWidth);
            rectCrop.Height = (userCropHeight / imageList[currentImage].Height * imageDisplay.ActualHeight);

            Console.WriteLine("Width: " + rectCrop.Width);
            Console.WriteLine("Height " + rectCrop.Height);

        }

        //Remove tracks from displayed image
        private void btnRemoveTrack_Click(object sender, RoutedEventArgs e)
        {
            //re-load tracks from imageListCopy
            imageList.Clear();
            imageList.TrimExcess();
            foreach (var image in imageListCopy)
            {
                imageList.Add(image);
            }
            updateImage();
        }
    }
}
