Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Jhon Emil\.gemini\antigravity-ide\brain\9a97663b-f4bc-4f1b-9342-3caf60b6f3eb\nitpliks_icon_clean_1791333287667.jpg"
$baseDir = "c:\Personal Project\video_player\android\app\src\main\res"

$sizes = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

$srcImg = [System.Drawing.Image]::FromFile($srcPath)

foreach ($folder in $sizes.Keys) {
    $dim = $sizes[$folder]
    $destFolder = Join-Path $baseDir $folder
    if (-not (Test-Path $destFolder)) {
        New-Item -ItemType Directory -Force -Path $destFolder | Out-Null
    }
    $destFile = Join-Path $destFolder "ic_launcher.png"
    
    $destBmp = New-Object System.Drawing.Bitmap($dim, $dim)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($srcImg, 0, 0, $dim, $dim)
    $g.Dispose()

    $destBmp.Save($destFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Output "Generated: $destFile (${dim}x${dim})"
}

$srcImg.Dispose()
Write-Output "All mipmap icons generated successfully!"
