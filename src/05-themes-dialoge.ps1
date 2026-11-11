# ------------------------------------------------------------
#  UI-Hilfsfunktionen
# ------------------------------------------------------------
# ------------------------------------------------------------
#  Farbschema
# ------------------------------------------------------------
# Base/Color sind Text-Schluessel (Anzeige: "Dunkel (Cyan)")
$ThemePresets = [ordered]@{
    "dark-cyan"     = @{ Base = "ThBaseDark";  Color = "ThColCyan";   Bg = "#0F1419"; Panel = "#171D26"; Text = "#E6EDF3"; Accent = "#22D3EE" }
    "dark-blue"     = @{ Base = "ThBaseDark";  Color = "ThColBlue";   Bg = "#0E1320"; Panel = "#161D2E"; Text = "#E5EAF5"; Accent = "#60A5FA" }
    "dark-indigo"   = @{ Base = "ThBaseDark";  Color = "ThColIndigo"; Bg = "#0D0F1E"; Panel = "#15182B"; Text = "#E7E8F7"; Accent = "#818CF8" }
    "dark-violet"   = @{ Base = "ThBaseDark";  Color = "ThColViolet"; Bg = "#110F1A"; Panel = "#1A1726"; Text = "#ECE8F5"; Accent = "#A78BFA" }
    "dark-pink"     = @{ Base = "ThBaseDark";  Color = "ThColPink";   Bg = "#160F14"; Panel = "#21171E"; Text = "#F4E8EF"; Accent = "#F472B6" }
    "dark-red"      = @{ Base = "ThBaseDark";  Color = "ThColRed";    Bg = "#160F10"; Panel = "#211718"; Text = "#F4E9EA"; Accent = "#F87171" }
    "dark-orange"   = @{ Base = "ThBaseDark";  Color = "ThColOrange"; Bg = "#15110E"; Panel = "#1F1915"; Text = "#F3EBE4"; Accent = "#FB923C" }
    "dark-gold"     = @{ Base = "ThBaseDark";  Color = "ThColGold";   Bg = "#14120C"; Panel = "#1E1B13"; Text = "#F2EEE2"; Accent = "#FBBF24" }
    "dark-green"    = @{ Base = "ThBaseDark";  Color = "ThColGreen";  Bg = "#0E1512"; Panel = "#15201B"; Text = "#E4F0EA"; Accent = "#34D399" }
    "dark-grey"     = @{ Base = "ThBaseDark";  Color = "ThColGrey";   Bg = "#121212"; Panel = "#1C1C1E"; Text = "#EDEDED"; Accent = "#D4D4D8" }
    # Vorlagen mit eigenem Verlauf (Accent -> Accent2); ohne Accent2 wird die zweite Farbe berechnet
    "dark-aurora"   = @{ Base = "ThBaseDark";  Color = "ThColAurora"; Bg = "#0A1017"; Panel = "#111A24"; Text = "#E6EEF5"; Accent = "#2DD4BF"; Accent2 = "#8B5CF6" }
    "dark-sunset"   = @{ Base = "ThBaseDark";  Color = "ThColSunset"; Bg = "#140E12"; Panel = "#1F161B"; Text = "#F5EAEC"; Accent = "#FB923C"; Accent2 = "#EC4899" }
    "dark-synth"    = @{ Base = "ThBaseDark";  Color = "ThColSynth";  Bg = "#0F0B1A"; Panel = "#181228"; Text = "#EDE9F7"; Accent = "#F472B6"; Accent2 = "#22D3EE" }
    "amoled"        = @{ Base = "ThBaseBlack"; Color = "ThColCyan";   Bg = "#000000"; Panel = "#0D0D0D"; Text = "#EDEDED"; Accent = "#22D3EE" }
    "amoled-red"    = @{ Base = "ThBaseBlack"; Color = "ThColRed";    Bg = "#000000"; Panel = "#0D0D0D"; Text = "#EDEDED"; Accent = "#F87171" }
    "amoled-violet" = @{ Base = "ThBaseBlack"; Color = "ThColViolet"; Bg = "#000000"; Panel = "#0D0D0D"; Text = "#EDEDED"; Accent = "#A78BFA" }
    "light"         = @{ Base = "ThBaseLight"; Color = "ThColCyan";   Bg = "#F3F5F8"; Panel = "#FFFFFF"; Text = "#1B2430"; Accent = "#0891B2" }
    "light-violet"  = @{ Base = "ThBaseLight"; Color = "ThColViolet"; Bg = "#F5F3FA"; Panel = "#FFFFFF"; Text = "#221D33"; Accent = "#7C3AED" }
    "light-green"   = @{ Base = "ThBaseLight"; Color = "ThColGreen";  Bg = "#F2F6F4"; Panel = "#FFFFFF"; Text = "#17251F"; Accent = "#059669" }
    "light-sand"    = @{ Base = "ThBaseLight"; Color = "ThColSand";   Bg = "#F4EFE6"; Panel = "#FFFCF6"; Text = "#2B2620"; Accent = "#C2410C" }
}
$script:ThemeWin = $null
$script:ThemePick = ""
$script:ThemeCards = @{}

function ConvertTo-WpfColor([string]$hex, [string]$fallback) {
    try { return [System.Windows.Media.Color][System.Windows.Media.ColorConverter]::ConvertFromString($hex) }
    catch { return [System.Windows.Media.Color][System.Windows.Media.ColorConverter]::ConvertFromString($fallback) }
}

function ConvertTo-Hex($c) { return ("#{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B) }

function Merge-Color($a, $b, [double]$t) {
    $r  = [byte][math]::Round($a.R + ($b.R - $a.R) * $t)
    $g  = [byte][math]::Round($a.G + ($b.G - $a.G) * $t)
    $bl = [byte][math]::Round($a.B + ($b.B - $a.B) * $t)
    return [System.Windows.Media.Color]::FromRgb($r, $g, $bl)
}

function Get-Luma($c) { return (0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B) / 255 }

# Relative Helligkeit und Kontrast nach WCAG
function Get-RelLum($c) {
    $ch = foreach ($v in @($c.R, $c.G, $c.B)) {
        $x = $v / 255.0
        if ($x -le 0.03928) { $x / 12.92 } else { [Math]::Pow(($x + 0.055) / 1.055, 2.4) }
    }
    return 0.2126 * $ch[0] + 0.7152 * $ch[1] + 0.0722 * $ch[2]
}

function Get-Contrast($a, $b) {
    $l1 = Get-RelLum $a; $l2 = Get-RelLum $b
    return ([Math]::Max($l1, $l2) + 0.05) / ([Math]::Min($l1, $l2) + 0.05)
}

# Vordergrund so lange Richtung Schwarz bzw. Weiss schieben, bis der Kontrast reicht
function Get-Readable($fg, $bg, [double]$min) {
    if ((Get-Contrast $fg $bg) -ge $min) { return $fg }
    $target = if ((Get-RelLum $bg) -gt 0.18) { [System.Windows.Media.Colors]::Black } else { [System.Windows.Media.Colors]::White }
    for ($i = 1; $i -le 20; $i++) {
        $c = Merge-Color $fg $target ($i / 20)
        if ((Get-Contrast $c $bg) -ge $min) { return $c }
    }
    return $target
}

# HSV <-> Farbe (fuer den Farbwaehler)
function ConvertTo-Hsv($c) {
    $r = $c.R / 255.0; $g = $c.G / 255.0; $b = $c.B / 255.0
    $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b)); $d = $max - $min
    $h = 0.0
    if ($d -gt 0) {
        if ($max -eq $r)     { $h = 60 * ((($g - $b) / $d) % 6) }
        elseif ($max -eq $g) { $h = 60 * ((($b - $r) / $d) + 2) }
        else                 { $h = 60 * ((($r - $g) / $d) + 4) }
    }
    if ($h -lt 0) { $h += 360 }
    $sat = if ($max -eq 0) { 0.0 } else { $d / $max }
    return @{ H = $h; S = $sat; V = $max }
}

function ConvertFrom-Hsv([double]$h, [double]$sat, [double]$v) {
    $h = (($h % 360) + 360) % 360
    $c = $v * $sat; $x = $c * (1 - [Math]::Abs((($h / 60) % 2) - 1)); $m = $v - $c
    switch ([int][Math]::Floor($h / 60)) {
        0 { $r = $c; $g = $x; $b = 0 }  1 { $r = $x; $g = $c; $b = 0 }  2 { $r = 0; $g = $c; $b = $x }
        3 { $r = 0; $g = $x; $b = $c }  4 { $r = $x; $g = 0; $b = $c }  default { $r = $c; $g = 0; $b = $x }
    }
    return [System.Windows.Media.Color]::FromRgb([byte][Math]::Round(($r + $m) * 255), [byte][Math]::Round(($g + $m) * 255), [byte][Math]::Round(($b + $m) * 255))
}

