# ------------------------------------------------------------
# GTA IV - Social Club logging suppression community patch
# ------------------------------------------------------------
# Searches the current working directory for socialclub.dll.
# Locates the target by byte signature, backs up the DLL, then
# replaces the first three bytes of the matching function with:
#   33 C0 C3  -> XOR EAX,EAX ; RET
# If writing or post-write verification fails, restores the backup.

& {
    $ErrorActionPreference = 'Stop'

    function Find-PatternOffsets {
        param(
            [Parameter(Mandatory = $true)] [byte[]] $Buffer,
            [Parameter(Mandatory = $true)] [byte[]] $Pattern
        )

        $results = New-Object 'System.Collections.Generic.List[int]'
        if ($Pattern.Length -eq 0 -or $Pattern.Length -gt $Buffer.Length) {
            return @()
        }

        $lastStart = $Buffer.Length - $Pattern.Length
        for ($i = 0; $i -le $lastStart; $i++) {
            $matched = $true
            for ($j = 0; $j -lt $Pattern.Length; $j++) {
                if ($Buffer[$i + $j] -ne $Pattern[$j]) {
                    $matched = $false
                    break
                }
            }
            if ($matched) {
                [void]$results.Add($i)
            }
        }

        return $results.ToArray()
    }

    function Test-ByteArrayEqual {
        param(
            [Parameter(Mandatory = $true)] [byte[]] $Left,
            [Parameter(Mandatory = $true)] [byte[]] $Right
        )

        if ($Left.Length -ne $Right.Length) {
            return $false
        }
        for ($i = 0; $i -lt $Left.Length; $i++) {
            if ($Left[$i] -ne $Right[$i]) {
                return $false
            }
        }
        return $true
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ' GTA IV - Social Club Log Suppression Patch' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    $GameDirectory = (Get-Location).Path
    Write-Host "[INFO] Working directory: $GameDirectory" -ForegroundColor Gray
    Write-Host '[STEP 1/6] Looking for socialclub.dll in this folder...' -ForegroundColor Cyan

    $DllPath = Join-Path $GameDirectory 'socialclub.dll'
    if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf)) {
        Write-Host '[ERROR] socialclub.dll was not found in the current folder.' -ForegroundColor Red
        Write-Host '[INFO] Open PowerShell in the GTA IV game folder and run the patcher there.' -ForegroundColor Yellow
        return
    }
    Write-Host "[OK] Found: $DllPath" -ForegroundColor Green

    Write-Host '[STEP 2/6] Reading DLL...' -ForegroundColor Cyan
    try {
        [byte[]]$OriginalData = [System.IO.File]::ReadAllBytes($DllPath)
    }
    catch {
        Write-Host ("[ERROR] Could not read socialclub.dll: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return
    }
    Write-Host ("[OK] DLL read ({0:N0} bytes). No version is assumed from its size or hash." -f $OriginalData.Length) -ForegroundColor Green

    [byte[]]$FunctionSignature = @(
        0x55, 0x8B, 0xEC, 0x83, 0xEC, 0x08, 0x8D, 0x45,
        0x10, 0x89, 0x45, 0xFC, 0x8B, 0x4D, 0xFC
    )
    [byte[]]$PatchedSignature = @(
        0x33, 0xC0, 0xC3, 0x83, 0xEC, 0x08, 0x8D, 0x45,
        0x10, 0x89, 0x45, 0xFC, 0x8B, 0x4D, 0xFC
    )
    [byte[]]$PatchBytes = @(0x33, 0xC0, 0xC3)

    Write-Host '[STEP 3/6] Searching for the target function signature...' -ForegroundColor Cyan
    $OriginalOffsets = @(Find-PatternOffsets -Buffer $OriginalData -Pattern $FunctionSignature)
    $PatchedOffsets = @(Find-PatternOffsets -Buffer $OriginalData -Pattern $PatchedSignature)

    if ($OriginalOffsets.Count -eq 0 -and $PatchedOffsets.Count -eq 1) {
        Write-Host ("[INFO] The patch signature is already present at file offset 0x{0:X}. No changes made." -f $PatchedOffsets[0]) -ForegroundColor Yellow
        return
    }

    if ($OriginalOffsets.Count -ne 1 -or $PatchedOffsets.Count -ne 0) {
        if ($OriginalOffsets.Count -eq 0) {
            Write-Host '[ERROR] Target signature not found. This DLL may use a different build or may already have been modified.' -ForegroundColor Red
        }
        elseif ($OriginalOffsets.Count -gt 1) {
            Write-Host ("[ERROR] The original signature appeared {0} times; expected exactly one. Nothing was changed." -f $OriginalOffsets.Count) -ForegroundColor Red
        }
        else {
            Write-Host '[ERROR] The DLL contains an unexpected mix of original/patched signatures. Nothing was changed.' -ForegroundColor Red
        }
        return
    }

    $PatchOffset = [int]$OriginalOffsets[0]
    Write-Host ("[OK] Unique match found at file offset 0x{0:X} ({0})." -f $PatchOffset) -ForegroundColor Green

    Write-Host '[STEP 4/6] Creating and verifying a backup...' -ForegroundColor Cyan
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $BackupPath = Join-Path $GameDirectory ("socialclub.dll.bak-{0}" -f $Stamp)
    if (Test-Path -LiteralPath $BackupPath) {
        $BackupPath = Join-Path $GameDirectory ("socialclub.dll.bak-{0}-{1}" -f $Stamp, ([guid]::NewGuid().ToString('N').Substring(0, 8)))
    }

    try {
        [System.IO.File]::Copy($DllPath, $BackupPath, $false)
        [byte[]]$BackupData = [System.IO.File]::ReadAllBytes($BackupPath)
        if (-not (Test-ByteArrayEqual -Left $OriginalData -Right $BackupData)) {
            throw 'Backup verification failed; the DLL has not been patched.'
        }
    }
    catch {
        Write-Host ("[ERROR] Could not create/verify the backup: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host '[INFO] The original DLL has not been intentionally modified.' -ForegroundColor Yellow
        if (Test-Path -LiteralPath $BackupPath) {
            Write-Host "[INFO] A backup file may remain here: $BackupPath" -ForegroundColor Yellow
        }
        return
    }
    Write-Host "[OK] Backup created and verified: $BackupPath" -ForegroundColor Green

    Write-Host '[STEP 5/6] Applying the three-byte patch...' -ForegroundColor Cyan
    [byte[]]$PatchedData = $OriginalData.Clone()
    for ($i = 0; $i -lt $PatchBytes.Length; $i++) {
        $PatchedData[$PatchOffset + $i] = $PatchBytes[$i]
    }
    Write-Host '[INFO] Replacement bytes: 33 C0 C3 (XOR EAX,EAX; RET).' -ForegroundColor Gray

    try {
        [System.IO.File]::WriteAllBytes($DllPath, $PatchedData)

        Write-Host '[STEP 6/6] Re-reading DLL and verifying the patch...' -ForegroundColor Cyan
        [byte[]]$VerifyData = [System.IO.File]::ReadAllBytes($DllPath)
        if (-not (Test-ByteArrayEqual -Left $PatchedData -Right $VerifyData)) {
            throw 'The written DLL differs from the expected patched bytes.'
        }
        if ($VerifyData.Length -ne $OriginalData.Length) {
            throw 'The DLL size changed unexpectedly.'
        }
        if ($VerifyData[$PatchOffset] -ne 0x33 -or
            $VerifyData[$PatchOffset + 1] -ne 0xC0 -or
            $VerifyData[$PatchOffset + 2] -ne 0xC3) {
            throw 'The patch bytes did not pass the final verification.'
        }

        Write-Host ''
        Write-Host '[SUCCESS] socialclub.dll patched and verified.' -ForegroundColor Green
        Write-Host "[INFO] Backup: $BackupPath" -ForegroundColor Green
        Write-Host '[INFO] If the game behaves unexpectedly, close it and restore the backup DLL.' -ForegroundColor Yellow
    }
    catch {
        Write-Host ("[ERROR] Patching or verification failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host '[ROLLBACK] Attempting to restore the original DLL from the verified backup...' -ForegroundColor Yellow
        try {
            [System.IO.File]::Copy($BackupPath, $DllPath, $true)
            [byte[]]$RestoredData = [System.IO.File]::ReadAllBytes($DllPath)
            if (-not (Test-ByteArrayEqual -Left $OriginalData -Right $RestoredData)) {
                throw 'Restored DLL does not match the original in-memory copy.'
            }
            Write-Host '[OK] Original DLL restored and verified.' -ForegroundColor Green
            Write-Host "[INFO] Backup retained at: $BackupPath" -ForegroundColor Gray
        }
        catch {
            Write-Host '[CRITICAL] Automatic restore failed. Do not launch the game until you restore the backup manually.' -ForegroundColor Red
            Write-Host ("[CRITICAL] Backup location: {0}" -f $BackupPath) -ForegroundColor Red
            Write-Host ("[CRITICAL] Restore error: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
        return
    }
}

Write-Host ''
Read-Host 'Press Enter to close'
