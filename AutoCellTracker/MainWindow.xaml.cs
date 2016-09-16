using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.IO;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Forms;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
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
                System.Windows.MessageBox.Show(this, "Because you are not using Windows Vista or later, the regular folder browser dialog will be used. Please use Windows Vista to see the new dialog.", "Sample folder browser dialog");
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

            if(numImages > 0)
            {
                updateImage();
                btnNext.IsEnabled = true;
                btnPrev.IsEnabled = true;
            }

        }

        public void updateImage()
        {
            //create new images using the EmguCV
            Image<Bgr, Byte> image = new Image<Bgr, Byte>((imageFilePath[currentImage]));
            imageDisplay.Image = image;
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

        //Rectangular crop all the images in the series. Uses a user selected box (mouse) or entered coordinates (x1,y1 to x2,y2)
        private void btnCrop_Click(object sender, RoutedEventArgs e)
        {
            //close flyout for ease of selecting the area
            flyoutSettings.IsOpen = false;


        }
    }
}
