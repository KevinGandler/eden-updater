# ------------------------------------------------------------
#  Hintergrund-Code (laeuft in eigenem Runspace, fasst die UI nicht an)
# ------------------------------------------------------------
$workerLib = {
    $UA          = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    $BaseUrl     = "https://git.eden-emu.dev"
    $ReleasesUrl = "https://git.eden-emu.dev/eden-ci/nightly/releases"
    $DefaultPattern = "Windows.*amd64.*pgo"

    function Add-Log([string]$m) { $sync.Log.Enqueue($m) }

    # Uebersetzte Texte kommen aus dem UI-Thread ($sync.L / $sync.Culture)
    $CI = [Globalization.CultureInfo]::CurrentCulture
    try { if ($sync.Culture) { $CI = [Globalization.CultureInfo]::GetCultureInfo([string]$sync.Culture) } } catch {}
    function T([string]$k) {
        if ($sync.L) { $v = $sync.L[$k]; if ($null -ne $v) { return [string]$v } }
        return $k
    }
    function TF([string]$k) { return [string]::Format($CI, (T $k), [object[]]$args) }

    # curl.exe verwenden (umgeht Cloudflare-Block von PowerShell/.NET)
    function Get-Page([string]$url) {
        $tmp = [IO.Path]::GetTempFileName()
        try {
            $code = & curl.exe -s -L --max-time 20 -A $UA -o $tmp -w "%{http_code}" $url 2>$null
            $html = if (Test-Path $tmp) { [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8) } else { "" }
            [pscustomobject]@{ Code = "$code"; Html = $html }
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    # Variante = Dateiname ohne Tag/Datum/Hash, z.B. "Eden-Windows-amd64-clang-pgo"
    function Get-VariantKey([string]$fname, [string]$tag) {
        $n = [IO.Path]::GetFileNameWithoutExtension($fname)
        if ($tag) { $n = $n.Replace($tag, "") }
        $n = [regex]::Replace($n, '(?<![A-Za-z0-9])(v?\d{4}[-._]\d{2}[-._]\d{2}|\d{8})(?![A-Za-z0-9])', '')
        $n = [regex]::Replace($n, '(?<![A-Za-z0-9])(?=[0-9a-f]*\d)[0-9a-f]{7,40}(?![A-Za-z0-9])', '')
        $n = [regex]::Replace($n, '[-_.\s]{2,}', '-')
        return $n.Trim('-', '_', '.', ' ')
    }

    function Get-Releases([int]$pages, [string]$variant, [string]$pattern) {
        $items    = New-Object System.Collections.ArrayList
        $seen     = @{}
        $varSeen  = @{}
        $varCount = @{}
        for ($p = 1; $p -le $pages; $p++) {
            $url = if ($p -eq 1) { $ReleasesUrl } else { "$ReleasesUrl`?page=$p" }
            Add-Log (TF "WLoadPage" $p)
            $r = Get-Page $url
            if ($r.Code -ne "200") {
                if ($p -eq 1) { throw (TF "WUnreachable" $r.Code) } else { break }
            }
            $html       = $r.Html
            $tagMatches = [regex]::Matches($html, '/eden-ci/nightly/releases/tag/([^"''<>\s]+)')
            $zipMatches = [regex]::Matches($html, 'href="([^"]*\.zip)"')
            $added = 0
            foreach ($z in $zipMatches) {
                $href = [System.Net.WebUtility]::HtmlDecode($z.Groups[1].Value)

                # Tag aus dem Download-Link, sonst der naechste Tag-Link davor
                $tag = $null
                if ($href -match '/releases/download/([^/]+)/') {
                    $tag = [uri]::UnescapeDataString($Matches[1])
                } else {
                    foreach ($t in $tagMatches) {
                        if ($t.Index -lt $z.Index) { $tag = $t.Groups[1].Value.Trim() } else { break }
                    }
                }
                if (-not $tag) { continue }

                # Variante bestimmen und mitzaehlen (fuer das Dropdown)
                $fname = [uri]::UnescapeDataString((($href -split '\?')[0]).Split('/')[-1])
                $key   = Get-VariantKey $fname $tag
                if (-not $key) { $key = $fname }
                $vk = "$tag|$key"
                if (-not $varSeen.ContainsKey($vk)) {
                    $varSeen[$vk] = $true
                    $varCount[$key] = 1 + [int]$varCount[$key]
                }

                # Filter
                if ($variant -eq "__custom__") { $ok = ($href -match $pattern) }
                elseif ($variant)              { $ok = ($key -eq $variant) }
                else                           { $ok = ($href -match $DefaultPattern) }
                if (-not $ok -or $seen.ContainsKey($tag)) { continue }
                $seen[$tag] = $true
                $dl = if ($href -match '^https?://') { $href } else { "$BaseUrl$href" }

                # Datum (falls im HTML vorhanden)
                $date = ""
                for ($i = 0; $i -lt $tagMatches.Count; $i++) {
                    if ($tagMatches[$i].Groups[1].Value.Trim() -eq $tag) {
                        $start = $tagMatches[$i].Index
                        $end   = $html.Length
                        for ($j = $i + 1; $j -lt $tagMatches.Count; $j++) {
                            if ($tagMatches[$j].Groups[1].Value.Trim() -ne $tag) { $end = $tagMatches[$j].Index; break }
                        }
                        $seg = $html.Substring($start, $end - $start)
                        $dm  = [regex]::Match($seg, 'datetime="([^"]+)"')
                        if ($dm.Success) {
                            try { $date = ([datetime]::Parse($dm.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)).ToString("g", $CI) } catch {}
                        }
                        break
                    }
                }
                [void]$items.Add([pscustomobject]@{ Tag = $tag; Url = $dl; Date = $date })
                $added++
            }
            if ($added -eq 0) { break }
        }

        # Gefundene Varianten: nur Builds, die unter Windows laufen
        # (kein Linux/Android/macOS; ARM-Builds nur auf ARM-Rechnern)
        $isArmHost = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
        $otherOs   = 'linux|android|macos|osx|darwin|freebsd|appimage|steamdeck|flatpak|apk'
        $vl = @(foreach ($k in $varCount.Keys) { [pscustomobject]@{ Key = $k; Count = $varCount[$k] } })
        $vl = @($vl | Where-Object {
            $_.Key -match '(?<![a-z])win(dows|64|32)?(?![a-z])' -and
            $_.Key -notmatch $otherOs -and
            ($isArmHost -or $_.Key -notmatch 'arm64|aarch64|armv')
        })
        $vl = @($vl | Sort-Object Key)
        [pscustomobject]@{ Items = $items.ToArray(); Variants = $vl }
    }

    # --- Patchnotes ---------------------------------------------------
    function Format-Notes([string]$text) {
        $out  = New-Object System.Collections.ArrayList
        $prevBlank = $true
        foreach ($raw in ($text -split "\r?\n")) {
            $l = $raw.TrimEnd()
            $l = [regex]::Replace($l, '<!--.*?-->', '')
            $l = [regex]::Replace($l, '<[^>]+>', '')
            $l = [regex]::Replace($l, '!?\[([^\]]*)\]\([^)]*\)', '$1')
            $isHead = $false
            if ($l -match '^\s{0,3}#{1,6}\s*(.+)$') { $l = $Matches[1].Trim().ToUpper(); $isHead = $true }
            $l = [regex]::Replace($l, '\*\*(.+?)\*\*', '$1')
            $l = [regex]::Replace($l, '__(.+?)__', '$1')
            $l = [regex]::Replace($l, '`([^`]*)`', '$1')
            $l = [regex]::Replace($l, '^(\s*)[-*+]\s+', '$1' + [string][char]0x2022 + ' ')
            if ($l.Trim() -eq "") {
                if (-not $prevBlank) { [void]$out.Add("") }
                $prevBlank = $true
                continue
            }
            if ($isHead -and -not $prevBlank) { [void]$out.Add("") }
            [void]$out.Add($l)
            $prevBlank = $false
        }
        $res = ($out -join "`r`n").Trim()
        if ($res.Length -gt 20000) { $res = $res.Substring(0, 20000) + "`r`n..." }
        return $res
    }

    function Convert-HtmlNotes([string]$html) {
        $m = [regex]::Match($html, '<div[^>]*class="[^"]*markup[^"]*"[^>]*>')
        if (-not $m.Success) { return $null }
        $pos   = $m.Index + $m.Length
        $depth = 1
        $end   = $html.Length
        foreach ($t in ([regex]'<(/?)div\b[^>]*>').Matches($html, $pos)) {
            if ($t.Groups[1].Value -eq '/') { $depth-- } else { $depth++ }
            if ($depth -eq 0) { $end = $t.Index; break }
        }
        $inner = $html.Substring($pos, $end - $pos)
        $inner = [regex]::Replace($inner, '(?i)<li[^>]*>', "`n- ")
        $inner = [regex]::Replace($inner, '(?i)<br\s*/?>|</p>|</h[1-6]>|</ul>|</ol>|</li>', "`n")
        $inner = [regex]::Replace($inner, '<[^>]+>', '')
        $inner = [System.Net.WebUtility]::HtmlDecode($inner)
        return (Format-Notes $inner)
    }

    # Dateigroesse fuer echten Prozentbalken (0 = unbekannt)
    function Get-RemoteSize([string]$url) {
        try {
            $h   = & curl.exe -s -I -L --max-time 20 -A $UA $url 2>$null
            $len = 0L
            foreach ($line in $h) {
                if ($line -match '^(?i)content-length:\s*(\d+)') { $len = [long]$Matches[1] }
            }
            return $len
        } catch { return 0L }
    }
}

$jobLoad = {
    $res = $null
    try {
        $a = $sync.Args
        $sync.Status   = (T "StSearching")
        $sync.Progress = -1
        $res = Get-Releases $a.Pages $a.Variant $a.Pattern
        $items = @($res.Items)
        if ($items.Count -eq 0) { throw (T "WNoReleases") }
        Add-Log (TF "WFound" $items.Count)
        $sync.Status = (T "StReady")
        $sync.Result = @{ Kind = "load"; Ok = $true; Items = $items; Variants = @($res.Variants) }
    } catch {
        Add-Log ((T "ErrPrefix") + " " + $_.Exception.Message)
        $sync.Status = (T "StLoadError")
        $vars = if ($res) { @($res.Variants) } else { @() }
        $sync.Result = @{ Kind = "load"; Ok = $false; Error = $_.Exception.Message; Variants = $vars }
    } finally {
        $sync.Done = $true
    }
}

$jobInstall = {
    $removed = $false
    $cancelled = $false
    try {
        $a    = $sync.Args
        $tag  = $a.Tag
        $url  = $a.Url
        $eden = $a.EdenPath
        $zip  = Join-Path $env:TEMP "eden_nightly_update.zip"

        # Laeuft Eden noch aus diesem Ordner?
        $running = Get-Process -Name eden -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -and $_.Path.StartsWith($eden, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
        }
        if ($running) { throw (T "WEdenRunning") }

        # 1) Download
        $sync.Status   = (TF "WDownloading" $tag)
        $sync.Progress = -1
        $total = Get-RemoteSize $url
        if (Test-Path $zip) { Remove-Item $zip -Force }
        $argLine = "-L --fail --max-time 900 -A `"$UA`" -o `"$zip`" `"$url`""
        $proc = Start-Process -FilePath "curl.exe" -ArgumentList $argLine -WindowStyle Hidden -PassThru
        $null = $proc.Handle
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $lastB = 0L; $lastT = 0.0; $speed = 0.0
        while (-not $proc.HasExited) {
            if ($sync.Cancel) {
                try { $proc.Kill() } catch {}
                Start-Sleep -Milliseconds 300
                Remove-Item $zip -Force -ErrorAction SilentlyContinue
                $cancelled = $true
                throw (T "WCancelled")
            }
            $b = if (Test-Path $zip) { (Get-Item $zip).Length } else { 0L }
            $t = $sw.Elapsed.TotalSeconds
            if (($t - $lastT) -ge 0.5) {
                $speed = (($b - $lastB) / 1MB) / ($t - $lastT)
                $lastB = $b; $lastT = $t
            }
            if ($total -gt 0) {
                $sync.Progress = [math]::Min(100, [int](100 * $b / $total))
                $sync.Status   = (TF "WDlProgress" ($b / 1MB) ($total / 1MB) $speed)
            } else {
                $sync.Progress = -1
                $sync.Status   = (TF "WDlProgressNoSize" ($b / 1MB) $speed)
            }
            Start-Sleep -Milliseconds 200
        }
        if ($proc.ExitCode -ne 0) { throw (TF "WDlFailed" $proc.ExitCode) }
        $finalMB = (Get-Item $zip).Length / 1MB
        Add-Log (TF "WDlDone" $finalMB $sw.Elapsed.TotalSeconds)
        $sync.CanCancel = $false

        # Spielstaende sichern (nur Spiele mit Aenderungen seit dem letzten Backup)
        if ($a.SaveBackup -and $a.SaveLib) {
            try {
                . ([scriptblock]::Create([string]$a.SaveLib))
                $sync.Progress = -1
                $sync.Status = (T "WSavesBackup")
                $nSaves = Backup-ChangedSaves ([string]$a.SaveRoot) ([string]$a.SaveBackupDir) ([int]$a.SaveKeep)
                Add-Log (TF "WSavesBacked" $nSaves)
            } catch {
                Add-Log ((T "ErrPrefix") + " " + (T "WSavesBackup") + " " + $_.Exception.Message)
            }
        }

        # 2) Backup der alten Version
        $sync.Progress = -1
        $excl = @($a.Excludes)
        if (-not (Test-Path $eden)) { New-Item -ItemType Directory -Path $eden | Out-Null }
        if ($a.Backup) {
            $sync.Status = (T "WBackupMaking")
            $bp = Join-Path $eden "Backup"
            if (Test-Path $bp) { Remove-Item -Path $bp -Recurse -Force }
            New-Item -ItemType Directory -Path $bp | Out-Null
            if ($a.InstalledVersion) { "$($a.InstalledVersion)" | Set-Content (Join-Path $bp "backup-version.txt") }
            Get-ChildItem -Path $eden -Exclude $excl | Copy-Item -Destination $bp -Recurse -Force
            Add-Log (T "WBackupDone")
        }

        # 3) Alten Inhalt loeschen
        $sync.Status = (T "WRemoveOld")
        $removed = $true
        Get-ChildItem -Path $eden -Exclude $excl | Remove-Item -Recurse -Force
        Add-Log (T "WRemovedOld")

        # 4) Entpacken (mit Fortschritt)
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zf = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            $n    = $zf.Entries.Count
            $i    = 0
            $root = [IO.Path]::GetFullPath($eden).TrimEnd('\') + '\'
            foreach ($e in $zf.Entries) {
                $i++
                $target = [IO.Path]::GetFullPath((Join-Path $eden $e.FullName))
                if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { continue }
                if ($e.FullName.EndsWith('/')) { [void][IO.Directory]::CreateDirectory($target); continue }
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
                if (($i % 20) -eq 0 -or $i -eq $n) {
                    $sync.Progress = [int](100 * $i / $n)
                    $sync.Status   = (TF "WExtracting" $i $n)
                }
            }
        } finally {
            $zf.Dispose()
        }
        Add-Log (T "WExtracted")

        # 5) Version merken, aufraeumen
        $tag | Set-Content (Join-Path $eden "version.txt")
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        $sync.Progress = 100
        $sync.Status   = (TF "WInstalledSt" $tag)
        Add-Log (TF "WInstalledLog" $tag)
        $sync.Result = @{ Kind = "install"; Ok = $true; Tag = $tag }
    } catch {
        Add-Log ((T "ErrPrefix") + " " + $_.Exception.Message)
        if ($removed -and $a.Backup) { Add-Log (TF "WBackupAt" (Join-Path $a.EdenPath "Backup")) }
        $sync.Status = (T "StError")
        $sync.Result = @{ Kind = "install"; Ok = $false; Error = $_.Exception.Message; Cancelled = $cancelled }
    } finally {
        $sync.Done = $true
    }
}

$jobRestore = {
    try {
        $a    = $sync.Args
        $eden = $a.EdenPath
        $bp   = Join-Path $eden "Backup"
        $excl = @($a.Excludes)
        if (-not (Test-Path $bp)) { throw (T "WNoBackup") }

        $running = Get-Process -Name eden -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -and $_.Path.StartsWith($eden, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
        }
        if ($running) { throw (T "WEdenRunning") }

        $items = @(Get-ChildItem -Path $bp -Exclude "backup-version.txt" -Force)
        if ($items.Count -eq 0) { throw (T "WBackupEmpty") }

        $sync.Progress = -1
        $sync.Status   = (T "WRemoveCur")
        Get-ChildItem -Path $eden -Exclude $excl | Remove-Item -Recurse -Force
        Add-Log (T "WRemovedCur")

        $n = $items.Count
        $i = 0
        foreach ($it in $items) {
            $sync.Progress = [int](100 * $i / $n)
            $sync.Status   = (TF "WRestoring" ($i + 1) $n)
            Copy-Item -LiteralPath $it.FullName -Destination $eden -Recurse -Force
            $i++
        }

        $ver = if ($a.BackupVersion) { "$($a.BackupVersion)" } else { T "WUnknownVer" }
        $ver | Set-Content (Join-Path $eden "version.txt")
        $sync.Progress = 100
        $sync.Status   = (TF "WRestoredSt" $ver)
        Add-Log (TF "WRestoredLog" $ver)
        $sync.Result = @{ Kind = "restore"; Ok = $true; Tag = $ver }
    } catch {
        Add-Log ((T "ErrPrefix") + " " + $_.Exception.Message)
        $sync.Status = (T "StError")
        $sync.Result = @{ Kind = "restore"; Ok = $false; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

$jobNotes = {
    $tag = $null
    try {
        $tag  = $sync.Args.Tag
        $enc  = [uri]::EscapeDataString($tag)
        $text = $null
        # 1) API (liefert den Release-Text direkt)
        $r = Get-Page "$BaseUrl/api/v1/repos/eden-ci/nightly/releases/tags/$enc"
        if ($r.Code -eq "200") {
            try {
                $j = $r.Html | ConvertFrom-Json
                if ($j.body) { $text = Format-Notes ([string]$j.body) }
            } catch {}
        }
        # 2) Fallback: Release-Seite
        if (-not $text) {
            $r = Get-Page "$BaseUrl/eden-ci/nightly/releases/tag/$enc"
            if ($r.Code -eq "200") { $text = Convert-HtmlNotes $r.Html }
        }
        $sync.Result = @{ Tag = $tag; Ok = [bool]$text; Text = $text; Error = $null }
    } catch {
        $sync.Result = @{ Tag = $tag; Ok = $false; Text = $null; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