# ------------------------------------------------------------
#  Titelleiste und Icon im Theme
# ------------------------------------------------------------
if (-not ('DwmTheme' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DwmTheme {
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
    public static void Apply(IntPtr hwnd, bool dark, int caption, int border, int text) {
        int d = dark ? 1 : 0;
        DwmSetWindowAttribute(hwnd, 20, ref d, 4);       // dunkle Titelleiste (Win10 20H1+ / Win11)
        DwmSetWindowAttribute(hwnd, 19, ref d, 4);       // aeltere Win10-Builds
        DwmSetWindowAttribute(hwnd, 35, ref caption, 4); // Titelleistenfarbe (Win11)
        DwmSetWindowAttribute(hwnd, 34, ref border, 4);  // Rahmenfarbe (Win11)
        DwmSetWindowAttribute(hwnd, 36, ref text, 4);    // Titeltext (Win11)
    }
}
'@
}

$script:ThemeColors = $null
# Einfarbige Pinsel und Verlaeufe, die dem Theme folgen (werden auch an Dialoge weitergegeben)
$script:ThemeSolid = @("BrBg","BrPanel","BrPanel2","BrCard","BrLine","BrText","BrMuted","BrAccent","BrAccent2","BrAccentFg","BrSel","BrSelStrong","BrLog","BrBadgeNewBg","BrBadgeNewFg","BrBadgeInstBg","BrAccentText")
$script:ThemeKeys  = $script:ThemeSolid + @("GrAccent","GrHero","GlowA","GlowB")
$script:ThemeAnimate = $false   # ab dem ersten Bild wird ein Theme-Wechsel animiert
$script:ThemeInstant = $false   # ohne Animation (z.B. beim Ziehen im Farbwaehler)
$script:ThemeFxOrigin = $null   # Punkt im Theme-Fenster, von dem aus sich das neue Theme ausbreitet
$script:ThemeFxGen = 0

function ConvertTo-ColorRef($c) { return ([int]$c.R -bor ([int]$c.G -shl 8) -bor ([int]$c.B -shl 16)) }

function Set-TitleBar($win) {
    try {
        if (-not $win -or -not $script:ThemeColors) { return }
        $h = [System.Windows.Interop.WindowInteropHelper]::new($win).Handle
        if ($h -eq [IntPtr]::Zero) { return }
        $t = $script:ThemeColors
        [DwmTheme]::Apply($h, [bool]$t.Dark, (ConvertTo-ColorRef $t.Bg), (ConvertTo-ColorRef $t.Line), (ConvertTo-ColorRef $t.Text))
    } catch {}
}

# App-Icon (Fenster + Taskleiste) = das EXE-Icon: Kreispfeil mit Download-Pfeil auf Cyan-Verlauf
function New-AppIcon {
    $C   = [System.Windows.Media.Color]
    $bg  = [System.Windows.Media.LinearGradientBrush]::new($C::FromRgb(0x5E, 0xEA, 0xF4), $C::FromRgb(0x0E, 0x74, 0x90),
            [System.Windows.Point]::new(0, 0), [System.Windows.Point]::new(1, 1))
    $ink = [System.Windows.Media.SolidColorBrush]::new($C::FromRgb(0xF4, 0xFD, 0xFF))
    $pen = [System.Windows.Media.Pen]::new($ink, 5)
    $pen.StartLineCap = "Round"; $pen.EndLineCap = "Round"; $pen.LineJoin = "Round"
    $G = [System.Windows.Media.Geometry]

    $dv = [System.Windows.Media.DrawingVisual]::new()
    $dc = $dv.RenderOpen()
    $dc.PushTransform([System.Windows.Media.ScaleTransform]::new(4, 4))   # 64er Zeichnung -> 256 px
    $dc.DrawRoundedRectangle($bg, $null, [System.Windows.Rect]::new(2, 2, 60, 60), 15, 15)
    $dc.DrawGeometry($null, $pen, $G::Parse("M 42.61,19.36 A 16.5,16.5 0 1 1 19.36,21.39"))
    $dc.DrawGeometry($ink, $null, $G::Parse("M 24.5,15.26 L 14.76,17.53 L 23.96,25.25 Z"))
    $dc.DrawGeometry($null, $pen, $G::Parse("M 32,23 L 32,39 M 25.5,33.5 L 32,40 L 38.5,33.5"))
    $dc.Pop()
    $dc.Close()
    $bmp = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(256, 256, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($dv)
    $bmp.Freeze()
    return $bmp
}

function Get-AlphaColor($c, [int]$alpha) {
    return [System.Windows.Media.Color]::FromArgb([byte]$alpha, $c.R, $c.G, $c.B)
}

# Zweite Akzentfarbe fuer Verlaeufe: gleicher Ton, im Farbkreis ein Stueck weiter
# (warme Farben wandern Richtung Rot, kalte Richtung Blau/Violett)
function Get-Accent2($c) {
    $h = ConvertTo-Hsv $c
    if ($h.S -lt 0.08) { return (Merge-Color $c ([System.Windows.Media.Colors]::Gray) 0.35) }
    $shift = if ($h.H -lt 75 -or $h.H -ge 345) { -28 } else { 32 }
    return (ConvertFrom-Hsv ($h.H + $shift) $h.S $h.V)
}

# Pinsel werden bei jedem Theme-Wechsel neu angelegt und eingefroren
# (WPF friert Pinsel ein, sobald eine Vorlage sie nutzt - sie lassen sich danach nicht mehr aendern).
function Set-ThemeResource([string]$key, $value) {
    $window.Resources[$key] = $value
    if ($script:ThemeWin) { $script:ThemeWin.Resources[$key] = $value }
}

function Set-ThemeBrush([string]$key, $color) {
    $b = [System.Windows.Media.SolidColorBrush]::new($color)
    $b.Freeze()
    Set-ThemeResource $key $b
}

# Verlauf aus (Farbe, Position)-Paaren; $radial = kreisfoermig, sonst von links oben nach ($ex,$ey)
function Set-ThemeGradient([string]$key, [bool]$radial, [double]$ex, [double]$ey, $stops) {
    if ($radial) { $b = [System.Windows.Media.RadialGradientBrush]::new() }
    else {
        $b = [System.Windows.Media.LinearGradientBrush]::new()
        $b.StartPoint = [System.Windows.Point]::new(0, 0)
        $b.EndPoint   = [System.Windows.Point]::new($ex, $ey)
    }
    foreach ($st in $stops) { $b.GradientStops.Add([System.Windows.Media.GradientStop]::new($st[0], [double]$st[1])) }
    $b.Freeze()
    Set-ThemeResource $key $b
}

# Theme-Wechsel als "Welle": das Fenster wird mit dem alten Theme fotografiert, das Foto liegt kurz
# ueber der Oberflaeche und bekommt ein wachsendes Loch - darunter erscheint das neue Theme.
function New-ThemeReveal($win, $origin) {
    try {
        if (-not $win -or -not $win.IsVisible) { return $null }
        $root = $win.Content
        $img  = $win.FindName("ThemeFx")
        if (-not $img -or -not $root) { return $null }
        $w = [double]$root.ActualWidth; $h = [double]$root.ActualHeight
        if ($w -lt 2 -or $h -lt 2) { return $null }
        $scale = 1.0
        try {
            $src = [System.Windows.PresentationSource]::FromVisual($win)
            if ($src) { $scale = [double]$src.CompositionTarget.TransformToDevice.M11 }
        } catch {}
        $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new([int][Math]::Ceiling($w * $scale), [int][Math]::Ceiling($h * $scale), 96 * $scale, 96 * $scale, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($root)
        $rtb.Freeze()
        if (-not $origin) { $origin = [System.Windows.Point]::new($w / 2, $h / 2) }
        $hole = [System.Windows.Media.EllipseGeometry]::new($origin, 0, 0)
        $full = [System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0, 0, $w, $h))
        $img.Clip   = [System.Windows.Media.CombinedGeometry]::new([System.Windows.Media.GeometryCombineMode]::Exclude, $full, $hole)
        $img.Source = $rtb
        $img.Visibility = "Visible"
        $dx = [Math]::Max($origin.X, $w - $origin.X); $dy = [Math]::Max($origin.Y, $h - $origin.Y)
        return @{ Img = $img; Hole = $hole; Radius = [Math]::Sqrt($dx * $dx + $dy * $dy) + 4 }
    } catch { return $null }
}

function Start-ThemeReveal($fx) {
    if (-not $fx) { return }
    $script:ThemeFxGen++
    $img = $fx.Img
    $gen = $script:ThemeFxGen
    $img.Tag = $gen
    $a = [System.Windows.Media.Animation.DoubleAnimation]::new(0.0, [double]$fx.Radius, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(560)))
    $ease = [System.Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseInOut
    $a.EasingFunction = $ease
    # Aufraeumen nur, wenn inzwischen kein neuerer Wechsel gestartet wurde
    $a.Add_Completed({
        if ($img.Tag -eq $gen) { $img.Visibility = "Collapsed"; $img.Source = $null; $img.Clip = $null }
    }.GetNewClosure())
    $fx.Hole.BeginAnimation([System.Windows.Media.EllipseGeometry]::RadiusXProperty, $a)
    $fx.Hole.BeginAnimation([System.Windows.Media.EllipseGeometry]::RadiusYProperty, $a)
}

# Aus 4 Grundfarben werden alle weiteren Farben abgeleitet.
# Lesbarkeit wird erzwungen: Text >= 4.5:1, gedaempfter Text und Akzent-Text >= 3:1.
$script:ThemeSig = $null
function Set-Theme($t) {
    $sig = "{0}|{1}|{2}|{3}|{4}" -f $t.Bg, $t.Panel, $t.Text, $t.Accent, $t.Accent2
    if ($sig -eq $script:ThemeSig) {
        $script:ThemeFxOrigin = $null
        if ($script:ThemeWin) { Set-TitleBar $script:ThemeWin }
        return
    }
    $script:ThemeSig = $sig
    # altes Aussehen festhalten (nur wenn animiert werden soll)
    $fx = @()
    if ($script:ThemeAnimate -and -not $script:ThemeInstant -and -not $script:Snapshot) {
        $fx += New-ThemeReveal $window $null
        if ($script:ThemeWin) { $fx += New-ThemeReveal $script:ThemeWin $script:ThemeFxOrigin }
    }
    $script:ThemeFxOrigin = $null
    $bg     = ConvertTo-WpfColor $t.Bg     "#0F1419"
    $panel  = ConvertTo-WpfColor $t.Panel  "#171D26"
    $text   = ConvertTo-WpfColor $t.Text   "#E6EDF3"
    $accent = ConvertTo-WpfColor $t.Accent "#22D3EE"
    $black  = [System.Windows.Media.Colors]::Black
    $white  = [System.Windows.Media.Colors]::White
    $light  = ((Get-RelLum $panel) -gt 0.18)
    $amoled = ((Get-RelLum $bg) -lt 0.002)

    $text       = Get-Readable (Get-Readable $text $panel 4.5) $bg 4.5
    $panel2     = Merge-Color $panel $text 0.045
    $line       = Merge-Color $panel $text $(if ($light) { 0.16 } else { 0.14 })
    $muted      = Get-Readable (Merge-Color $text $panel 0.42) $panel 3.0
    $accentText = Get-Readable $accent $panel 3.0
    $accent2    = if ($t.Accent2) { ConvertTo-WpfColor $t.Accent2 "#22D3EE" } else { Get-Accent2 $accent }
    $sel        = Merge-Color $panel $accent 0.18
    $selStrong  = Merge-Color $panel2 $accent 0.32
    $log        = if ($light) { Merge-Color $panel $text 0.03 } else { Merge-Color $bg $black 0.35 }
    # Schrift auf dem Akzent-Verlauf muss auf beiden Enden lesbar sein
    $darkFg     = Merge-Color $accent $black 0.88
    $cWhite     = [Math]::Min((Get-Contrast $white $accent), (Get-Contrast $white $accent2))
    $cDark      = [Math]::Min((Get-Contrast $darkFg $accent), (Get-Contrast $darkFg $accent2))
    $accentFg   = if ($cWhite -ge $cDark) { $white } else { $darkFg }
    $green      = ConvertTo-WpfColor "#34D399" "#34D399"
    $greenBg    = Merge-Color $panel $green 0.20
    $greenFg    = Get-Readable $green $greenBg 3.0

    Set-ThemeBrush "BrBg"          $bg
    Set-ThemeBrush "BrPanel"       $panel
    Set-ThemeBrush "BrPanel2"      $panel2
    Set-ThemeBrush "BrCard"        (Get-AlphaColor $panel $(if ($light) { 0xEB } else { 0xD9 }))
    Set-ThemeBrush "BrLine"        $line
    Set-ThemeBrush "BrText"        $text
    Set-ThemeBrush "BrMuted"       $muted
    Set-ThemeBrush "BrAccent"      $accent
    Set-ThemeBrush "BrAccent2"     $accent2
    Set-ThemeBrush "BrAccentText"  $accentText
    Set-ThemeBrush "BrAccentFg"    $accentFg
    Set-ThemeBrush "BrSel"         $sel
    Set-ThemeBrush "BrSelStrong"   $selStrong
    Set-ThemeBrush "BrLog"         $log
    Set-ThemeBrush "BrBadgeNewBg"  $greenBg
    Set-ThemeBrush "BrBadgeNewFg"  $greenFg
    Set-ThemeBrush "BrBadgeInstBg" (Merge-Color $panel $accent 0.20)

    # Verlaeufe: Akzent -> zweite Akzentfarbe, dazu das Leuchten im Hintergrund (auf reinem Schwarz dezenter)
    $aGlowA = if ($amoled) { 0x24 } elseif ($light) { 0x30 } else { 0x36 }
    $aGlowB = if ($amoled) { 0x18 } elseif ($light) { 0x22 } else { 0x26 }
    $aHero  = if ($light) { 0x24 } else { 0x2C }
    Set-ThemeGradient "GrAccent" $false 1 1 @(@($accent, 0), @($accent2, 1))
    Set-ThemeGradient "GrHero"   $false 1 0 @(@((Get-AlphaColor $accent $aHero), 0), @((Get-AlphaColor $accent2 ([int]($aHero * 0.3))), 0.55), @((Get-AlphaColor $accent2 0), 1))
    Set-ThemeGradient "GlowA"    $true  0 0 @(@((Get-AlphaColor $accent $aGlowA), 0), @((Get-AlphaColor $accent 0), 1))
    Set-ThemeGradient "GlowB"    $true  0 0 @(@((Get-AlphaColor $accent2 $aGlowB), 0), @((Get-AlphaColor $accent2 0), 1))

    $script:ThemeColors = @{ Bg = $bg; Text = $text; Line = $line; Dark = (-not $light) }
    Set-TitleBar $window
    if ($script:ThemeWin) { Set-TitleBar $script:ThemeWin }
    if (-not $window.Icon) { try { $window.Icon = New-AppIcon } catch {} }
    foreach ($f in $fx) { Start-ThemeReveal $f }
}

function Get-ThemeKey {
    $k = [string]$script:Settings.ThemePreset
    if ($k -eq "custom" -and $script:Settings.CustomTheme -and $script:Settings.CustomTheme.Bg) { return "custom" }
    if ($k -and $ThemePresets.Contains($k)) { return $k }
    return "dark-cyan"
}

# Die 4 Grundfarben eines Themes (Vorlage oder eigenes)
function Get-ThemeColors([string]$id) {
    if ($id -eq "custom") {
        $c = $script:Settings.CustomTheme
        if ($c -and $c.Bg) { return @{ Bg = [string]$c.Bg; Panel = [string]$c.Panel; Text = [string]$c.Text; Accent = [string]$c.Accent } }
        $id = "dark-cyan"
    }
    if (-not $ThemePresets.Contains($id)) { $id = "dark-cyan" }
    $p = $ThemePresets[$id]
    $c = @{ Bg = $p.Bg; Panel = $p.Panel; Text = $p.Text; Accent = $p.Accent }
    if ($p.Accent2) { $c.Accent2 = $p.Accent2 }
    return $c
}

$script:CurrentThemeId = "dark-cyan"
function Set-ThemeById([string]$id) {
    $script:CurrentThemeId = $id
    Set-Theme (Get-ThemeColors $id)
}
function Set-ThemeByKey([string]$key) { Set-ThemeById $key }

function Get-ThemeLabel([string]$key) {
    if ($key -eq "custom") { return (T "ThCustom") }
    if (-not $ThemePresets.Contains($key)) { $key = "dark-cyan" }
    $p = $ThemePresets[$key]
    return ("{0} ({1})" -f (T $p.Base), (T $p.Color))
}

function Update-ThemeLabel {
    $ui.TxtThemeName.Text = Get-ThemeLabel (Get-ThemeKey)
}

$themeDlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="{DynamicResource L_ThemeTitle}" Width="800" Height="660" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" UseLayoutRounding="True"
        Background="{DynamicResource BrBg}" Foreground="{DynamicResource BrText}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13">
  __RES__
  <Grid Background="{DynamicResource BrBg}">
  <Canvas IsHitTestVisible="False" ClipToBounds="True">
    <Ellipse Width="620" Height="620" Canvas.Left="-260" Canvas.Top="-340" Fill="{DynamicResource GlowA}"/>
    <Ellipse Width="700" Height="700" Canvas.Right="-300" Canvas.Bottom="-420" Fill="{DynamicResource GlowB}"/>
  </Canvas>
  <Grid Margin="26,22,26,22">
    <Grid.Resources>
      <!-- Farbfeld-Auswahl links (Hintergrund, Flaechen, Text, Akzent) -->
      <Style x:Key="Slot" TargetType="Button">
        <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
        <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
        <Setter Property="Margin" Value="0,0,0,8"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="Button">
              <Grid>
                <Border Background="{DynamicResource BrCard}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="2"
                        CornerRadius="13" Padding="12,10">
                  <ContentPresenter/>
                </Border>
                <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="13" Opacity="0" IsHitTestVisible="False"/>
              </Grid>
              <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="hl" Property="Opacity" Value="0.05"/>
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Style>
    </Grid.Resources>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0">
      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_ThemeTag}"/>
      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_ThemeTitle}" FontSize="26" FontWeight="SemiBold" Margin="0,2,0,3"/>
      <TextBlock x:Name="TxtDlgHint" Style="{StaticResource Hint}"/>
    </StackPanel>

    <Border Grid.Row="1" Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"
            CornerRadius="14" Padding="4" HorizontalAlignment="Left" Margin="0,16,0,16">
      <StackPanel Orientation="Horizontal">
        <Button x:Name="TabPresets" Tag="&#xE8FD;" Content="{DynamicResource L_ThTabPresets}" Style="{StaticResource BtnGhost}" Padding="14,7"/>
        <Button x:Name="TabCustom" Tag="&#xE790;" Content="{DynamicResource L_ThTabCustom}" Style="{StaticResource BtnGhost}" Padding="14,7" Margin="4,0,0,0"/>
      </StackPanel>
    </Border>

    <!-- Vorlagen -->
    <ScrollViewer x:Name="PagePresets" Grid.Row="2" VerticalScrollBarVisibility="Auto">
      <StackPanel Margin="0,0,6,0">
        <TextBlock x:Name="HdrDark" Style="{StaticResource Label}" Margin="2,0,0,10"/>
        <WrapPanel x:Name="HostDark"/>
        <TextBlock x:Name="HdrBlack" Style="{StaticResource Label}" Margin="2,8,0,10"/>
        <WrapPanel x:Name="HostBlack"/>
        <TextBlock x:Name="HdrLight" Style="{StaticResource Label}" Margin="2,8,0,10"/>
        <WrapPanel x:Name="HostLight"/>
      </StackPanel>
    </ScrollViewer>

    <!-- Eigenes Theme -->
    <Grid x:Name="PageCustom" Grid.Row="2" Visibility="Collapsed">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="240"/>
        <ColumnDefinition Width="22"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0">
        <Button x:Name="SlotBg" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwBg" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotBg}"/>
              <TextBlock x:Name="HxBg" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Button x:Name="SlotPanel" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwPanel" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotPanel}"/>
              <TextBlock x:Name="HxPanel" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Button x:Name="SlotText" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwText" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotText}"/>
              <TextBlock x:Name="HxText" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Button x:Name="SlotAccent" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwAccent" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotAccent}"/>
              <TextBlock x:Name="HxAccent" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Border Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="13"
                Padding="12,10" Margin="0,6,0,0">
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="DotContrast" Width="9" Height="9" VerticalAlignment="Center" Fill="{DynamicResource BrBadgeNewFg}"/>
            <TextBlock x:Name="TxtContrast" TextWrapping="Wrap" FontSize="12" Margin="9,0,0,0" MaxWidth="190" VerticalAlignment="Center"/>
          </StackPanel>
        </Border>
      </StackPanel>

      <Border Grid.Column="2" Style="{StaticResource Card}" Padding="18">
        <StackPanel>
          <Grid x:Name="SvBox" Width="436" Height="236" Cursor="Cross" Background="Transparent" ClipToBounds="True">
            <Rectangle x:Name="SvHue" RadiusX="10" RadiusY="10" Fill="Red"/>
            <Rectangle RadiusX="10" RadiusY="10">
              <Rectangle.Fill>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                  <GradientStop Color="#FFFFFFFF" Offset="0"/>
                  <GradientStop Color="#00FFFFFF" Offset="1"/>
                </LinearGradientBrush>
              </Rectangle.Fill>
            </Rectangle>
            <Rectangle RadiusX="10" RadiusY="10">
              <Rectangle.Fill>
                <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                  <GradientStop Color="#00000000" Offset="0"/>
                  <GradientStop Color="#FF000000" Offset="1"/>
                </LinearGradientBrush>
              </Rectangle.Fill>
            </Rectangle>
            <Canvas IsHitTestVisible="False">
              <Grid x:Name="SvDot" Width="20" Height="20">
                <Ellipse Stroke="#99000000" StrokeThickness="1"/>
                <Ellipse Margin="1" Stroke="White" StrokeThickness="2.5"/>
              </Grid>
            </Canvas>
          </Grid>
          <Grid x:Name="HueBar" Width="436" Height="16" Margin="0,16,0,0" Cursor="Hand" Background="Transparent">
            <Rectangle RadiusX="8" RadiusY="8">
              <Rectangle.Fill>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                  <GradientStop Color="#FF0000" Offset="0"/>
                  <GradientStop Color="#FFFF00" Offset="0.1667"/>
                  <GradientStop Color="#00FF00" Offset="0.3333"/>
                  <GradientStop Color="#00FFFF" Offset="0.5"/>
                  <GradientStop Color="#0000FF" Offset="0.6667"/>
                  <GradientStop Color="#FF00FF" Offset="0.8333"/>
                  <GradientStop Color="#FF0000" Offset="1"/>
                </LinearGradientBrush>
              </Rectangle.Fill>
            </Rectangle>
            <Canvas IsHitTestVisible="False">
              <Border x:Name="HueThumb" Width="10" Height="24" Canvas.Top="-4" CornerRadius="5" Background="White"
                      BorderBrush="#99000000" BorderThickness="1"/>
            </Canvas>
          </Grid>
          <Grid Margin="0,18,0,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border x:Name="PickSwatch" Width="38" Height="38" CornerRadius="9" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <TextBlock Grid.Column="1" Text="HEX" Style="{StaticResource Label}" VerticalAlignment="Center" Margin="14,0,10,0"/>
            <TextBox x:Name="TxtHex" Grid.Column="2" Width="130" HorizontalAlignment="Left" FontFamily="Cascadia Mono, Consolas" MaxLength="7"/>
          </Grid>
        </StackPanel>
      </Border>
    </Grid>

    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
      <Button x:Name="BtnThemeCancel" Content="{DynamicResource L_Cancel}" Style="{StaticResource Btn}"/>
      <Button x:Name="BtnThemeOk" Tag="&#xE73E;" Content="{DynamicResource L_Apply}" Style="{StaticResource BtnPrimary}" Margin="8,0,0,0"/>
    </StackPanel>
  </Grid>
  <Image x:Name="ThemeFx" Visibility="Collapsed" IsHitTestVisible="False" Stretch="Fill"/>
  </Grid>
