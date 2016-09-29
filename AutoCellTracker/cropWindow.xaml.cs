using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using Emgu.CV;
using Emgu.Util;
using Emgu.CV.Structure;

namespace AutoCellTracker
{
    /// <summary>
    /// Interaction logic for cropWindow.xaml
    /// </summary>
    /// 
    public partial class cropWindow : Window
    {
        public cropWindow()
        {
            InitializeComponent();
        }

        //Show what will be cropped in a red rectangle in the main window. TODO: Edit for case where X1,Y1 != 0
        private void btnView_Click(object sender, RoutedEventArgs e)
        {
            MainWindow mainWindow = Application.Current.MainWindow as MainWindow;

            mainWindow.rectCrop.Opacity = 100;

            double userCropWidth = double.Parse(textX2.Text) - double.Parse(textX1.Text);
            double userCropHeight = double.Parse(textY2.Text) - double.Parse(textY1.Text);

            mainWindow.rectCrop.Width = (userCropWidth / mainWindow.imageList[mainWindow.currentImage].Width * mainWindow.imageDisplay.ActualWidth);
            mainWindow.rectCrop.Height = (userCropHeight / mainWindow.imageList[mainWindow.currentImage].Height * mainWindow.imageDisplay.ActualHeight);
        }

        //Crop all of the images in the imageList to the user entered parameters
        private void btnCrop_Click(object sender, RoutedEventArgs e)
        {
            /*
            imageList[currentImage].ROI = new System.Drawing.Rectangle(0, 0, 500, 500);
            Image<Bgr,Byte> croppedImage = new Image<Bgr,Byte>(500,500);
            croppedImage = imageList[currentImage].Copy();
            imageDisplay.Source = ToBitmapSource(croppedImage);
            */

            int X1 = int.Parse(textX1.Text);
            int Y1 = int.Parse(textY1.Text);
            int X2 = int.Parse(textX2.Text);
            int Y2 = int.Parse(textY2.Text);

            MainWindow mainWindow = Application.Current.MainWindow as MainWindow;

            for (int i = 0; i < mainWindow.numImages; i++)
            {
                mainWindow.imageList[i].ROI = new System.Drawing.Rectangle(X1, Y1, X2, Y2);
                Image<Bgr, byte> croppedImage = new Image<Bgr, Byte>(X2 - X1, Y2 - Y1);
                croppedImage = mainWindow.imageList[i].Copy();
                mainWindow.imageList[i] = croppedImage;
            }

            mainWindow.updateImage();
            mainWindow.rectCrop.Opacity = 0;
        }
    }
}
