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

namespace AutoCellTracker
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml 
    /// </summary>
    public partial class MainWindow : MetroWindow
    {
        int numImages = 0;
        int currentImage = 0;
        List<String> imageFilePath = new List<string>();
        //List<Emgu.CV.IImage> imageList = new List<Emgu.CV.IImage>();
        List<Emgu.CV.Image<Bgr,Byte>> imageList = new List<Emgu.CV.Image<Bgr, Byte>>();

        public MainWindow()
        {
            InitializeComponent();
        }

        private void selectFolder_Click(object sender, RoutedEventArgs e)
        {
            //Select the folder which all the images are kept
            //FolderBrowserDialog folderBrowserDialog = new FolderBrowserDialog();
            //DialogResult result = folderBrowserDialog.ShowDialog();

            VistaFolderBrowserDialog dialog = new VistaFolderBrowserDialog();
            dialog.Description = "Navigate to folder containing images";
            dialog.UseDescriptionForTitle = true; // This applies to the Vista style dialog only, not the old dialog.
            if (!VistaFolderBrowserDialog.IsVistaFolderDialogSupported)
                MessageBox.Show(this, "Because you are not using Windows Vista or later, the regular folder browser dialog will be used. Please use Windows Vista to see the new dialog.", "Sample folder browser dialog");
            if ((bool)dialog.ShowDialog(this))
                folderTextBlock.Text = dialog.SelectedPath;

            DirectoryInfo directoryInfo = new DirectoryInfo(dialog.SelectedPath);

            //Searches folder for bitmap (.bmp) files. Loads an array with file names, and counts the total number of bmp files
            numImages = 0;
            currentImage = 0;

            //TODO: Add support for other image formats
            foreach (var imageFile in directoryInfo.GetFiles("*.bmp"))
            {
                imageFilePath.Add(imageFile.FullName);
                numImages++;
            }

            //Load images - create a list of EmguCV IImages
            for (int i = 0; i < numImages; i++)
            {
                Image<Bgr, Byte> image = new Image<Bgr, Byte>((imageFilePath[i]));
                imageList.Add(image);
            }

            if (numImages > 0)
            {
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
            rectCrop.Opacity = 100;

            //rectCrop.Height = (double.Parse(cropWindow.textX1.Text))/100;
            rectCrop.Height = 200;


            /*
            imageList[currentImage].ROI = new System.Drawing.Rectangle(0, 0, 500, 500);
            Image<Bgr,Byte> croppedImage = new Image<Bgr,Byte>(500,500);
            croppedImage = imageList[currentImage].Copy();
            imageDisplay.Source = ToBitmapSource(croppedImage);
            */
        }

        private void btnSave_Click(object sender, RoutedEventArgs e)
        {

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


    }
}
