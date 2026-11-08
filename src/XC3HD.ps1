# ==========================================================================
#  XC3 HD Texturen - KI-Upscaling für Xenoblade Chronicles 3 (Eden)
#  Nur fuer den eigenen Gebrauch mit einem Dump der eigenen Spielkopie.
#
#  Werkzeuge: XbTool (AlexCSDev), xc3_tex / xc3_lib (ScanMountGoat),
#             xcnx-file-loader (roccodev), Upscayl (lokal installiert),
#             xc3_maptex (eigenes Karten-Werkzeug auf Basis von xc3_lib)
# ==========================================================================

# Bild-Helfer (C#, System.Drawing): Rand auffuellen, Alpha trennen, sauber skalieren, Vergleichsbild
$Xc3ImgSource = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Xc3Img
{
    static byte[] Read(Bitmap b, out int stride)
    {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = d.Stride;
        var buf = new byte[d.Stride * b.Height];
        Marshal.Copy(d.Scan0, buf, 0, buf.Length);
        b.UnlockBits(d);
        return buf;
    }
    static Bitmap Make(byte[] buf, int w, int h)
    {
        var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        var d = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(buf, 0, d.Scan0, buf.Length);
        b.UnlockBits(d);
        return b;
    }
    static Bitmap Load(string path)
    {
        using (var tmp = new Bitmap(path)) { return tmp.Clone(new Rectangle(0, 0, tmp.Width, tmp.Height), PixelFormat.Format32bppArgb); }
    }

    // Normal-Map-Erkennung: Mittelwert um (128,128,>190)
    public static bool LooksLikeNormalMap(string png)
    {
        using (var b = Load(png))
        {
            int stride; var p = Read(b, out stride);
            long r = 0, g = 0, bl = 0, n = 0;
            int step = Math.Max(1, Math.Min(b.Width, b.Height) / 64);
            for (int y = 0; y < b.Height; y += step)
                for (int x = 0; x < b.Width; x += step)
                {
                    int i = y * stride + x * 4;
                    bl += p[i]; g += p[i + 1]; r += p[i + 2]; n++;
                }
            double mr = r / (double)n, mg = g / (double)n, mb = bl / (double)n;
            return mb > 190 && Math.Abs(mr - 128) < 30 && Math.Abs(mg - 128) < 30;
        }
    }

    // RGB mit umlaufendem Rand (wrap) auffuellen -> keine Naehte bei Kacheltexturen.
    // Gibt true zurueck, wenn die Textur Transparenz hat (Alpha wird separat gespeichert).
    public static bool Prepare(string png, string paddedOut, string alphaOut, int pad)
    {
        using (var b = Load(png))
        {
            int w = b.Width, h = b.Height, stride;
            var src = Read(b, out stride);
            int W = w + 2 * pad, H = h + 2 * pad;
            var dst = new byte[W * H * 4];
            bool hasAlpha = false;
            for (int y = 0; y < H; y++)
            {
                int sy = ((y - pad) % h + h) % h;
                for (int x = 0; x < W; x++)
                {
                    int sx = ((x - pad) % w + w) % w;
                    int si = sy * stride + sx * 4, di = (y * W + x) * 4;
                    dst[di] = src[si]; dst[di + 1] = src[si + 1]; dst[di + 2] = src[si + 2]; dst[di + 3] = 255;
                    if (src[si + 3] < 250) hasAlpha = true;
                }
            }
            using (var o = Make(dst, W, H)) o.Save(paddedOut, ImageFormat.Png);
            if (hasAlpha)
            {
                var a = new byte[w * h * 4];
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                    {
                        byte v = src[y * stride + x * 4 + 3]; int di = (y * w + x) * 4;
                        a[di] = v; a[di + 1] = v; a[di + 2] = v; a[di + 3] = 255;
                    }
                using (var o = Make(a, w, h)) o.Save(alphaOut, ImageFormat.Png);
            }
            return hasAlpha;
        }
    }

    static Bitmap Resize(Bitmap src, Rectangle srcRect, int w, int h)
    {
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(dst))
        using (var ia = new ImageAttributes())
        {
            g.CompositingMode = CompositingMode.SourceCopy;
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.SmoothingMode = SmoothingMode.HighQuality;
            ia.SetWrapMode(WrapMode.TileFlipXY);
            g.DrawImage(src, new Rectangle(0, 0, w, h), srcRect.X, srcRect.Y, srcRect.Width, srcRect.Height, GraphicsUnit.Pixel, ia);
        }
        return dst;
    }

    // KI-Ergebnis (4x, mit Rand) zuschneiden, sauber auf Zielgröße bringen, Alpha wieder einsetzen
    public static void Finish(string upPng, string alphaPng, int w, int h, int pad, int scale, int outW, int outH, string outPng)
    {
        using (var up = Load(upPng))
        using (var res = Resize(up, new Rectangle(pad * scale, pad * scale, w * scale, h * scale), outW, outH))
        {
            if (!string.IsNullOrEmpty(alphaPng))
            {
                using (var a = Load(alphaPng))
                using (var a2 = Resize(a, new Rectangle(0, 0, a.Width, a.Height), outW, outH))
                {
                    int s1, s2; var px = Read(res, out s1); var ap = Read(a2, out s2);
                    for (int y = 0; y < outH; y++)
                        for (int x = 0; x < outW; x++)
                            px[y * s1 + x * 4 + 3] = ap[y * s2 + x * 4];
                    using (var o = Make(px, outW, outH)) { o.Save(outPng, ImageFormat.Png); return; }
                }
            }
            res.Save(outPng, ImageFormat.Png);
        }
    }

    // Ausschnitt fuer den Modell-Vergleich (mittig, quadratisch)
    public static void Crop(string png, string outPng, int size)
    {
        using (var b = Load(png))
        {
            int s = Math.Min(size, Math.Min(b.Width, b.Height));
            var r = new Rectangle((b.Width - s) / 2, (b.Height - s) / 2, s, s);
            using (var c = b.Clone(r, PixelFormat.Format32bppArgb)) c.Save(outPng, ImageFormat.Png);
        }
    }

    public static void Upscale(string png, string outPng, int w, int h)
    {
        using (var b = Load(png))
        using (var r = Resize(b, new Rectangle(0, 0, b.Width, b.Height), w, h)) r.Save(outPng, ImageFormat.Png);
    }

    // Vergleichsbild: Zeilen = Texturen, Spalten = Methoden
    public static void Sheet(string[] files, string[] colNames, int rows, int cols, int tile, string outPng)
    {
        int head = 46;
        using (var sheet = new Bitmap(cols * tile, rows * tile + head, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(sheet))
        using (var font = new Font("Segoe UI", 15, FontStyle.Bold))
        using (var fg = new SolidBrush(Color.White))
        {
            g.Clear(Color.FromArgb(18, 22, 28));
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            for (int c = 0; c < cols; c++) g.DrawString(colNames[c], font, fg, c * tile + 10, 10);
            for (int r = 0; r < rows; r++)
                for (int c = 0; c < cols; c++)
                {
                    string f = files[r * cols + c];
                    if (string.IsNullOrEmpty(f) || !System.IO.File.Exists(f)) continue;
                    using (var b = Load(f))
                    {
                        g.InterpolationMode = InterpolationMode.NearestNeighbor;
                        g.DrawImage(b, new Rectangle(c * tile, head + r * tile, tile, tile));
                    }
                }
            sheet.Save(outPng, ImageFormat.Png);
        }
    }
}
'@

# ==========================================================================
#  Engine: alles, was im Hintergrund laeuft (wird in der Oberflaeche und im
#  Arbeits-Runspace geladen). Erwartet: $Root (Arbeitsordner), optional $S (Sync)
# ==========================================================================
$Engine = {
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$TitleId  = "010074F013262000"
$ToolsDir = Join-Path $Root "tools"
$Extract  = Join-Path $Root "entpackt"
$WorkDir  = Join-Path $Root "arbeit"
$MapsDir  = Join-Path $Root "karten"
$ModName  = "XC3 HD Texturen"
$ModDir   = Join-Path $Root "mod\$ModName"
$CfgFile  = Join-Path $Root "xc3hd-einstellungen.json"
$LogFile  = Join-Path $Root "xc3hd.log"

# Alles, was sich hochskalieren laesst (Ordner im entpackten Spiel + Dateityp)
# NICHT: monolib\shader (Shader-Hilfstexturen, Groesse muss exakt bleiben -> schwarze Welt),
#        map\*.wimdo (anderes Format, xc3_tex kann es nicht lesen)
$Sources = [ordered]@{
    ch      = @{ Name = "Charaktere & Outfits";               Dir = "chr\ch";  Kind = "wimdo" }
    wp      = @{ Name = "Waffen";                             Dir = "chr\wp";  Kind = "wimdo" }
    en      = @{ Name = "Monster & Gegner";                   Dir = "chr\en";  Kind = "wimdo" }
    oj      = @{ Name = "Objekte";                            Dir = "chr\oj";  Kind = "wimdo" }
    bt      = @{ Name = "Kampf-Objekte";                      Dir = "chr\bt";  Kind = "wimdo" }
    menu    = @{ Name = "Menüs & UI (experimentell)"; Dir = "menu";    Kind = "wilay" }
}
$Categories = [ordered]@{}; foreach ($k in $Sources.Keys) { $Categories[$k] = $Sources[$k].Name }

# ---------------- Einstellungen ----------------
function Get-DefaultCfg {
    [ordered]@{
        EdenData     = (Join-Path $env:APPDATA "eden")
        UpscaylBin   = ""
        UpscaylModel = "remacri-4x"
        Folders      = @("ch", "wp")
        Maps         = @()
        Factor       = 2
        MaxSize      = 4096
        MinSize      = 128
        Quality      = "Slow"
        Tta          = $false
        Encoders     = [Math]::Max(1, [Math]::Floor([Environment]::ProcessorCount / 4))
        AutoInstall  = $true
    }
}
function Get-Cfg {
    $c = Get-DefaultCfg
    if (Test-Path $CfgFile) {
        try {
            $j = Get-Content $CfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in @($c.Keys)) { if ($null -ne $j.$k) { $c[$k] = $j.$k } }
        } catch {}
    }
    $c.Folders = @($c.Folders); $c.Maps = @($c.Maps)
    return $c
}
function Save-Cfg($c) { $c | ConvertTo-Json | Set-Content $CfgFile -Encoding UTF8 }
$Cfg = Get-Cfg

