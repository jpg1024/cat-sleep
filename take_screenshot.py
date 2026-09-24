import time
time.sleep(1)

import subprocess
subprocess.run([
    'powershell', '-noprofile', '-command',
    'Add-Type -AssemblyName System.Windows.Forms,System.Drawing;'
    '$s = [System.Windows.Forms.Screen]::PrimaryScreen;'
    '$bmp = New-Object System.Drawing.Bitmap($s.Bounds.Width,$s.Bounds.Height);'
    '$g = [System.Drawing.Graphics]::FromImage($bmp);'
    '$g.CopyFromScreen($s.Bounds.Location,[System.Drawing.Point]::Empty,$s.Bounds.Size);'
    '$bmp.Save("D:\\PGitCode\\cat_sleep\\screenshot.png");'
    '$g.Dispose();$bmp.Dispose()'
])
print("Screenshot saved")