</Window>
'@

$themeCardXaml = @'
<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Tag="@@KEY@@" Width="164" Height="120" Margin="0,0,12,12" Padding="0" Cursor="Hand" FocusVisualStyle="{x:Null}"
        BorderThickness="2" BorderBrush="Transparent" Background="Transparent">
  <Button.Template>
    <ControlTemplate TargetType="Button">
      <Grid RenderTransformOrigin="0.5,0.5">
        <Grid.RenderTransform>
          <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
        </Grid.RenderTransform>
        <Border Background="@@BG@@" CornerRadius="14" BorderBrush="#38808080" BorderThickness="1"/>
        <Grid Margin="10,10,10,8">
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="28"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Margin="1,3,0,0">
              <Border Width="15" Height="15" CornerRadius="5" HorizontalAlignment="Left">
                <Border.Background>
                  <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="@@ACCENT@@" Offset="0"/>
                    <GradientStop Color="@@ACCENT2@@" Offset="1"/>
                  </LinearGradientBrush>
                </Border.Background>
              </Border>
              <Border Width="17" Height="3" CornerRadius="1.5" Background="@@ACCENT@@" Margin="0,9,0,0" HorizontalAlignment="Left"/>
              <Border Width="17" Height="3" CornerRadius="1.5" Background="@@TEXT@@" Opacity="0.3" Margin="0,6,0,0" HorizontalAlignment="Left"/>
              <Border Width="17" Height="3" CornerRadius="1.5" Background="@@TEXT@@" Opacity="0.3" Margin="0,6,0,0" HorizontalAlignment="Left"/>
            </StackPanel>
            <Border Grid.Column="1" Background="@@PANEL@@" CornerRadius="8" Padding="9,8,8,7" BorderBrush="#20808080" BorderThickness="1">
              <StackPanel>
                <Border Background="@@TEXT@@" Height="5" Width="52" CornerRadius="2.5" HorizontalAlignment="Left" Opacity="0.9"/>
                <Border Background="@@TEXT@@" Height="3" Width="80" CornerRadius="1.5" HorizontalAlignment="Left" Margin="0,7,0,0" Opacity="0.4"/>
                <Border Background="@@TEXT@@" Height="3" Width="60" CornerRadius="1.5" HorizontalAlignment="Left" Margin="0,5,0,0" Opacity="0.4"/>
                <Border Height="11" Width="46" CornerRadius="5.5" HorizontalAlignment="Left" Margin="0,9,0,0">
                  <Border.Background>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                      <GradientStop Color="@@ACCENT@@" Offset="0"/>
                      <GradientStop Color="@@ACCENT2@@" Offset="1"/>
                    </LinearGradientBrush>
                  </Border.Background>
                </Border>
              </StackPanel>
            </Border>
          </Grid>
          <TextBlock FontFamily="{DynamicResource FontHead}" Grid.Row="1" Text="@@LABEL@@" Foreground="@@TEXT@@" FontSize="11.5" FontWeight="SemiBold"
                     Margin="2,7,0,0" TextTrimming="CharacterEllipsis"/>
        </Grid>
        <Border CornerRadius="14" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"/>
      </Grid>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Panel.ZIndex" Value="2"/>
          <Trigger.EnterActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1.05" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1.05" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation>
            </Storyboard></BeginStoryboard>
          </Trigger.EnterActions>
          <Trigger.ExitActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.16"/>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.16"/>
            </Storyboard></BeginStoryboard>
          </Trigger.ExitActions>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Trigger.EnterActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="0.97" Duration="0:0:0.08"/>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="0.97" Duration="0:0:0.08"/>
            </Storyboard></BeginStoryboard>
          </Trigger.EnterActions>
        </Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>
  </Button.Template>
