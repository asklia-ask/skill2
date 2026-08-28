param(
    [Parameter(Mandatory = $true)]
    [string]$PhotoPath,

    [Parameter(Mandatory = $true)]
    [string]$ModelPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$ModelBounds,

    [Parameter(Mandatory = $true)]
    [string]$ModelCrop,

    [ValidateRange(0.0, 1.0)]
    [double]$PhotoFocusX = 0.5,

    [ValidateRange(0.0, 1.0)]
    [double]$PhotoFocusY = 0.5,

    [ValidateSet('auto', 'height', 'width')]
    [string]$FitBy = 'auto'
)

Add-Type -AssemblyName System.Drawing

$drawingAssemblies = @(
    [System.Drawing.Bitmap].Assembly.Location,
    [System.Drawing.Color].Assembly.Location
) | Select-Object -Unique

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;

public static class LocalLayoutKeyer
{
    private static Color AverageAt(Bitmap bitmap, int x, int y)
    {
        long r = 0, g = 0, b = 0;
        int count = 0;
        for (int oy = -3; oy <= 3; oy++)
        {
            int py = Math.Max(0, Math.Min(bitmap.Height - 1, y + oy));
            for (int ox = -3; ox <= 3; ox++)
            {
                int px = Math.Max(0, Math.Min(bitmap.Width - 1, x + ox));
                Color c = bitmap.GetPixel(px, py);
                r += c.R; g += c.G; b += c.B; count++;
            }
        }
        return Color.FromArgb((int)(r / count), (int)(g / count), (int)(b / count));
    }

    public static Bitmap Extract(Bitmap source, Rectangle crop, int topSampleY, int bottomSampleY)
    {
        Bitmap output = new Bitmap(crop.Width, crop.Height, PixelFormat.Format32bppArgb);
        Color[] top = new Color[crop.Width];
        Color[] bottom = new Color[crop.Width];
        for (int x = 0; x < crop.Width; x++)
        {
            int sx = crop.X + x;
            top[x] = AverageAt(source, sx, topSampleY);
            bottom[x] = AverageAt(source, sx, bottomSampleY);
        }

        for (int y = 0; y < crop.Height; y++)
        {
            int sy = crop.Y + y;
            double t = (sy - topSampleY) / (double)Math.Max(1, bottomSampleY - topSampleY);
            t = Math.Max(0.0, Math.Min(1.0, t));
            for (int x = 0; x < crop.Width; x++)
            {
                Color pixel = source.GetPixel(crop.X + x, sy);
                double er = top[x].R + (bottom[x].R - top[x].R) * t;
                double eg = top[x].G + (bottom[x].G - top[x].G) * t;
                double eb = top[x].B + (bottom[x].B - top[x].B) * t;
                double dr = pixel.R - er;
                double dg = pixel.G - eg;
                double db = pixel.B - eb;
                double difference = Math.Sqrt(dr * dr + dg * dg + db * db);

                const double low = 3.0;
                const double high = 16.0;
                double normalized = (difference - low) / (high - low);
                normalized = Math.Max(0.0, Math.Min(1.0, normalized));
                normalized = normalized * normalized * (3.0 - 2.0 * normalized);

                int edge = Math.Min(Math.Min(x, crop.Width - 1 - x), Math.Min(y, crop.Height - 1 - y));
                double edgeAlpha = Math.Min(1.0, edge / 24.0);
                int alpha = (int)Math.Round(255.0 * normalized * edgeAlpha);
                output.SetPixel(x, y, Color.FromArgb(alpha, pixel.R, pixel.G, pixel.B));
            }
        }
        return output;
    }
}
'@ -ReferencedAssemblies $drawingAssemblies

$ErrorActionPreference = 'Stop'

$CanvasWidth = 1200
$CanvasHeight = 1600
$PanelHeight = 800

function Get-CornerColor {
    param([System.Drawing.Bitmap]$Bitmap)

    $samples = @(
        $Bitmap.GetPixel(8, 8),
        $Bitmap.GetPixel($Bitmap.Width - 9, 8),
        $Bitmap.GetPixel(8, $Bitmap.Height - 9),
        $Bitmap.GetPixel($Bitmap.Width - 9, $Bitmap.Height - 9)
    )
    $r = [int](($samples | Measure-Object -Property R -Average).Average)
    $g = [int](($samples | Measure-Object -Property G -Average).Average)
    $b = [int](($samples | Measure-Object -Property B -Average).Average)
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

function Fill-ModelBackground {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Bitmap]$Model
    )

    $edgeColor = Get-CornerColor -Bitmap $Model
    $sampleY = [Math]::Max(8, [int][Math]::Round($Model.Height * 0.10))
    $centerSample = $Model.GetPixel([int]($Model.Width / 2), $sampleY)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(-250, -120, 1700, 1040)
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $brush.CenterPoint = [System.Drawing.PointF]::new(600, 385)
    $brush.CenterColor = $centerSample
    $brush.SurroundColors = @($edgeColor)
    $Graphics.FillRectangle($brush, 0, $PanelHeight, $CanvasWidth, $PanelHeight)
    $brush.Dispose()
    $path.Dispose()
}

