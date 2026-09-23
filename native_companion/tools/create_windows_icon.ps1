param(
  [string]$Source,
  [string]$Destination
)

$ErrorActionPreference = 'Stop'
$toolDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$companionRoot = Split-Path -Parent $toolDirectory

if (-not $Source) {
  $Source = Join-Path $companionRoot 'resources\oj_problem_companion.png'
}
if (-not $Destination) {
  $Destination = Join-Path $companionRoot 'resources\oj_problem_companion.ico'
}

$Source = [System.IO.Path]::GetFullPath($Source)
$Destination = [System.IO.Path]::GetFullPath($Destination)
if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
  throw "Icon source does not exist: $Source"
}

Add-Type -AssemblyName System.Drawing

$sizes = @(16, 24, 32, 48, 64, 128, 256)
$sourceBitmap = [System.Drawing.Bitmap]::FromFile($Source)
$frames = [System.Collections.Generic.List[byte[]]]::new()

try {
  foreach ($size in $sizes) {
    $bitmap = [System.Drawing.Bitmap]::new(
      $size,
      $size,
      [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($sourceBitmap, 0, 0, $size, $size)
      } finally {
        $graphics.Dispose()
      }

      $stream = [System.IO.MemoryStream]::new()
      try {
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        $frames.Add($stream.ToArray())
      } finally {
        $stream.Dispose()
      }
    } finally {
      $bitmap.Dispose()
    }
  }
} finally {
  $sourceBitmap.Dispose()
}

$destinationDirectory = Split-Path -Parent $Destination
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
$fileStream = [System.IO.File]::Open(
  $Destination,
  [System.IO.FileMode]::Create,
  [System.IO.FileAccess]::Write,
  [System.IO.FileShare]::None
)
$writer = [System.IO.BinaryWriter]::new($fileStream)

try {
  $writer.Write([uint16]0)
  $writer.Write([uint16]1)
  $writer.Write([uint16]$frames.Count)

  $offset = 6 + (16 * $frames.Count)
  for ($index = 0; $index -lt $frames.Count; $index++) {
    $size = $sizes[$index]
    $writer.Write([byte]($(if ($size -eq 256) { 0 } else { $size })))
    $writer.Write([byte]($(if ($size -eq 256) { 0 } else { $size })))
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]$frames[$index].Length)
    $writer.Write([uint32]$offset)
    $offset += $frames[$index].Length
  }

  foreach ($frame in $frames) {
    $writer.Write($frame)
  }
} finally {
  $writer.Dispose()
}

Write-Host "Windows icon generated: $Destination"