</Button>
'@

function Update-ThemeCards {
    foreach ($k in $script:ThemeCards.Keys) {
        $btn = $script:ThemeCards[$k]
        if ($k -eq $script:ThemePick) {
            $btn.SetResourceReference([System.Windows.Controls.Control]::BorderBrushProperty, "BrAccent")
        } else {
            $btn.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        }
    }
}

function New-Brush([string]$hex) {
    $b = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-WpfColor $hex "#000000"))
    $b.Freeze()
    return $b
}

# Reiter im Theme-Fenster
function Set-ThemeTab([string]$tab) {
    $d = $script:Dlg
    $c = [System.Windows.Controls.Control]
    foreach ($pair in @(@($d.TabPresets, "presets"), @($d.TabCustom, "custom"))) {
        if ($pair[1] -eq $tab) {
            $pair[0].SetResourceReference($c::BackgroundProperty, "BrSel")
            $pair[0].SetResourceReference($c::ForegroundProperty, "BrAccentText")
        } else {
            $pair[0].ClearValue($c::BackgroundProperty)
            $pair[0].ClearValue($c::ForegroundProperty)
        }
    }
    $d.PagePresets.Visibility = if ($tab -eq "presets") { "Visible" } else { "Collapsed" }
    $d.PageCustom.Visibility  = if ($tab -eq "custom")  { "Visible" } else { "Collapsed" }
    $d.TxtDlgHint.Text = if ($tab -eq "custom") { T "ThCustomHint" } else { T "ThemeHint" }
    if ($tab -eq "custom" -and $script:ThemePick -ne "custom") {
        # Eigenes Theme startet mit den Farben der zuletzt gewaehlten Vorlage
        $script:Draft = Get-ThemeColors $script:ThemePick
        $script:Draft.Remove("Accent2")
        $script:ThemePick = "custom"
        Set-Theme $script:Draft
        Update-ThemeCards
    }
    if ($tab -eq "custom") { Set-PickerFromHex $script:Draft[$script:Slot]; Update-Slots }
}