function Draw-ImageHighQuality {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Image]$Image,
        [System.Drawing.Rectangle]$Destination,
        [System.Drawing.Rectangle]$Source
    )

    $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Graphics.DrawImage($Image, $Destination, $Source.X, $Source.Y, $Source.Width, $Source.Height, [System.Drawing.GraphicsUnit]::Pixel)
}

function Add-KeyedCrop {
    param(
        [System.Drawing.Bitmap]$Canvas,
        [System.Drawing.Bitmap]$Source,
        [System.Drawing.Rectangle]$Crop,
        [System.Drawing.Rectangle]$Destination,
        [int]$TopSampleY,
        [int]$BottomSampleY
    )

    $cutout = [LocalLayoutKeyer]::Extract($Source, $Crop, $TopSampleY, $BottomSampleY)
    $scaled = New-Object System.Drawing.Bitmap($Destination.Width, $Destination.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
    $scaledGraphics.Clear([System.Drawing.Color]::Transparent)
    Draw-ImageHighQuality -Graphics $scaledGraphics -Image $cutout -Destination ([System.Drawing.Rectangle]::new(0, 0, $Destination.Width, $Destination.Height)) -Source ([System.Drawing.Rectangle]::new(0, 0, $cutout.Width, $cutout.Height))
    $scaledGraphics.Dispose()

    $canvasGraphics = [System.Drawing.Graphics]::FromImage($Canvas)
    $canvasGraphics.DrawImage($scaled, $Destination.X, $Destination.Y, $Destination.Width, $Destination.Height)
    $canvasGraphics.Dispose()
    $scaled.Dispose()
    $cutout.Dispose()
}

function New-LayoutTest {
    param(
        [string]$PhotoPath,
        [string]$ModelPath,
        [string]$OutputPath,
        [double]$PhotoFocusX,
        [double]$PhotoFocusY,
        [System.Drawing.Rectangle]$ModelBounds,
        [System.Drawing.Rectangle]$ModelCrop,
        [ValidateSet('auto', 'height', 'width')][string]$FitBy
    )

    $photo = [System.Drawing.Bitmap]::FromFile($PhotoPath)
    $model = [System.Drawing.Bitmap]::FromFile($ModelPath)
    $canvas = New-Object System.Drawing.Bitmap($CanvasWidth, $CanvasHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)

    $background = Get-CornerColor -Bitmap $model
    $graphics.Clear($background)
    Fill-ModelBackground -Graphics $graphics -Model $model

    $targetRatio = $CanvasWidth / [double]$PanelHeight
    $sourceRatio = $photo.Width / [double]$photo.Height
    if ($sourceRatio -lt $targetRatio) {
        $cropWidth = $photo.Width
        $cropHeight = [int][Math]::Round($photo.Width / $targetRatio)
        $cropX = 0
        $focusCenter = [int][Math]::Round($photo.Height * $PhotoFocusY)
        $cropY = [Math]::Max(0, [Math]::Min($photo.Height - $cropHeight, $focusCenter - [int]($cropHeight / 2)))
    }
    else {
        $cropHeight = $photo.Height
        $cropWidth = [int][Math]::Round($photo.Height * $targetRatio)
        $focusCenter = [int][Math]::Round($photo.Width * $PhotoFocusX)
        $cropX = [Math]::Max(0, [Math]::Min($photo.Width - $cropWidth, $focusCenter - [int]($cropWidth / 2)))
        $cropY = 0
    }
    $photoCrop = [System.Drawing.Rectangle]::new($cropX, $cropY, $cropWidth, $cropHeight)
    Draw-ImageHighQuality -Graphics $graphics -Image $photo -Destination ([System.Drawing.Rectangle]::new(0, 0, $CanvasWidth, $PanelHeight)) -Source $photoCrop
    $graphics.Dispose()

    if ($FitBy -eq 'height') {
        $scale = 480.0 / $ModelBounds.Height
    }
    elseif ($FitBy -eq 'width') {
        $scale = 720.0 / $ModelBounds.Width
    }
    else {
        $scale = [Math]::Min(720.0 / $ModelBounds.Width, 480.0 / $ModelBounds.Height)
    }

    $targetObjectWidth = [int][Math]::Round($ModelBounds.Width * $scale)
    $targetObjectHeight = [int][Math]::Round($ModelBounds.Height * $scale)
    $targetObjectX = [int][Math]::Round(($CanvasWidth - $targetObjectWidth) / 2.0)
    $targetObjectY = [int][Math]::Round(($PanelHeight - $targetObjectHeight) / 2.0)

    $cropScaleX = $targetObjectWidth / [double]$ModelBounds.Width
    $cropScaleY = $targetObjectHeight / [double]$ModelBounds.Height
    $targetCropWidth = [int][Math]::Round($ModelCrop.Width * $cropScaleX)
    $targetCropHeight = [int][Math]::Round($ModelCrop.Height * $cropScaleY)
    $objectOffsetX = ($ModelBounds.X - $ModelCrop.X) * $cropScaleX
    $objectOffsetY = ($ModelBounds.Y - $ModelCrop.Y) * $cropScaleY
    $targetCropX = [int][Math]::Round($targetObjectX - $objectOffsetX)
    $targetCropY = [int][Math]::Round($PanelHeight + $targetObjectY - $objectOffsetY)

    $topSampleY = [Math]::Max(4, $ModelBounds.Y - 55)
    $bottomSampleY = [Math]::Min($model.Height - 5, $ModelBounds.Bottom + 55)
    Add-KeyedCrop -Canvas $canvas -Source $model -Crop $ModelCrop -Destination ([System.Drawing.Rectangle]::new($targetCropX, $targetCropY, $targetCropWidth, $targetCropHeight)) -TopSampleY $topSampleY -BottomSampleY $bottomSampleY

    $outputDirectory = Split-Path -Parent $OutputPath
    if ($outputDirectory) {
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    }
    $canvas.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $left = 100.0 * $targetObjectX / $CanvasWidth
    $right = 100.0 * ($CanvasWidth - $targetObjectX - $targetObjectWidth) / $CanvasWidth
    $top = 100.0 * $targetObjectY / $PanelHeight
    $bottom = 100.0 * ($PanelHeight - $targetObjectY - $targetObjectHeight) / $PanelHeight
    $centerX = ($targetObjectX + $targetObjectWidth / 2.0) - $CanvasWidth / 2.0
    $centerY = ($targetObjectY + $targetObjectHeight / 2.0) - $PanelHeight / 2.0

    $photo.Dispose()
    $model.Dispose()
    $canvas.Dispose()

    return [pscustomobject]@{
        Output = [System.IO.Path]::GetFullPath($outputPath)
        PhotoCrop = "${cropX},${cropY},${cropWidth},${cropHeight}"
        ObjectBox = "${targetObjectX},${targetObjectY},${targetObjectWidth},${targetObjectHeight}"
        LeftPct = [Math]::Round($left, 2)
        RightPct = [Math]::Round($right, 2)
        TopPct = [Math]::Round($top, 2)
        BottomPct = [Math]::Round($bottom, 2)
        CenterXPx = [Math]::Round($centerX, 2)
        CenterYPx = [Math]::Round($centerY, 2)
    }
}

foreach ($path in @($PhotoPath, $ModelPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Input file not found: $path"
    }
}

function ConvertTo-Rectangle {
    param(
        [string]$Value,
        [string]$Name
    )

    $parts = @($Value.Split(',') | ForEach-Object { [int]$_.Trim() })
    if ($parts.Count -ne 4 -or $parts[2] -le 0 -or $parts[3] -le 0) {
        throw "$Name must be x,y,width,height with positive width and height."
    }
    [System.Drawing.Rectangle]::new($parts[0], $parts[1], $parts[2], $parts[3])
}

$boundsRectangle = ConvertTo-Rectangle -Value $ModelBounds -Name 'ModelBounds'
$cropRectangle = ConvertTo-Rectangle -Value $ModelCrop -Name 'ModelCrop'

$modelProbe = [System.Drawing.Image]::FromFile($ModelPath)
try {
    $imageRectangle = [System.Drawing.Rectangle]::new(0, 0, $modelProbe.Width, $modelProbe.Height)
    if (-not $imageRectangle.Contains($boundsRectangle)) {
        throw 'ModelBounds must stay inside the model image.'
    }
    if (-not $imageRectangle.Contains($cropRectangle)) {
        throw 'ModelCrop must stay inside the model image.'
    }
    if (-not $cropRectangle.Contains($boundsRectangle)) {
        throw 'ModelCrop must fully contain ModelBounds.'
    }
}
finally {
    $modelProbe.Dispose()
}

$result = New-LayoutTest -PhotoPath $PhotoPath -ModelPath $ModelPath -OutputPath $OutputPath -PhotoFocusX $PhotoFocusX -PhotoFocusY $PhotoFocusY -ModelBounds $boundsRectangle -ModelCrop $cropRectangle -FitBy $FitBy
$result | ConvertTo-Json -Depth 3