function Get-DumpDir { Join-Path $Cfg.EdenData "dump\$TitleId\romfs" }

function Log([string]$m, [string]$level = "info") {
    $line = "{0:HH:mm:ss}  {1}" -f (Get-Date), $m
    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
    if ($S) { $S.Log.Enqueue("$level|$line") } else { Write-Host $line }
}
function Fail([string]$m) { throw $m }
function Test-Stop { return ($S -and $S.Stop) }
function Set-Progress([string]$phase, [int]$done, [int]$total, [string]$item, $eta) {
    if (-not $S) { return }
    $S.Phase = $phase; $S.Done = $done; $S.Total = $total; $S.Item = $item
    $S.Eta = if ($eta) { "{0:hh\:mm}" -f $eta } else { "" }
}

# ---------------- Bild-Helfer ----------------
Add-Type -AssemblyName System.Drawing
if (-not ("Xc3Img" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition $Xc3ImgSource
}

# ---------------- DDS ----------------
$DxgiNames = @{
    28 = "Rgba8Unorm"; 29 = "Rgba8UnormSrgb"; 87 = "Bgra8Unorm"; 91 = "Bgra8UnormSrgb"
    71 = "BC1RgbaUnorm"; 72 = "BC1RgbaUnormSrgb"; 74 = "BC2RgbaUnorm"; 75 = "BC2RgbaUnormSrgb"
    77 = "BC3RgbaUnorm"; 78 = "BC3RgbaUnormSrgb"; 80 = "BC4RUnorm"; 81 = "BC4RSnorm"
    83 = "BC5RgUnorm"; 84 = "BC5RgSnorm"; 95 = "BC6hRgbUfloat"; 96 = "BC6hRgbSfloat"
    98 = "BC7RgbaUnorm"; 99 = "BC7RgbaUnormSrgb"; 61 = "R8Unorm"; 49 = "Rg8Unorm"
}
$ColorFormats = @(28, 29, 87, 91, 71, 72, 74, 75, 77, 78, 98, 99)

function Get-DdsInfo([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try { $b = New-Object byte[] 148; [void]$fs.Read($b, 0, 148) } finally { $fs.Close() }
    if ([Text.Encoding]::ASCII.GetString($b, 0, 4) -ne "DDS ") { return $null }
    $info = @{
        Height = [BitConverter]::ToUInt32($b, 12); Width = [BitConverter]::ToUInt32($b, 16)
        Caps2 = [BitConverter]::ToUInt32($b, 112); Dxgi = 0; Array = 1; Cube = $false
    }
    switch ([Text.Encoding]::ASCII.GetString($b, 84, 4)) {
        "DX10" {
            $info.Dxgi  = [int][BitConverter]::ToUInt32($b, 128)
            $info.Cube  = (([BitConverter]::ToUInt32($b, 136) -band 4) -ne 0)
            $info.Array = [BitConverter]::ToUInt32($b, 140)
        }
        "DXT1" { $info.Dxgi = 71 }  "DXT3" { $info.Dxgi = 74 }  "DXT5" { $info.Dxgi = 77 }
        "ATI1" { $info.Dxgi = 80 }  "BC4U" { $info.Dxgi = 80 }  "ATI2" { $info.Dxgi = 83 }  "BC5U" { $info.Dxgi = 83 }
    }
    if (($info.Caps2 -band 0x200) -ne 0) { $info.Cube = $true }
    $info.Volume = (($info.Caps2 -band 0x200000) -ne 0)
    $info.Format = $DxgiNames[$info.Dxgi]
    return $info
}

# ---------------- Externe Programme (unsichtbar) ----------------
function Format-Args([string[]]$a) {
    ($a | ForEach-Object { if ($_ -match '[\s"]' -or $_ -eq "") { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
}
function New-Proc([string]$exe, [string[]]$a, [bool]$redirect) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = Format-Args $a
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $Root
    if ($redirect) { $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true }
    return [Diagnostics.Process]::Start($psi)
}
# Synchron ausfuehren; Fehler bei Exit-Code != 0
function Run([string]$exe, [string[]]$a, [switch]$Quiet) {
    $p = New-Proc $exe $a $true
    $outT = $p.StandardOutput.ReadToEndAsync(); $errT = $p.StandardError.ReadToEndAsync()
    $p.WaitForExit()
    $out = $outT.Result; $err = $errT.Result
    if (-not $Quiet -and $out) { try { Add-Content $LogFile $out -Encoding UTF8 } catch {} }
    if ($p.ExitCode -ne 0) {
        $msg = (($err + "`n" + $out).Trim() -split "`n" | Select-Object -Last 4) -join " "
        throw ("{0} meldet Fehler {1}: {2}" -f (Split-Path -Leaf $exe), $p.ExitCode, $msg)
    }
    return $out
}

# ---------------- Werkzeuge ----------------
$FallbackUrls = @{
    "XbTool"      = "https://github.com/AlexCSDev/XbTool/releases/download/040623/xbtool_040623.zip"
    "xc3_tex"     = "https://github.com/ScanMountGoat/xc3_lib/releases/download/v0.22.0/xc3_lib_win_x64.zip"
    "file-loader" = "https://github.com/roccodev/xcnx-file-loader/releases/download/2.0.2/xcnx-file-loader-xc3.zip"
}
function Save-Download([string]$url, [string]$out) {
    $curl = Join-Path $env:SystemRoot "System32\curl.exe"
    if (Test-Path $curl) {
        $p = New-Proc $curl @("-L", "-f", "-s", "-S", "-A", "XC3-HD", "-o", $out, $url) $false
        $p.WaitForExit()
        if ($p.ExitCode -eq 0 -and (Test-Path $out)) { return }
    }
    $wc = New-Object Net.WebClient
    $wc.Headers.Add("User-Agent", "XC3-HD")
    $wc.DownloadFile($url, $out)
}
function Install-Tool([string]$name) {
    $dir = Join-Path $ToolsDir $name
    if (Test-Path (Join-Path $dir ".fertig")) { return $dir }
    $url = $FallbackUrls[$name]
    Log "Lade $name ..."
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $zip = Join-Path $dir (($url -split '/')[-1])
    try { Save-Download $url $zip } catch { Fail "Download von $name fehlgeschlagen: $($_.Exception.Message)" }
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    Remove-Item $zip -ErrorAction SilentlyContinue
    Set-Content (Join-Path $dir ".fertig") "ok"
    return $dir
}
function Find-File([string]$dir, [string]$name) {
    if (-not (Test-Path $dir)) { return $null }
    $f = Get-ChildItem -Path $dir -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { return $f.FullName } else { return $null }
}
function Find-Upscayl {
    if ($Cfg.UpscaylBin -and (Test-Path $Cfg.UpscaylBin)) { return $Cfg.UpscaylBin }
    $cands = @(
        (Join-Path $env:ProgramFiles "Upscayl\resources\bin\upscayl-bin.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Upscayl\resources\bin\upscayl-bin.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Upscayl\resources\bin\upscayl-bin.exe")
    )
    foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}
function Get-UpscaylModels {
    $bin = Find-Upscayl
    if (-not $bin) { return @{ Dir = ""; Names = @() } }
    $dir = Join-Path (Split-Path -Parent (Split-Path -Parent $bin)) "models"
    $names = @(Get-ChildItem $dir -Filter *.param -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName } |
               Where-Object { $_ -notmatch '(?i)lite|x2|2x$' } | Sort-Object)
    return @{ Dir = $dir; Names = $names }
}
function Find-Maptex {
    foreach ($c in @((Join-Path $ToolsDir "maptex\xc3_maptex.exe"), (Join-Path $Root "xc3_maptex.exe"))) { if (Test-Path $c) { return $c } }
    return $null
}
function Get-Tools {
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    $xb = Install-Tool "XbTool"; $xc = Install-Tool "xc3_tex"; $fl = Install-Tool "file-loader"
    $up = Find-Upscayl
    if (-not $up) { Fail "Upscayl nicht gefunden. Bitte installieren (upscayl.org) oder den Pfad in den Einstellungen angeben." }
    return @{
        XbTool = (Find-File $xb "xbtool.exe"); Tex = (Find-File $xc "xc3_tex.exe")
        Loader = $fl; Upscayl = $up; Maptex = (Find-Maptex)
    }
}

# ---------------- Entpacken ----------------
function Test-Extracted { Test-Path (Join-Path $Extract ".fertig") }
function Invoke-Extract($t) {
    if (Test-Extracted) { return }
    $dump = Get-DumpDir
    $arh = Join-Path $dump "bf3.arh"; $ard = Join-Path $dump "bf3.ard"
    if (-not (Test-Path $arh) -or -not (Test-Path $ard)) { Fail "bf3.arh/bf3.ard nicht gefunden in $dump. Bitte in Eden: Rechtsklick auf das Spiel -> RomFS dumpen." }
    Set-Progress "Spielarchiv entpacken" 0 0 "bf3.ard (ca. 10 GB)" $null
    Log "Entpacke das Spielarchiv (dauert ein paar Minuten)..." "accent"
    New-Item -ItemType Directory -Path $Extract -Force | Out-Null
    Run $t.XbTool @("-g", "xb3", "-t", "ExtractArchive", "-a", $arh, $ard, "-o", $Extract) -Quiet | Out-Null
    if (-not (Test-Path (Join-Path $Extract "chr"))) {
        $sub = Get-ChildItem $Extract -Recurse -Directory -Filter chr -Depth 2 | Select-Object -First 1
        if ($sub) { Get-ChildItem $sub.Parent.FullName | Move-Item -Destination $Extract -Force }
    }
    if (-not (Test-Path (Join-Path $Extract "chr"))) { Fail "Nach dem Entpacken fehlt der Ordner chr." }
    Set-Content (Join-Path $Extract ".fertig") (Get-Date)
    Log "Spielarchiv entpackt." "ok"
}

# ---------------- Gemeinsame Upscale-Logik ----------------
function Test-Upscale($info, [string]$png) {
    if (-not $info -or -not $info.Format) { return $false }
    if ($ColorFormats -notcontains $info.Dxgi) { return $false }
    if ($info.Cube -or $info.Volume -or $info.Array -gt 1) { return $false }
    if ([Math]::Min($info.Width, $info.Height) -lt $Cfg.MinSize) { return $false }
    if ([Math]::Max($info.Width, $info.Height) * $Cfg.Factor -gt $Cfg.MaxSize) { return $false }
    $texName = (Split-Path -Leaf $png)
    if ($texName -match '(?i)(MSK|NRM|NML|AMB|_AO|SPM|SPC|MTL|RGH|GLS|DEP|HGT|EMI|PRM|MASK|ALPHA)') { return $false }
    if ([Xc3Img]::LooksLikeNormalMap($png)) { return $false }
    return $true
}
function Invoke-UpscaleTexture($t, [string]$png, $info, [string]$model, [string]$tmp, [string]$outPng) {
    $pad = [int][Math]::Max(8, [Math]::Min($info.Width, $info.Height) / 16)
    $padded = "$tmp.pad.png"; $alpha = "$tmp.alpha.png"; $up = "$tmp.up.png"
    $hasA = [Xc3Img]::Prepare($png, $padded, $alpha, $pad)
    $m = Get-UpscaylModels
    $ua = @("-i", $padded, "-o", $up, "-s", "4", "-m", $m.Dir, "-n", $model, "-f", "png")
    if ($Cfg.Tta) { $ua += "-x" }
    Run $t.Upscayl $ua -Quiet | Out-Null
    $ow = [int]$info.Width * $Cfg.Factor; $oh = [int]$info.Height * $Cfg.Factor
    [Xc3Img]::Finish($up, $(if ($hasA) { $alpha } else { "" }), [int]$info.Width, [int]$info.Height, $pad, 4, $ow, $oh, $outPng)
    Remove-Item $padded, $alpha, $up -ErrorAction SilentlyContinue
}

# Parallele Komprimierung (CPU) waehrend die GPU weiterrechnet
$script:Encoders = New-Object System.Collections.ArrayList
function Start-Encode($t, [string]$png, [string]$tmpDds, [string]$final, [string]$fmt, [string]$orig) {
    while (@($script:Encoders | Where-Object { -not $_.HasExited }).Count -ge [int]$Cfg.Encoders) { Start-Sleep -Milliseconds 100 }
    Complete-Encodes -OnlyExited
    New-Item -ItemType Directory -Path (Split-Path -Parent $tmpDds) -Force | Out-Null
    $p = New-Proc $t.Tex @($png, $tmpDds, "--format", $fmt, "--quality", $Cfg.Quality) $false
    $p | Add-Member -NotePropertyName Job -NotePropertyValue @{ Tmp = $tmpDds; Final = $final; Png = $png; Orig = $orig } -Force
    [void]$script:Encoders.Add($p)
}
function Complete-Encodes([switch]$OnlyExited) {
    foreach ($p in @($script:Encoders)) {
        if ($OnlyExited -and -not $p.HasExited) { continue }
        $p.WaitForExit()
        $j = $p.Job
        if ((Test-Path $j.Tmp) -and (Get-Item $j.Tmp).Length -gt 0) { Move-Item $j.Tmp $j.Final -Force }
        else {
            Log "  Komprimieren fehlgeschlagen: $(Split-Path -Leaf $j.Final)" "warn"
            if ($j.Orig) { Copy-Item $j.Orig $j.Final -Force }
        }
        Remove-Item $j.Png -ErrorAction SilentlyContinue
        [void]$script:Encoders.Remove($p)
    }
}

# ---------------- Modelle (Charaktere, Waffen, Monster, Objekte) ----------------
function Get-ModelFiles([string]$id) {
    $src = $Sources[$id]
    $d = Join-Path $Extract $src.Dir
    if (-not (Test-Path $d)) { return @() }
    return @(Get-ChildItem $d -Recurse -Filter ("*." + $src.Kind) -File | Sort-Object FullName)
}
function Get-ModelMarker([string]$rel) { Join-Path $WorkDir ("fertig-v3\" + $rel + ".ok") }
function Get-ModelDoneCount([string]$id) {
    $src = $Sources[$id]
    $d = Join-Path $WorkDir ("fertig-v3\" + $src.Dir)
    if (-not (Test-Path $d)) { return 0 }
    return @(Get-ChildItem $d -Recurse -Filter ("*." + $src.Kind + ".ok") -File).Count
}
function Export-Model($t, $wimdo) {
    $rel = $wimdo.FullName.Substring($Extract.Length + 1)
    $exp = Join-Path $WorkDir ("export\" + [IO.Path]::ChangeExtension($rel, $null).TrimEnd('.'))
    if (-not (Test-Path (Join-Path $exp ".fertig"))) {
        New-Item -ItemType Directory -Path $exp -Force | Out-Null
        Run $t.Tex @($wimdo.FullName, $exp) -Quiet | Out-Null
        Set-Content (Join-Path $exp ".fertig") ""
    }
    return @{ Rel = $rel; Export = $exp }
}

function Invoke-BuildModels($t, [string]$folder) {
    $kind = $Sources[$folder].Kind
    if ($kind -eq "witex") { return (Invoke-BuildWitex $t $folder) }
    if ($kind -eq "wilay") { return (Invoke-BuildWilay $t $folder) }
    $files = @(Get-ModelFiles $folder)
    $label = $Categories[$folder]
    $model = $Cfg.UpscaylModel
    $todo = @($files | Where-Object { -not (Test-Path (Get-ModelMarker ($_.FullName.Substring($Extract.Length + 1)))) })
    $already = $files.Count - $todo.Count
    Log ("{0}: {1} Modelle, {2} schon fertig" -f $label, $files.Count, $already) "accent"
    $sw = [Diagnostics.Stopwatch]::StartNew(); $n = 0
    foreach ($w in $todo) {
        if (Test-Stop) { return }
        $rel = $w.FullName.Substring($Extract.Length + 1)
        $eta = if ($n -gt 0) { [TimeSpan]::FromSeconds($sw.Elapsed.TotalSeconds / $n * ($todo.Count - $n)) } else { $null }
        Set-Progress $label ($already + $n) $files.Count (Split-Path -Leaf $rel) $eta
        try {
            $e = Export-Model $t $w
            $final = Join-Path $WorkDir ("final-v2\" + [IO.Path]::ChangeExtension($rel, $null).TrimEnd('.'))
            New-Item -ItemType Directory -Path $final -Force | Out-Null
            foreach ($dds in Get-ChildItem $e.Export -Filter *.dds) {
                $target = Join-Path $final $dds.Name
                $encOld = Join-Path $final ("_enc\" + $dds.Name)
                if ((Test-Path $encOld) -and (Get-Item $encOld).Length -gt 0) { Move-Item $encOld $target -Force; continue }
                if (Test-Path $target) { continue }
                $info = Get-DdsInfo $dds.FullName
                $png = Join-Path $final ($dds.BaseName + ".orig.png")
                $doIt = $false
                if ($info -and $ColorFormats -contains $info.Dxgi -and -not $info.Cube -and $info.Array -le 1) {
                    Run $t.Tex @($dds.FullName, $png) -Quiet | Out-Null
                    $doIt = Test-Upscale $info $png
                }
                if (-not $doIt) { Copy-Item $dds.FullName $target; Remove-Item $png -ErrorAction SilentlyContinue; continue }
                $hi = Join-Path $final ($dds.BaseName + ".hd.png")
                Invoke-UpscaleTexture $t $png $info $model (Join-Path $final $dds.BaseName) $hi
                Remove-Item $png -ErrorAction SilentlyContinue
                Start-Encode $t $hi (Join-Path $final ("_enc\" + $dds.Name)) $target $info.Format $dds.FullName
            }
            Complete-Encodes
            $hd = @(Get-ChildItem $final -Filter *.dds | Where-Object { $_.Length -ne (Get-Item (Join-Path $e.Export $_.Name)).Length }).Count
            if ($hd -gt 0) {
                $outWimdo = Join-Path $ModDir ("romfs\" + $rel)
                New-Item -ItemType Directory -Path (Split-Path -Parent $outWimdo) -Force | Out-Null
                Run $t.Tex @("edit-wimdo", $w.FullName, $final, $outWimdo, (Join-Path $Extract "chr")) -Quiet | Out-Null
            }
            $marker = Get-ModelMarker $rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $marker) -Force | Out-Null
            Set-Content $marker ""
        } catch {
            Complete-Encodes
            Log "  Übersprungen: $rel ($($_.Exception.Message))" "warn"
        }
        $n++
    }
    Set-Progress $label $files.Count $files.Count "" $null
    Log "$label fertig." "ok"
}

# Gemeinsame Schleife fuer Einzeldateien (witex/wilay): $process bekommt Datei + rel und meldet $true bei Aenderung
function Invoke-FileLoop($t, [string]$id, [scriptblock]$process) {
    $files = @(Get-ModelFiles $id)
    $label = $Categories[$id]
    $todo = @($files | Where-Object { -not (Test-Path (Get-ModelMarker ($_.FullName.Substring($Extract.Length + 1)))) })
    $already = $files.Count - $todo.Count
    Log ("{0}: {1} Dateien, {2} schon fertig" -f $label, $files.Count, $already) "accent"
    $sw = [Diagnostics.Stopwatch]::StartNew(); $n = 0
    foreach ($f in $todo) {
        if (Test-Stop) { return }
        $rel = $f.FullName.Substring($Extract.Length + 1)
        $eta = if ($n -gt 0) { [TimeSpan]::FromSeconds($sw.Elapsed.TotalSeconds / $n * ($todo.Count - $n)) } else { $null }
        Set-Progress $label ($already + $n) $files.Count (Split-Path -Leaf $rel) $eta
        try {
            & $process $f $rel
            $marker = Get-ModelMarker $rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $marker) -Force | Out-Null
            Set-Content $marker ""
        } catch {
            Complete-Encodes
            Log "  Übersprungen: $rel ($($_.Exception.Message))" "warn"
        }
        $n++
    }
    Set-Progress $label $files.Count $files.Count "" $null
    Log "$label fertig." "ok"
}

# Einzelne Texturdateien (.witex) - direkt als .witex in die Mod
function Invoke-BuildWitex($t, [string]$id) {
    Invoke-FileLoop $t $id {
        param($f, $rel)
        $base = Join-Path $WorkDir ("final-v2\" + $rel)
        New-Item -ItemType Directory -Path (Split-Path -Parent $base) -Force | Out-Null
        $dds = "$base.orig.dds"
        Run $t.Tex @($f.FullName, $dds) -Quiet | Out-Null
        $info = Get-DdsInfo $dds
        $png = "$base.orig.png"
        $ok = $false
        if ($info -and $ColorFormats -contains $info.Dxgi -and -not $info.Cube -and $info.Array -le 1) {
            Run $t.Tex @($dds, $png) -Quiet | Out-Null
            $ok = Test-Upscale $info $png
        }
        if ($ok) {
            $hi = "$base.hd.png"
            Invoke-UpscaleTexture $t $png $info $Cfg.UpscaylModel $base $hi
            $out = Join-Path $ModDir ("romfs\" + $rel)
            New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
            Start-Encode $t $hi (Join-Path (Split-Path -Parent $base) ("_enc\" + (Split-Path -Leaf $rel))) $out $info.Format ""
            Complete-Encodes
        }
        Remove-Item $dds, $png -ErrorAction SilentlyContinue
    }
}

# Menue-Layouts (.wilay) - nur DDS-Texturen, JPEG-Bilder bleiben original
function Invoke-BuildWilay($t, [string]$id) {
    Invoke-FileLoop $t $id {
        param($f, $rel)
        $stem = [IO.Path]::ChangeExtension($rel, $null).TrimEnd('.')
        $exp = Join-Path $WorkDir ("export\" + $stem)
        $final = Join-Path $WorkDir ("final-v2\" + $stem)
        $tmp = Join-Path $final "_tmp"
        if (-not (Test-Path (Join-Path $exp ".fertig"))) {
            New-Item -ItemType Directory -Path $exp -Force | Out-Null
            Run $t.Tex @($f.FullName, $exp) -Quiet | Out-Null
            Set-Content (Join-Path $exp ".fertig") ""
        }
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $count = 0
        foreach ($dds in Get-ChildItem $exp -Filter *.dds) {
            $target = Join-Path $final $dds.Name
            if (Test-Path $target) { $count++; continue }
            $info = Get-DdsInfo $dds.FullName
            $png = Join-Path $tmp ($dds.BaseName + ".orig.png")
            $ok = $false
            if ($info -and $ColorFormats -contains $info.Dxgi -and -not $info.Cube -and $info.Array -le 1) {
                Run $t.Tex @($dds.FullName, $png) -Quiet | Out-Null
                $ok = Test-Upscale $info $png
            }
            if (-not $ok) { Remove-Item $png -ErrorAction SilentlyContinue; continue }
            $hi = Join-Path $tmp ($dds.BaseName + ".hd.png")
            Invoke-UpscaleTexture $t $png $info $Cfg.UpscaylModel (Join-Path $tmp $dds.BaseName) $hi
            Remove-Item $png -ErrorAction SilentlyContinue
            Start-Encode $t $hi (Join-Path $tmp ("_enc\" + $dds.Name)) $target $info.Format ""
            $count++
        }
        Complete-Encodes
        if (@(Get-ChildItem $final -Filter *.dds -File).Count -gt 0) {
            $out = Join-Path $ModDir ("romfs\" + $rel)
            New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
            Run $t.Tex @("edit-wilay", $f.FullName, $final, $out) -Quiet | Out-Null
        }
    }
}

# ---------------- Karten ----------------
function Get-MapList {
    $d = Join-Path $Extract "map"
    if (-not (Test-Path $d)) { return @() }
    return @(Get-ChildItem $d -Filter *.wismhd -File | Sort-Object Name | ForEach-Object {
        $da = [IO.Path]::ChangeExtension($_.FullName, ".wismda")
        [pscustomobject]@{ Id = $_.BaseName; Path = $_.FullName; SizeMB = $(if (Test-Path $da) { [int]((Get-Item $da).Length / 1MB) } else { 0 }) }
    })
}
function Get-MapState([string]$id) {
    $dir = Join-Path $MapsDir $id
    $exp = Join-Path $dir "export"
    $total = if (Test-Path $exp) { @(Get-ChildItem $exp -Filter *.dds -File).Count } else { 0 }
    $hd = if (Test-Path (Join-Path $dir "hd")) { @(Get-ChildItem (Join-Path $dir "hd") -Filter *.dds -File).Count } else { 0 }
    $skip = if (Test-Path (Join-Path $dir "hd\_tmp")) { @(Get-ChildItem (Join-Path $dir "hd\_tmp") -Filter *.skip -File).Count } else { 0 }
    $complete = (Test-Path (Join-Path $dir ".fertig")) -or ($total -gt 0 -and ($hd + $skip) -ge $total)
    return @{ Total = $total; Hd = $hd; Done = $hd + $skip; Complete = $complete }
}

function Invoke-BuildMap($t, $map) {
    if (-not $t.Maptex) { Fail "xc3_maptex.exe fehlt (sollte im Programm enthalten sein)." }
    # Karten vertragen keine 4096er-Texturen (Welt wird schwarz) - hier immer max. 2048 px
    $c = @{}; foreach ($k in @($Cfg.Keys)) { $c[$k] = $Cfg[$k] }
    if ([int]$c.MaxSize -gt 2048) { $c.MaxSize = 2048 }
    $Cfg = $c
    $id = $map.Id
    $dir = Join-Path $MapsDir $id; $src = Join-Path $dir "export"; $dst = Join-Path $dir "hd"
    $tmp = Join-Path $dst "_tmp"
    $label = "Karte $id"
    if (-not (Test-Path (Join-Path $src ".fertig"))) {
        Set-Progress $label 0 0 "Texturen exportieren" $null
        Log "$label`: exportiere Texturen..." "accent"
        New-Item -ItemType Directory -Path $src -Force | Out-Null
        Run $t.Maptex @("export", $map.Path, $src) -Quiet | Out-Null
        Set-Content (Join-Path $src ".fertig") ""
    }
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $all = @(Get-ChildItem $src -Filter *.dds | Sort-Object { [int]($_.BaseName.Split('.')[1]) })
    $todo = @($all | Where-Object { -not (Test-Path (Join-Path $dst $_.Name)) -and -not (Test-Path (Join-Path $tmp ($_.Name + ".skip"))) })
    $already = $all.Count - $todo.Count
    Log ("{0}: {1} Texturen, {2} schon erledigt" -f $label, $all.Count, $already) "accent"
    $sw = [Diagnostics.Stopwatch]::StartNew(); $n = 0; $new = 0
    foreach ($dds in $todo) {
        if (Test-Stop) { break }
        $eta = if ($n -gt 0) { [TimeSpan]::FromSeconds($sw.Elapsed.TotalSeconds / $n * ($todo.Count - $n)) } else { $null }
        Set-Progress $label ($already + $n) $all.Count $dds.Name $eta
        $n++
        $target = Join-Path $dst $dds.Name
        $skip = Join-Path $tmp ($dds.Name + ".skip")
        $info = Get-DdsInfo $dds.FullName
        $png = Join-Path $tmp ($dds.BaseName + ".orig.png")
        $ok = $false
        if ($info -and $ColorFormats -contains $info.Dxgi -and -not $info.Cube -and $info.Array -le 1) {
            try { Run $t.Tex @($dds.FullName, $png) -Quiet | Out-Null; $ok = Test-Upscale $info $png } catch { $ok = $false }
        }
        if (-not $ok) { Set-Content $skip ""; Remove-Item $png -ErrorAction SilentlyContinue; continue }
        $hi = Join-Path $tmp ($dds.BaseName + ".hd.png")
        try { Invoke-UpscaleTexture $t $png $info $Cfg.UpscaylModel (Join-Path $tmp $dds.BaseName) $hi }
        catch { Log "  $($dds.Name): $($_.Exception.Message)" "warn"; Set-Content $skip ""; continue }
        Remove-Item $png -ErrorAction SilentlyContinue
        Start-Encode $t $hi (Join-Path $dst ("_enc\" + $dds.Name)) $target $info.Format ""
        $new++
    }
    Complete-Encodes
    $hdCount = @(Get-ChildItem $dst -Filter *.dds -File).Count
    $complete = -not (Test-Stop)
    if ($complete) { Set-Content (Join-Path $dir ".fertig") "" }
    if ($hdCount -gt 0 -and ($new -gt 0 -or -not (Test-Path (Join-Path $ModDir "romfs\map\$id.wismhd")))) {
        Set-Progress $label $all.Count $all.Count "Karte zusammenbauen" $null
        Log "$label`: baue $hdCount HD-Texturen in die Karte ein..." "accent"
        Run $t.Maptex @("import", $map.Path, $dst, (Join-Path $ModDir "romfs\map")) -Quiet | Out-Null
        Log "$label`: fertig ($hdCount HD-Texturen)." "ok"
    }
}

# ---------------- Installieren ----------------
function Test-EdenRunning { [bool](Get-Process -Name eden, eden-cli -ErrorAction SilentlyContinue) }
function Invoke-Install($t) {
    if (Test-EdenRunning) { Fail "Eden läuft gerade. Bitte zuerst schließen." }
    if (-not (Test-Path (Join-Path $ModDir "romfs"))) { Fail "Es wurde noch nichts gebaut." }
    $load = Join-Path $Cfg.EdenData "load\$TitleId"
    $src = Get-ChildItem $t.Loader -Recurse -Directory -Filter $TitleId | Select-Object -First 1
    if (-not $src) { Fail "File-Loader-Paket unvollständig." }
    $fl = Join-Path $load "XCNX File Loader"
    New-Item -ItemType Directory -Path $fl -Force | Out-Null
    Copy-Item (Join-Path $src.FullName "*") $fl -Recurse -Force
    $dst = Join-Path $load $ModName
    Set-Progress "In Eden installieren" 0 0 "Dateien kopieren" $null
    Log "Kopiere Mod nach $dst ..." "accent"
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    $p = New-Proc "robocopy.exe" @($ModDir, $dst, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:1", "/W:1") $false
    $p.WaitForExit()
    if ($p.ExitCode -ge 8) { Fail "Kopieren fehlgeschlagen (robocopy $($p.ExitCode))." }
    Log "In Eden installiert. Beide Mods (XC3 HD Texturen + XCNX File Loader) müssen in Eden aktiviert sein." "ok"
}

# ---------------- Modell-Vergleich ----------------
function Invoke-Compare($t) {
    Invoke-Extract $t
    $m = Get-UpscaylModels
    if (-not $m.Names.Count) { Fail "Keine Upscayl-Modelle gefunden." }
    $cmp = Join-Path $Root "vergleich"; New-Item -ItemType Directory -Path $cmp -Force | Out-Null
    Log ("Vergleiche: " + ($m.Names -join ", ")) "accent"
    $samples = @()
    $pool = @(Get-ModelFiles "ch") + @(Get-ModelFiles "en")
    foreach ($w in ($pool | Get-Random -Count ([Math]::Min(60, $pool.Count)) -SetSeed 7)) {
        if ($samples.Count -ge 6 -or (Test-Stop)) { break }
        Set-Progress "Modell-Vergleich" $samples.Count 6 "Beispiele suchen" $null
        try { $e = Export-Model $t $w } catch { continue }
        foreach ($dds in Get-ChildItem $e.Export -Filter *.dds) {
            $info = Get-DdsInfo $dds.FullName
            if (-not $info -or [Math]::Min($info.Width, $info.Height) -lt 512 -or $ColorFormats -notcontains $info.Dxgi -or $info.Array -gt 1 -or $info.Cube) { continue }
            if ($dds.Name -match '(?i)(MSK|NRM|AMB|SPM|MTL)') { continue }
            $png = Join-Path $cmp ("s{0}.png" -f $samples.Count)
            Run $t.Tex @($dds.FullName, $png) -Quiet | Out-Null
            if ([Xc3Img]::LooksLikeNormalMap($png)) { continue }
            $crop = Join-Path $cmp ("s{0}.crop.png" -f $samples.Count)
            [Xc3Img]::Crop($png, $crop, 256)
            $samples += $crop
            break
        }
    }
    if (-not $samples.Count) { Fail "Keine Beispiel-Texturen gefunden." }
    $files = @(); $cols = @("Original") + $m.Names
    $total = $samples.Count * $m.Names.Count; $k = 0
    foreach ($s in $samples) {
        $bic = "$s.bicubic.png"; [Xc3Img]::Upscale($s, $bic, 512, 512); $files += $bic
        foreach ($mod in $m.Names) {
            if (Test-Stop) { return $null }
            Set-Progress "Modell-Vergleich" $k $total $mod $null; $k++
            $out = "$s.$mod.png"
            try { Invoke-UpscaleTexture $t $s @{ Width = 256; Height = 256 } $mod "$s.$mod" $out }
            catch { Log "  $mod fehlgeschlagen: $($_.Exception.Message)" "warn"; $out = "" }
            $files += $out
        }
    }
    $sheet = Join-Path $Root "Modell-Vergleich.png"
    [Xc3Img]::Sheet($files, $cols, $samples.Count, $cols.Count, 512, $sheet)
    Log "Vergleichsbild erstellt." "ok"
    return $sheet
}

# ---------------- Gesamtablauf ----------------
function Invoke-Job([string]$job) {
    $Cfg = Get-Cfg
    $t = Get-Tools
    switch ($job) {
        "setup"   { Invoke-Extract $t }
        "compare" { $S.Result = Invoke-Compare $t }
        "install" { Invoke-Install $t }
        "build" {
            Invoke-Extract $t
            if (-not $Cfg.UpscaylModel) { Fail "Kein KI-Modell gewählt." }
            Log ("Start: Modell {0}, {1}x bis max. {2} px, Kompression {3}" -f $Cfg.UpscaylModel, $Cfg.Factor, $Cfg.MaxSize, $Cfg.Quality) "accent"
            foreach ($f in $Categories.Keys) {
                if (Test-Stop) { break }
                if (@($Cfg.Folders) -contains $f) { Invoke-BuildModels $t $f }
            }
            foreach ($map in (Get-MapList)) {
                if (Test-Stop) { break }
                if (@($Cfg.Maps) -contains $map.Id) { Invoke-BuildMap $t $map }
            }
            if (Test-Stop) { Log "Angehalten. Beim nächsten Start geht es an derselben Stelle weiter." "warn" }
            if ($Cfg.AutoInstall -and (Test-Path (Join-Path $ModDir "romfs"))) {
                if (Test-EdenRunning) { Log "Eden läuft - Installation uebersprungen. Spaeter auf 'In Eden installieren' klicken." "warn" }
                else { Invoke-Install $t }
            }
        }
    }
}
}

# ==========================================================================
#  Oberflaeche
# ==========================================================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$exePath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$Root = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
        elseif ((Split-Path -Leaf $exePath) -notmatch '^(powershell|pwsh)') { Split-Path -Parent $exePath }
        else { (Get-Location).Path }
if ($env:XC3HD_ROOT) { $Root = $env:XC3HD_ROOT }
$S = $null
. $Engine

# Im EXE eingebettete Werkzeuge auspacken (xc3_maptex.exe)
function Expand-EmbeddedTools {
    try {
        $asm = [Reflection.Assembly]::GetEntryAssembly()
        if (-not $asm) { return }
        foreach ($n in $asm.GetManifestResourceNames()) {
            if ($n -notlike "*.exe") { continue }
            $dir = Join-Path $ToolsDir "maptex"; New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $out = Join-Path $dir $n
            $st = $asm.GetManifestResourceStream($n)
            try {
                if ((Test-Path $out) -and (Get-Item $out).Length -eq $st.Length) { continue }
                $fs = [IO.File]::Create($out); try { $st.CopyTo($fs) } finally { $fs.Close() }
            } finally { $st.Close() }
        }
    } catch {}
}
Expand-EmbeddedTools

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="XC3 HD Texturen" Width="1280" Height="800" MinWidth="1100" MinHeight="660"
        WindowStartupLocation="CenterScreen" Background="#0E1116" Foreground="#E6EAF0"
        FontFamily="Segoe UI" FontSize="13" UseLayoutRounding="True">
  <Window.Resources>
    <SolidColorBrush x:Key="Card" Color="#161B22"/>
    <SolidColorBrush x:Key="Line" Color="#262D38"/>
    <SolidColorBrush x:Key="Muted" Color="#8B95A5"/>
    <SolidColorBrush x:Key="Accent" Color="#3FB6E8"/>
    <SolidColorBrush x:Key="AccentText" Color="#06141C"/>
    <SolidColorBrush x:Key="Ok" Color="#4CC38A"/>
    <SolidColorBrush x:Key="Warn" Color="#E5B454"/>
    <SolidColorBrush x:Key="Bad" Color="#F06A6A"/>
    <Style x:Key="CardBorder" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource Card}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="10"/>
      <Setter Property="Padding" Value="16,14"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
    <Style x:Key="H" TargetType="TextBlock">
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,10"/>
      <Setter Property="Foreground" Value="#E6EAF0"/>
    </Style>
    <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#E6EAF0"/></Style>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="#E6EAF0"/>
      <Setter Property="Background" Value="#202734"/>
      <Setter Property="BorderBrush" Value="#2E3746"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="7" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BtnPrimary" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="{StaticResource AccentText}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E6EAF0"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,3"/>
    </Style>
    <Style TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="#E6EAF0"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="b" Background="Transparent" CornerRadius="5" Padding="{TemplateBinding Padding}" Margin="3,1">
              <ContentPresenter TextElement.Foreground="#E6EAF0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="b" Property="Background" Value="#263040"/></Trigger>
              <Trigger Property="IsSelected" Value="True"><Setter TargetName="b" Property="Background" Value="#1D4E66"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Margin" Value="0,0,0,10"/>
      <Setter Property="Foreground" Value="#E6EAF0"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton x:Name="Toggle" Focusable="False" ClickMode="Press"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="tb" Background="#0E1116" BorderBrush="#2E3746" BorderThickness="1" CornerRadius="7">
                      <Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0"
                            Data="M 0 0 L 5 5 L 10 0" Stroke="#8B95A5" StrokeThickness="1.6"/>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="tb" Property="BorderBrush" Value="#3FB6E8"/></Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter IsHitTestVisible="False" Margin="11,0,32,0" VerticalAlignment="Center" HorizontalAlignment="Left"
                                Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                TextElement.Foreground="#E6EAF0"/>
              <Popup x:Name="PART_Popup" Placement="Bottom" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade"
                     IsOpen="{TemplateBinding IsDropDownOpen}">
                <Border Background="#161B22" BorderBrush="#2E3746" BorderThickness="1" CornerRadius="7" Margin="0,4,0,0" Padding="0,4"
                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}" MaxHeight="320">
                  <ScrollViewer VerticalScrollBarVisibility="Auto"><ItemsPresenter/></ScrollViewer>
                </Border>
              </Popup>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#0E1116"/>
      <Setter Property="Foreground" Value="#E6EAF0"/>
      <Setter Property="BorderBrush" Value="#2E3746"/>
      <Setter Property="Padding" Value="6,5"/>
    </Style>
    <Style x:Key="Label" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="MinWidth" Value="8"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.Thumb>
                <Thumb>
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb"><Border Background="#2E3746" CornerRadius="4" Margin="1,0"/></ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
            </Track>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/><Setter Property="Height" Value="0"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Grid Margin="18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Kopf -->
    <Grid Margin="2,0,2,14">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <StackPanel>
        <TextBlock Text="XC3 HD Texturen" FontSize="22" FontWeight="SemiBold"/>
        <TextBlock Text="KI-Upscaling für Xenoblade Chronicles 3 in Eden" Foreground="{StaticResource Muted}" Margin="0,2,0,0"/>
      </StackPanel>
      <Border Grid.Column="1" x:Name="Chip" CornerRadius="12" Padding="12,5" VerticalAlignment="Center" Background="#202734">
        <TextBlock x:Name="ChipText" Text="Bereit" FontWeight="SemiBold"/>
      </Border>
    </Grid>

    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="1.15*"/>
        <ColumnDefinition Width="14"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="14"/>
        <ColumnDefinition Width="1.15*"/>
      </Grid.ColumnDefinitions>

      <!-- Links: Status + Inhalte -->
      <Grid>
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <Border Style="{StaticResource CardBorder}">
          <StackPanel>
            <TextBlock Style="{StaticResource H}" Text="Status"/>
            <ItemsControl x:Name="StatusList">
              <ItemsControl.ItemTemplate>
                <DataTemplate>
                  <Grid Margin="0,2">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="18"/><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                    <Ellipse Width="8" Height="8" Fill="{Binding Brush}" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                    <TextBlock Grid.Column="1" Text="{Binding Name}" Foreground="#8B95A5"/>
                    <TextBlock Grid.Column="2" Text="{Binding Value}" TextTrimming="CharacterEllipsis" ToolTip="{Binding Value}"/>
                  </Grid>
                </DataTemplate>
              </ItemsControl.ItemTemplate>
            </ItemsControl>
            <Button x:Name="BtnSetup" Style="{StaticResource Btn}" Content="Werkzeuge laden + Spiel entpacken" HorizontalAlignment="Left" Margin="0,10,0,0"/>
          </StackPanel>
        </Border>

        <Border Grid.Row="1" Style="{StaticResource CardBorder}" Margin="0">
          <Grid>
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <TextBlock Style="{StaticResource H}" Text="Was soll hochskaliert werden?"/>
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
              <ItemsControl x:Name="CatList">
                <ItemsControl.ItemTemplate>
                  <DataTemplate>
                    <Grid Margin="0,1">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                      <CheckBox Content="{Binding Name}" IsChecked="{Binding On, Mode=OneWay}" Tag="{Binding Id}"/>
                      <TextBlock Grid.Column="1" Text="{Binding Info}" Foreground="#8B95A5" FontSize="12" VerticalAlignment="Center" Margin="8,0,4,0"/>
                    </Grid>
                  </DataTemplate>
                </ItemsControl.ItemTemplate>
              </ItemsControl>
            </ScrollViewer>
          </Grid>
        </Border>
      </Grid>

      <!-- Mitte: Karten -->
      <Border Grid.Column="2" Style="{StaticResource CardBorder}" Margin="0">
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock Style="{StaticResource H}" Text="Karten" Margin="0" VerticalAlignment="Center"/>
            <Button Grid.Column="1" x:Name="BtnMapsAll" Style="{StaticResource Btn}" Content="Alle" Padding="10,3"/>
            <Button Grid.Column="2" x:Name="BtnMapsNone" Style="{StaticResource Btn}" Content="Keine" Padding="10,3" Margin="0"/>
          </Grid>
          <TextBlock Grid.Row="1" Text="Welttexturen wie Boden, Felsen und Gebäude (experimentell). DLC-Gebiete sind nicht im Basis-Dump enthalten." Foreground="#8B95A5" FontSize="12" Margin="0,6,0,10" TextWrapping="Wrap"/>
          <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <ItemsControl x:Name="MapList">
              <ItemsControl.ItemTemplate>
                <DataTemplate>
                  <Grid Margin="0,1">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <CheckBox Content="{Binding Name}" IsChecked="{Binding On, Mode=OneWay}" Tag="{Binding Id}"/>
                    <TextBlock Grid.Column="1" Text="{Binding Info}" Foreground="#8B95A5" VerticalAlignment="Center" Margin="0,0,6,0"/>
                  </Grid>
                </DataTemplate>
              </ItemsControl.ItemTemplate>
            </ItemsControl>
          </ScrollViewer>
        </Grid>
      </Border>

      <!-- Rechts: Einstellungen + Protokoll -->
      <Grid Grid.Column="4">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <Border Style="{StaticResource CardBorder}">
          <StackPanel>
            <TextBlock Style="{StaticResource H}" Text="Einstellungen"/>
            <TextBlock Style="{StaticResource Label}" Text="KI-Modell (Upscayl)"/>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <ComboBox x:Name="CbModel"/>
              <Button Grid.Column="1" x:Name="BtnCompare" Style="{StaticResource Btn}" Content="Vergleichen" Margin="8,0,0,10" Padding="10,5"
                      ToolTip="Erstellt ein Vergleichsbild aller Modelle mit echten Spieltexturen"/>
            </Grid>
            <TextBlock Style="{StaticResource Label}" Text="Zielgröße"/>
            <ComboBox x:Name="CbSize" SelectedValuePath="Tag"/>
            <TextBlock Style="{StaticResource Label}" Text="Kompressionsqualität"/>
            <ComboBox x:Name="CbQuality" SelectedValuePath="Tag"/>
            <TextBlock Style="{StaticResource Label}" Text="Parallele Komprimierungen (CPU)"/>
            <ComboBox x:Name="CbEncoders"/>
            <CheckBox x:Name="ChkAutoInstall" Content="Nach dem Bauen automatisch in Eden installieren"/>
            <Expander Header="Pfade" Foreground="#E6EAF0" Margin="0,8,0,0">
              <StackPanel Margin="0,8,0,0">
                <TextBlock Style="{StaticResource Label}" Text="Eden-Datenordner (enthält dump und load)"/>
                <Grid Margin="0,0,0,8">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <TextBox x:Name="TxtEden" IsReadOnly="True"/>
                  <Button Grid.Column="1" x:Name="BtnEden" Style="{StaticResource Btn}" Content="..." Margin="6,0,0,0" Padding="10,3"/>
                </Grid>
                <TextBlock Style="{StaticResource Label}" Text="Upscayl (upscayl-bin.exe)"/>
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <TextBox x:Name="TxtUpscayl" IsReadOnly="True"/>
                  <Button Grid.Column="1" x:Name="BtnUpscayl" Style="{StaticResource Btn}" Content="..." Margin="6,0,0,0" Padding="10,3"/>
                </Grid>
              </StackPanel>
            </Expander>
          </StackPanel>
        </Border>
        <Border Grid.Row="1" Style="{StaticResource CardBorder}" Margin="0">
          <Grid>
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <Grid Margin="0,0,0,8">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <TextBlock Style="{StaticResource H}" Text="Protokoll" Margin="0"/>
              <Button Grid.Column="1" x:Name="BtnFolder" Style="{StaticResource Btn}" Content="Ordner öffnen" Padding="10,3" Margin="0"/>
            </Grid>
            <TextBox Grid.Row="1" x:Name="TxtLog" IsReadOnly="True" FontFamily="Consolas" FontSize="12"
                     VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" TextWrapping="Wrap" BorderThickness="0"/>
          </Grid>
        </Border>
      </Grid>
    </Grid>

    <!-- Fußzeile: Fortschritt + Aktionen -->
    <Border Grid.Row="2" Style="{StaticResource CardBorder}" Margin="0,12,0,0">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel VerticalAlignment="Center" Margin="0,0,16,0">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtPhase" Text="Bereit" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
            <TextBlock Grid.Column="1" x:Name="TxtEta" Foreground="#8B95A5"/>
          </Grid>
          <ProgressBar x:Name="Bar" Height="8" Margin="0,7,0,5" Minimum="0" Maximum="1" Value="0"
                       Background="#202734" BorderThickness="0" Foreground="{StaticResource Accent}"/>
          <TextBlock x:Name="TxtItem" Foreground="#8B95A5" FontSize="12" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <Button x:Name="BtnInstall" Style="{StaticResource Btn}" Content="In Eden installieren"/>
          <Button x:Name="BtnStop" Style="{StaticResource Btn}" Content="Anhalten" IsEnabled="False"/>
          <Button x:Name="BtnStart" Style="{StaticResource BtnPrimary}" Content="Start" MinWidth="120" Margin="0"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
$ui = @{}
foreach ($n in @("Chip","ChipText","StatusList","BtnSetup","CatList","MapList","BtnMapsAll","BtnMapsNone","CbModel","BtnCompare",
                 "CbSize","CbQuality","CbEncoders","ChkAutoInstall","TxtEden","BtnEden","TxtUpscayl","BtnUpscayl","BtnFolder","TxtLog",
                 "TxtPhase","TxtEta","Bar","TxtItem","BtnInstall","BtnStop","BtnStart")) { $ui[$n] = $window.FindName($n) }

$Brushes = @{}
foreach ($k in @("Ok","Warn","Bad","Accent","Muted")) { $Brushes[$k] = $window.FindResource($k) }

function New-CbItem([string]$text, $tag) { $i = New-Object Windows.Controls.ComboBoxItem; $i.Content = $text; $i.Tag = $tag; return $i }

# ---------------- Zustand anzeigen ----------------
$script:Busy = $false
$script:CatItems = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$script:MapItems = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$ui.CatList.ItemsSource = $script:CatItems
$ui.MapList.ItemsSource = $script:MapItems

function New-Row($id, $name, $info, $on) {
    $o = New-Object PSObject -Property @{ Id = $id; Name = $name; Info = $info; On = [bool]$on }
    return $o
}

function Update-Status {
    $Cfg = Get-Cfg
    $dump = Get-DumpDir
    $dumpOk = (Test-Path (Join-Path $dump "bf3.ard"))
    $toolsOk = (Test-Path (Join-Path $ToolsDir "XbTool\.fertig")) -and (Test-Path (Join-Path $ToolsDir "xc3_tex\.fertig")) -and (Test-Path (Join-Path $ToolsDir "file-loader\.fertig"))
    $up = Find-Upscayl
    $ext = Test-Extracted
    $mt = Find-Maptex
    $installed = Test-Path (Join-Path $Cfg.EdenData "load\$TitleId\$ModName")
    $rows = @(
        @{ Name = "Spiel-Dump";   Value = $(if ($dumpOk) { "gefunden" } else { "fehlt - in Eden RomFS dumpen" });    Brush = $(if ($dumpOk) { $Brushes.Ok } else { $Brushes.Bad }) },
        @{ Name = "Werkzeuge";    Value = $(if ($toolsOk) { "bereit" } else { "werden beim Start geladen" });        Brush = $(if ($toolsOk) { $Brushes.Ok } else { $Brushes.Warn }) },
        @{ Name = "Upscayl";      Value = $(if ($up) { $up } else { "nicht gefunden - upscayl.org" });               Brush = $(if ($up) { $Brushes.Ok } else { $Brushes.Bad }) },
        @{ Name = "Karten-Tool";  Value = $(if ($mt) { "bereit" } else { "fehlt" });                                 Brush = $(if ($mt) { $Brushes.Ok } else { $Brushes.Warn }) },
        @{ Name = "Spiel entpackt"; Value = $(if ($ext) { "ja" } else { "nein" });                                   Brush = $(if ($ext) { $Brushes.Ok } else { $Brushes.Warn }) },
        @{ Name = "In Eden";      Value = $(if ($installed) { "installiert" } else { "noch nicht installiert" });   Brush = $(if ($installed) { $Brushes.Ok } else { $Brushes.Muted }) }
    )
    $ui.StatusList.ItemsSource = @($rows | ForEach-Object { New-Object PSObject -Property $_ })

    $script:CatItems.Clear()
    foreach ($k in $Categories.Keys) {
        $info = ""
        if ($ext) {
            $total = @(Get-ModelFiles $k).Count
            $done = Get-ModelDoneCount $k
            $unit = if ($Sources[$k].Kind -eq "wimdo") { "Modelle" } else { "Dateien" }
            $info = if ($total -eq 0) { "nicht vorhanden" } elseif ($done -ge $total) { "$total $unit - fertig" } else { "$done / $total $unit" }
        }
        $script:CatItems.Add((New-Row $k $Categories[$k] $info (@($Cfg.Folders) -contains $k)))
    }
    $script:MapItems.Clear()
    foreach ($m in (Get-MapList)) {
        $st = Get-MapState $m.Id
        $info = if ($st.Complete) { "fertig ($($st.Hd) HD)" } elseif ($st.Total -gt 0) { "$($st.Done) / $($st.Total)" } else { "$($m.SizeMB) MB" }
        $script:MapItems.Add((New-Row $m.Id $m.Id $info (@($Cfg.Maps) -contains $m.Id)))
    }
    $ui.TxtEden.Text = $Cfg.EdenData
    $ui.TxtUpscayl.Text = $(if ($up) { $up } else { "" })
    $ui.BtnSetup.Visibility = $(if ($toolsOk -and $ext) { "Collapsed" } else { "Visible" })
}

function Update-Models {
    $Cfg = Get-Cfg
    $ui.CbModel.Items.Clear()
    $m = Get-UpscaylModels
    foreach ($n in $m.Names) { [void]$ui.CbModel.Items.Add($n) }
    if ($m.Names -contains $Cfg.UpscaylModel) { $ui.CbModel.SelectedItem = $Cfg.UpscaylModel }
    elseif ($m.Names.Count) { $ui.CbModel.SelectedIndex = 0 }
}

function Init-Settings {
    $Cfg = Get-Cfg
    [void]$ui.CbSize.Items.Add((New-CbItem "Doppelt, bis 4096 px (beste Qualität)" "4096"))
    [void]$ui.CbSize.Items.Add((New-CbItem "Doppelt, bis 2048 px (kleiner, schneller)" "2048"))
    $ui.CbSize.SelectedValue = [string]$Cfg.MaxSize
    if ($ui.CbSize.SelectedIndex -lt 0) { $ui.CbSize.SelectedIndex = 0 }
    [void]$ui.CbQuality.Items.Add((New-CbItem "Beste (langsam)" "Slow"))
    [void]$ui.CbQuality.Items.Add((New-CbItem "Normal" "Normal"))
    [void]$ui.CbQuality.Items.Add((New-CbItem "Schnell" "Fast"))
    $ui.CbQuality.SelectedValue = [string]$Cfg.Quality
    if ($ui.CbQuality.SelectedIndex -lt 0) { $ui.CbQuality.SelectedIndex = 0 }
    foreach ($n in @(1, 2, 3, 4, 6, 8, 12, 16)) { [void]$ui.CbEncoders.Items.Add([string]$n) }
    $ui.CbEncoders.SelectedItem = [string]$Cfg.Encoders
    if ($ui.CbEncoders.SelectedIndex -lt 0) { $ui.CbEncoders.SelectedItem = "4" }
    $ui.ChkAutoInstall.IsChecked = [bool]$Cfg.AutoInstall
    Update-Models
}

function Save-UiSettings {
    $c = Get-Cfg
    if ($ui.CbModel.SelectedItem) { $c.UpscaylModel = [string]$ui.CbModel.SelectedItem }
    if ($ui.CbSize.SelectedValue) { $c.MaxSize = [int]$ui.CbSize.SelectedValue }
    if ($ui.CbQuality.SelectedValue) { $c.Quality = [string]$ui.CbQuality.SelectedValue }
    if ($ui.CbEncoders.SelectedItem) { $c.Encoders = [int]$ui.CbEncoders.SelectedItem }
    $c.AutoInstall = [bool]$ui.ChkAutoInstall.IsChecked
    $c.Folders = @($script:CatItems | Where-Object { $_.On } | ForEach-Object { $_.Id })
    $c.Maps = @($script:MapItems | Where-Object { $_.On } | ForEach-Object { $_.Id })
    Save-Cfg $c
}

# ---------------- Protokoll ----------------
$script:LogLines = New-Object System.Collections.Generic.List[string]
function Add-LogLine([string]$line) {
    $script:LogLines.Add($line)
    if ($script:LogLines.Count -gt 400) { $script:LogLines.RemoveRange(0, $script:LogLines.Count - 400) }
    $ui.TxtLog.Text = ($script:LogLines -join "`r`n")
    $ui.TxtLog.ScrollToEnd()
}

function Set-Chip([string]$text, [string]$brush) {
    $ui.ChipText.Text = $text
    $ui.Chip.Background = $Brushes[$brush]
    $ui.ChipText.Foreground = $(if ($brush -eq "Muted") { [Windows.Media.Brushes]::White } else { $window.FindResource("AccentText") })
}

# ---------------- Hintergrund-Job ----------------
$script:Sync = [hashtable]::Synchronized(@{})
$script:Job = $null

function Start-Work([string]$job) {
    if ($script:Busy) { return }
    Save-UiSettings
    $script:Sync.Clear()
    $script:Sync.Log = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
    $script:Sync.Stop = $false; $script:Sync.Phase = "Starte..."; $script:Sync.Done = 0; $script:Sync.Total = 0
    $script:Sync.Item = ""; $script:Sync.Eta = ""; $script:Sync.Error = $null; $script:Sync.Finished = $false; $script:Sync.Result = $null
    $script:Sync.JobName = $job

    $rs = [RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = "STA"; $rs.ThreadOptions = "ReuseThread"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("S", $script:Sync)
    $rs.SessionStateProxy.SetVariable("Root", $Root)
    $rs.SessionStateProxy.SetVariable("Xc3ImgSource", $Xc3ImgSource)
    $ps = [PowerShell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript(". ([scriptblock]::Create(`$args[0])); try { Invoke-Job `$args[1] } catch { `$S.Error = `$_.Exception.Message; Log ('FEHLER: ' + `$_.Exception.Message) 'bad' } finally { `$S.Finished = `$true }")
    [void]$ps.AddArgument($Engine.ToString()); [void]$ps.AddArgument($job)
    $script:Job = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
    $script:Busy = $true
    Set-BusyUi $true
    $script:Timer.Start()
}

function Set-BusyUi([bool]$busy) {
    foreach ($b in @("BtnStart","BtnInstall","BtnSetup","BtnCompare","BtnEden","BtnUpscayl","CbModel","CbSize","CbQuality","CbEncoders","CatList","MapList","BtnMapsAll","BtnMapsNone")) {
        $ui[$b].IsEnabled = -not $busy
    }
    $ui.BtnStop.IsEnabled = $busy
    $ui.BtnStop.Content = "Anhalten"
    if ($busy) { Set-Chip "Läuft" "Accent" }
}

$script:Timer = New-Object Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(300)
$script:Timer.Add_Tick({
    $s = $script:Sync
    $line = $null
    $added = $false
    while ($s.Log -and $s.Log.TryDequeue([ref]$line)) {
        $parts = $line.Split('|', 2)
        $script:LogLines.Add($parts[1]); $added = $true
    }
    if ($added) {
        if ($script:LogLines.Count -gt 400) { $script:LogLines.RemoveRange(0, $script:LogLines.Count - 400) }
        $ui.TxtLog.Text = ($script:LogLines -join "`r`n"); $ui.TxtLog.ScrollToEnd()
    }
    $ui.TxtPhase.Text = [string]$s.Phase
    $ui.TxtItem.Text = [string]$s.Item
    if ([int]$s.Total -gt 0) {
        $ui.Bar.IsIndeterminate = $false
        $ui.Bar.Value = [double]$s.Done / [double]$s.Total
        $ui.TxtEta.Text = ("{0} / {1}" -f $s.Done, $s.Total) + $(if ($s.Eta) { "  -  Rest ca. $($s.Eta) h" } else { "" })
    } else {
        $ui.Bar.IsIndeterminate = $script:Busy
        $ui.TxtEta.Text = ""
    }
    if ($s.Finished) {
        $script:Timer.Stop()
        try { $script:Job.PS.EndInvoke($script:Job.Handle) } catch {}
        try { $script:Job.PS.Dispose(); $script:Job.RS.Dispose() } catch {}
        $script:Busy = $false
        Set-BusyUi $false
        $ui.Bar.IsIndeterminate = $false
        if ($s.Error) { Set-Chip "Fehler" "Bad"; $ui.TxtPhase.Text = "Fehler: " + $s.Error }
        elseif ($s.Stop) { Set-Chip "Angehalten" "Warn"; $ui.TxtPhase.Text = "Angehalten - Start setzt an derselben Stelle fort" }
        else { Set-Chip "Fertig" "Ok"; $ui.TxtPhase.Text = "Fertig"; $ui.Bar.Value = 1 }
        $ui.TxtItem.Text = ""
        Update-Status
        Update-Models
        if ($s.JobName -eq "compare" -and $s.Result -and (Test-Path $s.Result)) { Start-Process $s.Result }
    }
})

# ---------------- Ereignisse ----------------
$ui.BtnStart.Add_Click({
    $sel = @($script:CatItems | Where-Object { $_.On }).Count + @($script:MapItems | Where-Object { $_.On }).Count
    if ($sel -eq 0 -and (Test-Extracted)) {
        [Windows.MessageBox]::Show($window, "Bitte zuerst links auswählen, was hochskaliert werden soll.", "XC3 HD Texturen") | Out-Null
        return
    }
    if (-not $ui.CbModel.SelectedItem) {
        [Windows.MessageBox]::Show($window, "Kein KI-Modell gefunden. Ist Upscayl installiert?", "XC3 HD Texturen") | Out-Null
        return
    }
    Start-Work "build"
})
$ui.BtnStop.Add_Click({
    $script:Sync.Stop = $true
    $ui.BtnStop.IsEnabled = $false
    $ui.BtnStop.Content = "Hält an..."
    Add-LogLine ("{0:HH:mm:ss}  Wird nach dem aktuellen Schritt angehalten..." -f (Get-Date))
})
$ui.BtnSetup.Add_Click({ Start-Work "setup" })
$ui.BtnCompare.Add_Click({ Start-Work "compare" })
$ui.BtnInstall.Add_Click({
    if (Test-EdenRunning) { [Windows.MessageBox]::Show($window, "Eden läuft gerade. Bitte zuerst schließen.", "XC3 HD Texturen") | Out-Null; return }
    Start-Work "install"
})
$ui.BtnFolder.Add_Click({ Start-Process explorer.exe $Root })
# Haekchen in den Listen -> Zustand in den Zeilen-Objekten
$onCheck = [Windows.RoutedEventHandler]{
    param($sender, $e)
    $cb = $e.OriginalSource
    if ($cb -is [Windows.Controls.CheckBox]) {
        foreach ($row in @($script:CatItems) + @($script:MapItems)) { if ($row.Id -eq $cb.Tag) { $row.On = [bool]$cb.IsChecked } }
    }
}
$ui.CatList.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, $onCheck)
$ui.MapList.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, $onCheck)
$ui.BtnMapsAll.Add_Click({ foreach ($m in @($script:MapItems)) { $m.On = $true }; $ui.MapList.Items.Refresh() })
$ui.BtnMapsNone.Add_Click({ foreach ($m in @($script:MapItems)) { $m.On = $false }; $ui.MapList.Items.Refresh() })
$ui.BtnEden.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Eden-Datenordner wählen (enthält die Ordner dump und load)"
    $d.SelectedPath = $ui.TxtEden.Text
    if ($d.ShowDialog() -eq "OK") { $c = Get-Cfg; $c.EdenData = $d.SelectedPath; Save-Cfg $c; Update-Status }
})
$ui.BtnUpscayl.Add_Click({
    $d = New-Object Microsoft.Win32.OpenFileDialog
    $d.Filter = "upscayl-bin.exe|upscayl-bin.exe"
    $d.Title = "upscayl-bin.exe auswählen (im Upscayl-Ordner unter resources\bin)"
    if ($d.ShowDialog($window)) { $c = Get-Cfg; $c.UpscaylBin = $d.FileName; Save-Cfg $c; Update-Status; Update-Models }
})
$window.Add_Closing({
    param($sender, $e)
    if ($script:Busy) {
        $r = [Windows.MessageBox]::Show($window, "Es läuft gerade noch etwas. Trotzdem beenden?`n`nDer Fortschritt bleibt erhalten, beim nächsten Start geht es weiter.", "XC3 HD Texturen", "YesNo")
        if ($r -ne "Yes") { $e.Cancel = $true; return }
        $script:Sync.Stop = $true
    }
    try { Save-UiSettings } catch {}
})

# ---------------- Start ----------------
Init-Settings
Update-Status
Set-Chip "Bereit" "Muted"
Add-LogLine ("{0:HH:mm:ss}  Arbeitsordner: {1}" -f (Get-Date), $Root)

if ($env:XC3HD_SNAPSHOT) {
    $window.Add_ContentRendered({
        $window.UpdateLayout()
        $w = [int]$window.ActualWidth; $h = [int]$window.ActualHeight
        $root = [Windows.Media.VisualTreeHelper]::GetChild($window, 0)
        $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
        $dv = New-Object Windows.Media.DrawingVisual
        $dc = $dv.RenderOpen()
        $dc.DrawRectangle($window.Background, $null, (New-Object Windows.Rect(0, 0, $w, $h)))
        $dc.DrawRectangle((New-Object Windows.Media.VisualBrush($root)), $null, (New-Object Windows.Rect(0, 0, $w, $h)))
        $dc.Close(); $rtb.Render($dv)
        $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [IO.File]::Create($env:XC3HD_SNAPSHOT); try { $enc.Save($fs) } finally { $fs.Close() }
        $window.Close()
    })
}
[void]$window.ShowDialog()
if ($script:Busy) {
    # Fenster wurde waehrend der Arbeit geschlossen: Hintergrundarbeit beenden (Fortschritt bleibt erhalten)
    try { $script:Job.PS.BeginStop($null, $null) | Out-Null } catch {}
    Start-Sleep -Milliseconds 500
    [Environment]::Exit(0)
}