# Farbfelder links + Lesbarkeit
function Update-Slots {
    $d = $script:Dlg
    foreach ($slot in @("Bg", "Panel", "Text", "Accent")) {
        $hex = [string]$script:Draft[$slot]
        $d["Sw$slot"].Background = New-Brush $hex
        $d["Hx$slot"].Text = $hex.ToUpper()
        $btn = $d["Slot$slot"]
        if ($slot -eq $script:Slot) { $btn.SetResourceReference([System.Windows.Controls.Control]::BorderBrushProperty, "BrAccent") }
        else { $btn.SetResourceReference([System.Windows.Controls.Control]::BorderBrushProperty, "BrLine") }
    }
    $ratio = Get-Contrast (ConvertTo-WpfColor $script:Draft.Text "#FFFFFF") (ConvertTo-WpfColor $script:Draft.Panel "#000000")
    $ok = $ratio -ge 4.5
    $d.TxtContrast.Text = (TF "ThContrast" ([Math]::Round($ratio, 1))) + "  –  " + $(if ($ok) { T "ThContrastOk" } else { T "ThContrastLow" })
    if ($ok) { $d.DotContrast.SetResourceReference([System.Windows.Shapes.Shape]::FillProperty, "BrBadgeNewFg") }
    else     { $d.DotContrast.Fill = New-Brush "#F59E0B" }
}

# Farbwaehler
$script:Pick = @{ H = 0.0; S = 0.0; V = 0.0 }
$script:PickWatch = [Diagnostics.Stopwatch]::StartNew()

function Set-PickerFromHex([string]$hex) {
    $script:Pick = ConvertTo-Hsv (ConvertTo-WpfColor $hex "#000000")
    Update-PickerVisual
}

function Update-PickerVisual {
    $d = $script:Dlg
    $w = $d.SvBox.Width; $h = $d.SvBox.Height
    $d.SvHue.Fill = [System.Windows.Media.SolidColorBrush]::new((ConvertFrom-Hsv $script:Pick.H 1 1))
    [System.Windows.Controls.Canvas]::SetLeft($d.SvDot, $script:Pick.S * $w - 10)
    [System.Windows.Controls.Canvas]::SetTop($d.SvDot, (1 - $script:Pick.V) * $h - 10)
    [System.Windows.Controls.Canvas]::SetLeft($d.HueThumb, $script:Pick.H / 360 * $d.HueBar.Width - 5)
    $c = ConvertFrom-Hsv $script:Pick.H $script:Pick.S $script:Pick.V
    $d.PickSwatch.Background = [System.Windows.Media.SolidColorBrush]::new($c)
    if (-not $d.TxtHex.IsKeyboardFocused) { $d.TxtHex.Text = ConvertTo-Hex $c }
}

# Aktuelle Picker-Farbe ins gewaehlte Feld schreiben (Vorschau gedrosselt, damit das Ziehen fluessig bleibt)
function Commit-Picker([bool]$force) {
    $script:Draft[$script:Slot] = ConvertTo-Hex (ConvertFrom-Hsv $script:Pick.H $script:Pick.S $script:Pick.V)
    Update-Slots
    if ($force -or $script:PickWatch.ElapsedMilliseconds -gt 60) {
        $script:ThemeInstant = $true
        try { Set-Theme $script:Draft } finally { $script:ThemeInstant = $false }
        $script:PickWatch.Restart()
    }
}

function Set-PickFromSv($pt) {
    $d = $script:Dlg
    $script:Pick.S = [Math]::Min(1.0, [Math]::Max(0.0, $pt.X / $d.SvBox.Width))
    $script:Pick.V = [Math]::Min(1.0, [Math]::Max(0.0, 1 - $pt.Y / $d.SvBox.Height))
    Update-PickerVisual
}

function Set-PickFromHue($pt) {
    $script:Pick.H = [Math]::Min(359.9, [Math]::Max(0.0, $pt.X / $script:Dlg.HueBar.Width * 360))
    Update-PickerVisual
}

function Set-HexFromBox {
    $t = $script:Dlg.TxtHex.Text.Trim()
    if ($t -match '^#?([0-9a-fA-F]{6})$') {
        $hex = "#" + $Matches[1].ToUpper()
        $script:Draft[$script:Slot] = $hex
        Set-PickerFromHex $hex
        Update-Slots
        Set-Theme $script:Draft
    } else {
        Update-PickerVisual
    }
}

