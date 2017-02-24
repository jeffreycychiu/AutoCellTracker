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

namespace AutoCellTracker
{
    /// <summary>
    /// Interaction logic for trackSettingsWindow.xaml
    /// </summary>
    public partial class trackSettingsWindow : Window
    {
        public trackSettingsWindow()
        {
            InitializeComponent();
        }

        private void btnApplyTrackSettings_Click(object sender, RoutedEventArgs e)
        {
            double roundLimit = double.Parse(textBlockRoundLimit.Text);
            double cellAreaMinimum = double.Parse(textBlockCellAreaMinimum.Text);
            double cellFudgeUpper = double.Parse(textBlockCellFudgeUpper.Text);
            double cellFudgeLower = double.Parse(textBlockCellFudgeLower.Text);

            //MainWindow.roundLimit = roundLimit;
        }
    }
}
