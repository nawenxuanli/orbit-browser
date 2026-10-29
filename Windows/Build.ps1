param([switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$out = Join-Path $root 'out'
$publish = Join-Path $out 'app'
New-Item -ItemType Directory -Force $out | Out-Null
dotnet publish "$root/Orbit.Windows.csproj" -c Release -r win-x64 --self-contained true -o $publish
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
$p = Start-Process "$publish/Orbit.exe" -ArgumentList '--self-test' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'Address and domain boundary tests failed' }
if ($SmokeTest) {
 $report = Join-Path $out 'verification'
 New-Item -ItemType Directory -Force $report | Out-Null
 $p = Start-Process "$publish/Orbit.exe" -ArgumentList @('--smoke-test', "`"$report`"") -PassThru
 if (-not $p.WaitForExit(90000)) { $p.Kill(); throw 'Windows browser smoke test timed out' }
 if ($p.ExitCode -ne 0 -or -not (Test-Path "$report/smoke-test.txt")) { Get-Content "$report/failure.txt" -ErrorAction SilentlyContinue; throw 'Windows browser smoke test failed' }
 Get-Content "$report/smoke-test.txt"
}
Add-Type -AssemblyName System.Drawing
$assets = Join-Path $publish 'Assets'
New-Item -ItemType Directory -Force $assets | Out-Null
foreach ($entry in @(@('StoreLogo',50),@('Square44x44Logo',44),@('Square150x150Logo',150))) {
 $size = [int]$entry[1]
 $bmp = New-Object System.Drawing.Bitmap $size,$size
 $g = [System.Drawing.Graphics]::FromImage($bmp)
 $g.SmoothingMode = 'AntiAlias'
 $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#1B2026'))
 $pen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#42C4DE')),([single]($size*0.045))
 foreach ($offset in @(0.34,0.5,0.66)) {
  $points = New-Object 'System.Drawing.PointF[]' 4
  $points[0] = New-Object System.Drawing.PointF ([single]($size*0.2)),([single]($size*$offset))
  $points[1] = New-Object System.Drawing.PointF ([single]($size*0.4)),([single]($size*($offset+0.12)))
  $points[2] = New-Object System.Drawing.PointF ([single]($size*0.6)),([single]($size*($offset-0.12)))
  $points[3] = New-Object System.Drawing.PointF ([single]($size*0.8)),([single]($size*$offset))
  $g.DrawCurve($pen,$points)
 }
 $bmp.Save((Join-Path $assets ($entry[0]+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
 $pen.Dispose();$g.Dispose();$bmp.Dispose()
}
Copy-Item "$root/Package.appxmanifest" "$publish/AppxManifest.xml" -Force
$sdk = Get-ChildItem "${env:ProgramFiles(x86)}/Windows Kits/10/bin/*/x64/makeappx.exe" | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $sdk) { throw 'Windows SDK MakeAppx was not found' }
& $sdk.FullName pack /d $publish /p "$out/Orbit-Browser-0.3.0-x64.msix" /o
if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed' }
Write-Output 'MSIX created with the Partner Center identity. Unsigned package is for Store submission; Microsoft signs certified packages.'