# Theme-Fenster aufbauen (wird auch fuer Screenshots genutzt)
function New-ThemeDialog([string]$tab = "presets") {
    $resBlock = [regex]::Match($xaml, '<Window\.Resources>.*?</Window\.Resources>', 'Singleline').Value
    $dlg = [Windows.Markup.XamlReader]::Parse($themeDlgXaml.Replace('__RES__', $resBlock))
    $dlg.Owner = $window
    foreach ($k in $script:ThemeKeys) { $dlg.Resources[$k] = $window.Resources[$k] }
    Set-LangResources $dlg
    $script:ThemeWin   = $dlg
    $script:ThemePick  = $script:CurrentThemeId
    $script:ThemeCards = @{}
    $script:Draft      = Get-ThemeColors $script:ThemePick
    $script:Slot       = "Accent"

    $d = @{}
    foreach ($n in @("TxtDlgHint","TabPresets","TabCustom","PagePresets","PageCustom","HdrDark","HdrBlack","HdrLight","HostDark","HostBlack","HostLight",
                     "SlotBg","SlotPanel","SlotText","SlotAccent","SwBg","SwPanel","SwText","SwAccent","HxBg","HxPanel","HxText","HxAccent",
                     "TxtContrast","DotContrast","SvBox","SvHue","SvDot","HueBar","HueThumb","PickSwatch","TxtHex","BtnThemeOk","BtnThemeCancel")) {
        $d[$n] = $dlg.FindName($n)
    }
    $script:Dlg = $d
    $d.HdrDark.Text  = (T "ThBaseDark").ToUpper()
    $d.HdrBlack.Text = (T "ThBaseBlack").ToUpper() + "  ·  AMOLED"
    $d.HdrLight.Text = (T "ThBaseLight").ToUpper()

    foreach ($k in $ThemePresets.Keys) {
        $p  = $ThemePresets[$k]
        $cx = $themeCardXaml.Replace('@@KEY@@', $k).Replace('@@BG@@', $p.Bg).Replace('@@PANEL@@', $p.Panel).Replace('@@TEXT@@', $p.Text).Replace('@@ACCENT@@', $p.Accent).Replace('@@ACCENT2@@', $(if ($p.Accent2) { $p.Accent2 } else { $p.Accent })).Replace('@@LABEL@@', [System.Security.SecurityElement]::Escape((T $p.Color)))
        $btn = [Windows.Markup.XamlReader]::Parse($cx)
        $btn.Add_Click({
            param($sender, $e)
            try {
                $script:ThemePick = [string]$sender.Tag
                $script:Draft = Get-ThemeColors $script:ThemePick
                try { $script:ThemeFxOrigin = $sender.TranslatePoint([System.Windows.Point]::new($sender.ActualWidth / 2, $sender.ActualHeight / 2), $script:ThemeWin.Content) } catch {}
                Set-ThemeById $script:ThemePick
                Update-ThemeCards
            } catch {}
        })
        $hostPanel = switch ($p.Base) { "ThBaseLight" { $d.HostLight } "ThBaseBlack" { $d.HostBlack } default { $d.HostDark } }
        [void]$hostPanel.Children.Add($btn)
        $script:ThemeCards[$k] = $btn
    }

    $d.TabPresets.Add_Click({ Set-ThemeTab "presets" })
    $d.TabCustom.Add_Click({ Set-ThemeTab "custom" })
    foreach ($slot in @("Bg", "Panel", "Text", "Accent")) {
        $d["Slot$slot"].Tag = $slot
        $d["Slot$slot"].Add_Click({
            param($sender, $e)
            $script:Slot = [string]$sender.Tag
            Set-PickerFromHex $script:Draft[$script:Slot]
            Update-Slots
        })
    }
    $d.SvBox.Add_MouseLeftButtonDown({ param($sender, $e) [void]$sender.CaptureMouse(); Set-PickFromSv ($e.GetPosition($sender)); Commit-Picker $false })
    $d.SvBox.Add_MouseMove({ param($sender, $e) if ($sender.IsMouseCaptured) { Set-PickFromSv ($e.GetPosition($sender)); Commit-Picker $false } })
    $d.SvBox.Add_MouseLeftButtonUp({ param($sender, $e) $sender.ReleaseMouseCapture(); Commit-Picker $true })
    $d.HueBar.Add_MouseLeftButtonDown({ param($sender, $e) [void]$sender.CaptureMouse(); Set-PickFromHue ($e.GetPosition($sender)); Commit-Picker $false })
    $d.HueBar.Add_MouseMove({ param($sender, $e) if ($sender.IsMouseCaptured) { Set-PickFromHue ($e.GetPosition($sender)); Commit-Picker $false } })
    $d.HueBar.Add_MouseLeftButtonUp({ param($sender, $e) $sender.ReleaseMouseCapture(); Commit-Picker $true })
    $d.TxtHex.Add_KeyDown({ param($sender, $e) if ($e.Key -eq "Return") { Set-HexFromBox } })
    $d.TxtHex.Add_LostKeyboardFocus({ Set-HexFromBox })
    $d.BtnThemeOk.Add_Click({ $script:ThemeWin.Tag = "ok"; $script:ThemeWin.Close() })
    $d.BtnThemeCancel.Add_Click({ $script:ThemeWin.Close() })
    $dlg.Add_SourceInitialized({ Set-TitleBar $script:ThemeWin })

    Set-Theme $script:Draft
    Update-ThemeCards
    Update-Slots
    if ($tab -eq "custom" -and $script:ThemePick -ne "custom") { $script:Draft.Remove("Accent2"); $script:ThemePick = "custom"; Update-ThemeCards }
    Set-ThemeTab $tab
    return $dlg
}

# Theme-Fenster anzeigen (Klick = Vorschau, Uebernehmen = speichern)
function Show-ThemeDialog {
    Set-ThemeById (Get-ThemeKey)
    $dlg = New-ThemeDialog "presets"
    $dlg.Add_ContentRendered({ try { Start-FadeIn $script:ThemeWin.Content 0 } catch {} })
    [void]$dlg.ShowDialog()
    if ($dlg.Tag -eq "ok") {
        if ($script:ThemePick -eq "custom") {
            $script:Settings.CustomTheme = @{ Bg = $script:Draft.Bg; Panel = $script:Draft.Panel; Text = $script:Draft.Text; Accent = $script:Draft.Accent }
        }
        $script:Settings.ThemePreset = $script:ThemePick
        Save-Settings
        Add-UiLog (TF "LogThemeSaved" (Get-ThemeLabel $script:ThemePick))
    }
    $script:ThemeWin = $null
    Set-ThemeById (Get-ThemeKey)       # Vorschau verwerfen bzw. gespeichertes Theme setzen
    Update-ThemeLabel
}

$msgDlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Eden Updater" Width="480" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" UseLayoutRounding="True"
        Background="{DynamicResource BrBg}" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="{DynamicResource BrText}">
  __RES__
  <Grid>
    <Canvas IsHitTestVisible="False" ClipToBounds="True">
      <Ellipse Width="460" Height="460" Canvas.Left="-230" Canvas.Top="-300" Fill="{DynamicResource GlowA}"/>
    </Canvas>
    <Grid Margin="24,24,22,20">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border x:Name="MsgBar" Width="44" Height="44" CornerRadius="14" VerticalAlignment="Top" Margin="0,0,16,0"
              Background="{DynamicResource BrSel}">
        <TextBlock x:Name="MsgGlyph" Text="&#xE897;" FontFamily="{StaticResource FontIcon}" FontSize="20"
                   Foreground="{DynamicResource BrAccentText}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <StackPanel Grid.Column="1">
        <TextBlock x:Name="MsgTitle" FontFamily="{StaticResource FontHead}" FontSize="18" FontWeight="SemiBold" Margin="0,1,0,8"/>
        <!-- lange Texte (z.B. die Frage zu Covern aus dem Internet) bleiben auf kleinen Bildschirmen bedienbar -->
        <ScrollViewer MaxHeight="470" VerticalScrollBarVisibility="Auto" Focusable="False">
          <TextBlock x:Name="MsgText" TextWrapping="Wrap" Foreground="{DynamicResource BrText}" Margin="0,0,6,0"/>
        </ScrollViewer>
        <StackPanel x:Name="MsgButtons" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,24,0,0"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
'@

$script:MsgWin = $null
$script:MsgResult = "Cancel"

