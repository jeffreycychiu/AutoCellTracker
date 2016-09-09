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
using MahApps.Metro.Controls;
using Microsoft.Win32;
using Ookii.Dialogs.Wpf;

namespace AutoCellTracker
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : MetroWindow
    {
        List<String> imageFilePath = new List<string>();
        int numImages = 0;

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
            foreach (var imageFile in directoryInfo.GetFiles("*.bmp"))
            {
                imageFilePath.Add(imageFile.FullName);
                numImages++;
            }

            numImagesTextBlock.Text = "Image: 1/" + numImages.ToString();

        }
    }
}