# Ersatz fuer die weisse Windows-MessageBox: buttons = "OK" oder "YesNo", Rueckgabe "OK"/"Yes"/"No"
function Show-Dialog([string]$text, [string]$buttons = "OK", [string]$icon = "Information", [string]$title = "", [double]$width = 0, [bool]$neutral = $false) {
    $resBlock = [regex]::Match($xaml, '<Window\.Resources>.*?</Window\.Resources>', 'Singleline').Value
    $d = [Windows.Markup.XamlReader]::Parse($msgDlgXaml.Replace('__RES__', $resBlock))
    foreach ($k in $script:ThemeKeys) { $d.Resources[$k] = $window.Resources[$k] }
    Set-LangResources $d
    if ($window.IsVisible) { $d.Owner = $window }
    $script:MsgWin    = $d
    $script:MsgResult = if ($buttons -eq "YesNo") { "No" } else { "OK" }

    $titles = @{ Warning = (T "DlgWarning"); Error = (T "DlgError"); Question = (T "DlgQuestion"); Information = (T "DlgInfo") }
    $d.Title = $titles[$icon]
    $d.FindName("MsgTitle").Text = $(if ($title) { $title } else { $titles[$icon] })
    $d.FindName("MsgTitle").TextWrapping = [System.Windows.TextWrapping]::Wrap
    $d.FindName("MsgText").Text  = $text
    if ($width -gt 0) { $d.Width = $width }
    # Icon-Feld: Akzentfarbe, bei Warnung gelb, bei Fehler rot
    $bar   = $d.FindName("MsgBar")
    $glyph = $d.FindName("MsgGlyph")
    $glyphs = @{ Warning = 0xE7BA; Error = 0xE783; Question = 0xE897; Information = 0xE946 }
    if ($glyph -and $glyphs.ContainsKey($icon)) { $glyph.Text = [string][char]$glyphs[$icon] }
    $tone = if ($icon -eq "Warning") { "#F59E0B" } elseif ($icon -eq "Error") { "#EF4444" } else { $null }
    if ($tone) {
        $tc = ConvertTo-WpfColor $tone $tone
        $bar.Background = [System.Windows.Media.SolidColorBrush]::new((Get-AlphaColor $tc 0x38))
        if ($glyph) { $glyph.Foreground = [System.Windows.Media.SolidColorBrush]::new($tc) }
    }

    $panelBtns = $d.FindName("MsgButtons")
    $defs = if ($buttons -eq "YesNo") { @(@((T "No"), "No", $false), @((T "Yes"), "Yes", $true)) } else { @(, @((T "OK"), "OK", $true)) }
    foreach ($def in $defs) {
        $b = [System.Windows.Controls.Button]::new()
        $b.Content = $def[0]
        $b.CommandParameter = $def[1]
        $b.MinWidth = 84
        # neutral: beide Knoepfe gleich, Enter waehlt nichts aus (fuer Fragen, bei denen keine Antwort nahegelegt werden soll)
        $b.Style   = $d.FindResource($(if ($def[2] -and -not $neutral) { "BtnPrimary" } else { "Btn" }))
        $b.Margin  = [System.Windows.Thickness]::new(8, 0, 0, 0)
        if ($def[2]) { if (-not $neutral) { $b.IsDefault = $true } } else { $b.IsCancel = $true }
        $b.Add_Click({ param($sender, $e) $script:MsgResult = [string]$sender.CommandParameter; $script:MsgWin.Close() })
        [void]$panelBtns.Children.Add($b)
    }
    $d.Add_SourceInitialized({ Set-TitleBar $script:MsgWin })
    $d.Add_ContentRendered({ try { Start-FadeIn $script:MsgWin.Content 0 } catch {} })
    [void]$d.ShowDialog()
    $script:MsgWin = $null
    return $script:MsgResult
}

function Get-Brush([string]$hex) { [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

# Ordnerauswahl (WinForms) mit dem Updater-Fenster als Besitzer, sonst kann sie hinter dem Fenster aufgehen
function Show-FolderDialog([string]$desc, [string]$start) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = $desc
    if ($start -and (Test-Path -LiteralPath $start)) { $dlg.SelectedPath = $start }
    $own = New-Object System.Windows.Forms.NativeWindow
    try {
        $h = [IntPtr]::Zero
        try { if ($window) { $h = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle } } catch {}
        if ($h -ne [IntPtr]::Zero) { $own.AssignHandle($h); $res = $dlg.ShowDialog($own) } else { $res = $dlg.ShowDialog() }
        if ($res -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
        return $null
    } finally {
        try { $own.ReleaseHandle() } catch {}
        $dlg.Dispose()
    }
}

function Show-Msg([string]$text, [string]$icon = "Warning") {
    [void](Show-Dialog $text "OK" $icon)
}

$script:LogOpen = $false
function Set-LogVisible([bool]$show) {
    $hp   = [System.Windows.FrameworkElement]::HeightProperty
    $full = 130.0
    if ($show -and $script:LogOpen -and $ui.TxtLog.Visibility -eq "Visible") { return }
    $script:LogOpen = $show
    $ui.BtnLogToggle.Tag = [string][char]$(if ($show) { 0xE70E } else { 0xE70D })
    if ($script:Snapshot -or -not $script:Initialized) {
        $ui.TxtLog.BeginAnimation($hp, $null)
        $ui.TxtLog.Height = $full
        $ui.TxtLog.Visibility = if ($show) { "Visible" } else { "Collapsed" }
        if ($show) { $ui.TxtLog.ScrollToEnd() }
        return
    }
    $ease = [System.Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    if ($show) {
        $from = if ($ui.TxtLog.Visibility -eq "Visible") { $ui.TxtLog.ActualHeight } else { 0.0 }
        $ui.TxtLog.Visibility = "Visible"
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new($from, $full, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(260)))
        $a.EasingFunction = $ease
        $ui.TxtLog.BeginAnimation($hp, $a)
        $ui.TxtLog.ScrollToEnd()
    } else {
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new($ui.TxtLog.ActualHeight, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(220)))
        $a.EasingFunction = $ease
        $a.Add_Completed({ if (-not $script:LogOpen) { $ui.TxtLog.Visibility = "Collapsed" } })
        $ui.TxtLog.BeginAnimation($hp, $a)
    }
}

function Add-UiLog([string]$m) {
    # Fehler klappen das Log automatisch auf
    if ($m.StartsWith((T "ErrPrefix"))) { try { Set-LogVisible $true } catch {} }
    $ui.TxtLog.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format "HH:mm:ss"), $m))
    $ui.TxtLog.ScrollToEnd()
}

function Flush-Log {
    $line = $null
    while ($sync.Log.TryDequeue([ref]$line)) { Add-UiLog $line }
}

function Get-InstalledVersion {
    $vf = Join-Path $script:Settings.EdenPath "version.txt"
    if (Test-Path $vf) {
        $v = Get-Content $vf -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($v) { return "$v".Trim() }
    }
    return $null
}

# Dropdown-Eintrag: angezeigt wird nur der Text, der Wert steckt im Tag
function New-CbItem([string]$label, [string]$value) {
    $i = [System.Windows.Controls.ComboBoxItem]::new()
    $i.Content = $label
    $i.Tag     = $value
    return $i
}

function Update-PatternVisibility {
    $ui.PanelPattern.Visibility = if ([string]$ui.CmbVariant.SelectedValue -eq "__custom__") { "Visible" } else { "Collapsed" }
}

function Update-VariantCombo {
    $s = $script:Settings
    $cur = if ($ui.CmbVariant.Items.Count -gt 0 -and $null -ne $ui.CmbVariant.SelectedValue) { [string]$ui.CmbVariant.SelectedValue } else { [string]$s.AssetVariant }
    $items = New-Object System.Collections.ArrayList
    [void]$items.Add((New-CbItem ((T "VarRecommended")) ("")))
    $known = @{}
    foreach ($v in $script:Variants) {
        $known[$v.Key] = $true
        [void]$items.Add((New-CbItem ([string]$v.Key) ([string]$v.Key)))
    }
    if ($cur -and $cur -ne "__custom__" -and -not $known.ContainsKey($cur)) {
        [void]$items.Add((New-CbItem ($cur) ($cur)))
    }
    [void]$items.Add((New-CbItem ((T "VarCustom")) ("__custom__")))
    $script:SuppressVariantEvent = $true
    $ui.CmbVariant.ItemsSource = $items.ToArray()
    $ui.CmbVariant.SelectedValue = $cur
    $script:SuppressVariantEvent = $false
    Update-PatternVisibility
}

function Get-BackupVersion {
    $f = Join-Path (Join-Path $script:Settings.EdenPath "Backup") "backup-version.txt"
    if (Test-Path $f) {
        $v = Get-Content $f -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($v) { return "$v".Trim() }
    }
    return $null
}

function Test-HasBackup {
    $bp = Join-Path $script:Settings.EdenPath "Backup"
    if (-not (Test-Path $bp)) { return $false }
    return (@(Get-ChildItem -Path $bp -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "backup-version.txt" }).Count -gt 0)
}

function Update-List {
    $inst   = Get-InstalledVersion
    $latest = if ($script:Releases.Count -gt 0) { $script:Releases[0].Tag } else { $null }
    $vis    = [System.Windows.Visibility]::Visible
    $col    = [System.Windows.Visibility]::Collapsed
    $items = foreach ($r in $script:Releases) {
        [pscustomobject]@{
            Tag       = $r.Tag
            Url       = $r.Url
            Date      = $r.Date
            NewBadge  = if ($r.Tag -eq $latest) { $vis } else { $col }
            InstBadge = if ($inst -and $r.Tag -eq $inst) { $vis } else { $col }
        }
    }
    $prevTag = if ($ui.List.SelectedItem) { $ui.List.SelectedItem.Tag } else { $null }
    $ui.List.ItemsSource = @($items)
    $ui.TxtListInfo.Text = TF "ListInfo" $script:Releases.Count
    if ($ui.List.Items.Count -gt 0) {
        $idx = 0
        if ($prevTag) {
            for ($i = 0; $i -lt $ui.List.Items.Count; $i++) {
                if ($ui.List.Items[$i].Tag -eq $prevTag) { $idx = $i; break }
            }
        }
        $ui.List.SelectedIndex = $idx
    }
}

# Punkt im Status-Chip pulsiert, solange gesucht wird oder ein Update wartet
function Set-DotPulse([bool]$on) {
    $prop = [System.Windows.UIElement]::OpacityProperty
    $sc   = $ui.DotRing.RenderTransform
    $sx   = [System.Windows.Media.ScaleTransform]::ScaleXProperty
    $sy   = [System.Windows.Media.ScaleTransform]::ScaleYProperty
    if ($on -and -not $script:Snapshot) {
        $forever = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new(1.0, 0.45, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(800)))
        $a.AutoReverse = $true; $a.RepeatBehavior = $forever
        $ui.DotState.BeginAnimation($prop, $a)
        $dur = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(1600))
        $grow = [System.Windows.Media.Animation.DoubleAnimation]::new(1.0, 3.0, $dur); $grow.RepeatBehavior = $forever
        $fade = [System.Windows.Media.Animation.DoubleAnimation]::new(0.55, 0.0, $dur); $fade.RepeatBehavior = $forever
        $sc.BeginAnimation($sx, $grow); $sc.BeginAnimation($sy, $grow)
        $ui.DotRing.BeginAnimation($prop, $fade)
    } else {
        $ui.DotState.BeginAnimation($prop, $null)
        $ui.DotState.Opacity = 1
        $sc.BeginAnimation($sx, $null); $sc.BeginAnimation($sy, $null)
        $ui.DotRing.BeginAnimation($prop, $null)
    }
}

# Solange etwas laeuft: Logo-Pfeil dreht sich, Statuspunkt unten pulsiert in Akzentfarbe
$script:BusyShown = $null
function Set-BusyVisual([bool]$busy) {
    if ($null -ne $script:BusyShown -and $script:BusyShown -eq $busy) { return }
    $script:BusyShown = $busy
    $rot  = $ui.LogoRing.RenderTransform
    $ap   = [System.Windows.Media.RotateTransform]::AngleProperty
    $op   = [System.Windows.UIElement]::OpacityProperty
    $fill = [System.Windows.Shapes.Shape]::FillProperty
    if ($busy) {
        $ui.DotBusy.SetResourceReference($fill, "BrAccent")
        if ($script:Snapshot) { return }
        $forever = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $spin = [System.Windows.Media.Animation.DoubleAnimation]::new(0.0, 360.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(1100)))
        $spin.RepeatBehavior = $forever
        $rot.BeginAnimation($ap, $spin)
        $pulse = [System.Windows.Media.Animation.DoubleAnimation]::new(1.0, 0.3, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(600)))
        $pulse.AutoReverse = $true; $pulse.RepeatBehavior = $forever
        $ui.DotBusy.BeginAnimation($op, $pulse)
    } else {
        $ui.DotBusy.SetResourceReference($fill, "BrMuted")
        $ui.DotBusy.BeginAnimation($op, $null)
        if ($script:Snapshot) { return }
        # Drehung sauber bis zur vollen Runde auslaufen lassen
        $cur = [double]$rot.Angle % 360
        $end = [System.Windows.Media.Animation.DoubleAnimation]::new($cur, 360.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(520)))
        $ease = [System.Windows.Media.Animation.CubicEase]::new()
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
        $end.EasingFunction = $ease
        $end.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::Stop
        $rot.BeginAnimation($ap, $end)
    }
}

# Pfeile zwischen "installiert" und "neueste" laufen, solange ein Update wartet
$script:FlowOn = $null
function Set-FlowAnim([bool]$on) {
    if ($null -ne $script:FlowOn -and $script:FlowOn -eq $on) { return }
    $script:FlowOn = $on
    $op = [System.Windows.UIElement]::OpacityProperty
    $i = 0
    foreach ($f in @($ui.Flow1, $ui.Flow2, $ui.Flow3)) {
        if ($on -and -not $script:Snapshot) {
            $a = [System.Windows.Media.Animation.DoubleAnimation]::new(0.15, 1.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(520)))
            $a.AutoReverse = $true
            $a.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $a.BeginTime = [TimeSpan]::FromMilliseconds(180 * $i)
            $f.BeginAnimation($op, $a)
        } else {
            $f.BeginAnimation($op, $null)
        }
        $i++
    }
}

function Set-StateChip([string]$text, [string]$bg, [string]$fg, [bool]$pulse) {
    $ui.ChipState.Visibility = "Visible"
    $ui.TxtChip.Text = $text
    $ui.ChipState.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $bg)
    $ui.TxtChip.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $fg)
    $ui.DotState.SetResourceReference([System.Windows.Shapes.Shape]::FillProperty, $fg)
    if ($script:ChipPulse -ne $pulse) { Set-DotPulse $pulse; $script:ChipPulse = $pulse }
}

function Update-StateChip($latest) {
    if ($script:Busy -and $script:BusyKind -eq "load") {
        Set-StateChip (T "StSearching") "BrPanel2" "BrMuted" $true
    } elseif ($script:UpdateAvailable) {
        Set-StateChip (T "ChipUpdate") "BrBadgeNewBg" "BrBadgeNewFg" $true
    } elseif ($latest) {
        Set-StateChip (T "BtnUpToDate") "BrBadgeInstBg" "BrAccentText" $false
    } else {
        $ui.ChipState.Visibility = "Collapsed"
    }
}

function Update-Ui {
    try { Update-SelfCard } catch {}
    $inst   = Get-InstalledVersion
    $latest = if ($script:Releases.Count -gt 0) { $script:Releases[0].Tag } else { $null }
    $ui.TxtInstalled.Text = if ($inst) { $inst } else { T "NotInstalled" }
    $ui.TxtLatest.Text    = if ($latest) { $latest } else { "-" }
    $script:UpdateAvailable = [bool]($latest -and $latest -ne $inst)
    Update-StateChip $latest

    $busy = $script:Busy
    $ui.BtnUpdate.Content   = if ($script:UpdateAvailable) { T "BtnUpdate" } elseif ($latest) { T "BtnUpToDate" } else { T "BtnUpdate" }
    $ui.BtnUpdate.IsEnabled = (-not $busy) -and $script:UpdateAvailable
    $sel = $ui.List.SelectedItem
    $ui.BtnInstallSel.Content   = if ($sel -and $inst -and $sel.Tag -eq $inst) { T "BtnReinstall" } else { T "BtnInstallSel" }
    $ui.BtnInstallSel.IsEnabled = (-not $busy) -and ($null -ne $sel)
    $ui.BtnReload.IsEnabled = -not $busy
    $hasBk = Test-HasBackup
    $bv    = Get-BackupVersion
    $ui.BtnRestore.Content   = if ($hasBk -and $bv) { TF "BtnRestoreTo" $bv } else { T "BtnRestore" }
    $ui.BtnRestore.IsEnabled = (-not $busy) -and $hasBk
    $ui.BtnMore.IsEnabled   = -not $busy
    $ui.BtnSave.IsEnabled   = -not $busy
    $ui.BtnLaunch.IsEnabled = (-not $busy) -and (Test-Path (Join-Path $script:Settings.EdenPath "eden.exe"))
    $ui.BtnCancel.Visibility = if ($busy -and $script:BusyKind -eq "install") { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $ui.BtnCancel.IsEnabled  = [bool]$sync.CanCancel
    $ui.TxtSideVer.Text = $ui.TxtInstalled.Text
    try { Set-BusyVisual ([bool]$busy); Set-FlowAnim ([bool]$script:UpdateAvailable) } catch {}
}

function Test-NotesVisible {
    return (($script:CurrentPage -eq "notes") -or (([string]$script:Settings.NotesLayout -eq "side") -and ($script:CurrentPage -eq "versions")))
}

# Patchnotes entweder als eigene Seite oder neben der Versionsliste
function Set-NotesLayout {
    $side    = ([string]$script:Settings.NotesLayout -eq "side")
    $content = $ui.NotesContent
    $parent  = $content.Parent
    if ($parent -is [System.Windows.Controls.Border]) { $parent.Child = $null }
    if ($side) {
        $ui.PanelNotesSide.Child      = $content
        $ui.PanelNotesSide.Visibility = "Visible"
        $ui.ColList.Width  = New-Object System.Windows.GridLength(1.1, [System.Windows.GridUnitType]::Star)
        $ui.ColNotes.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $ui.BtnNavNotes.Visibility = "Collapsed"
        $ui.TxtNotesHint.Text = T "NotesHintSide"
        if ($script:CurrentPage -eq "notes") { Set-Page "versions"; return }
    } else {
        $ui.PanelNotes.Child          = $content
        $ui.PanelNotesSide.Visibility = "Collapsed"
        $ui.ColList.Width  = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $ui.ColNotes.Width = New-Object System.Windows.GridLength(0)
        $ui.BtnNavNotes.Visibility = "Visible"
        $ui.TxtNotesHint.Text = T "NotesHintPage"
    }
    try { Move-NavPill $false } catch {}
    if (Test-NotesVisible) { try { Show-Notes } catch {} }
}

