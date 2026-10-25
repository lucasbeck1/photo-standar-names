# Load assemblies for GUI and EXIF processing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Supported media extensions (Photos, RAW images, Videos)
$validExtensions = @(
    # Standard photos
    ".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".bmp", ".tiff", ".tif", ".gif",
    # Camera RAW
    ".cr2", ".cr3", ".nef", ".arw", ".dng", ".orf", ".rw2",
    # Videos
    ".mov", ".mp4", ".avi", ".mkv", ".m4v", ".3gp", ".wmv"
)

# Helper function to extract EXIF Date Taken with fallback to file timestamps
function Get-MediaTimestamp {
    param([System.IO.FileInfo]$fileInfo)

    $ext = $fileInfo.Extension.ToLower()
    $imgExtensions = @(".jpg", ".jpeg", ".png", ".tiff", ".tif")

    if ($imgExtensions -contains $ext) {
        $fs = $null
        $img = $null
        try {
            $fs = New-Object System.IO.FileStream($fileInfo.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $img = [System.Drawing.Image]::FromStream($fs, $false, $false)

            $prop = $null
            # Check PropertyTagExifDTOrig (36867), PropertyTagExifDTDigitized (36868), PropertyTagDateTime (306)
            foreach ($tagId in @(36867, 36868, 306)) {
                try {
                    $prop = $img.GetPropertyItem($tagId)
                    if ($prop) { break }
                } catch { }
            }

            if ($prop -and $prop.Value) {
                $dateStr = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0, ' ')
                $parsedDate = [DateTime]::MinValue
                if ([DateTime]::TryParseExact($dateStr, 'yyyy:MM:dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                    if ($parsedDate.Year -gt 1980 -and $parsedDate -le [DateTime]::Now.AddDays(1)) {
                        return $parsedDate
                    }
                }
            }
        } catch {
            # Safely continue to fallback
        } finally {
            if ($img) { $img.Dispose() }
            if ($fs) { $fs.Dispose() }
        }
    }

    # Fallback: Oldest valid date between LastWriteTime and CreationTime
    $date = $fileInfo.LastWriteTime
    if ($fileInfo.CreationTime -lt $date -and $fileInfo.CreationTime.Year -gt 1980) {
        $date = $fileInfo.CreationTime
    }
    return $date
}

# Form configuration
$form = New-Object System.Windows.Forms.Form
$form.Text = "Photo Migrator & Standardizer"
$form.Size = New-Object System.Drawing.Size(520, 360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Helper function to create labels
function CreateLabel ($text, $y) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(20, $y)
    $lbl.Size = New-Object System.Drawing.Size(470, 20)
    $lbl.Text = $text
    $form.Controls.Add($lbl)
}

# Helper function to create path picker section
function CreateBrowseSection ($y, $defaultPath) {
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, $y)
    $txt.Size = New-Object System.Drawing.Size(380, 23)
    $txt.Text = $defaultPath
    $form.Controls.Add($txt)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Location = New-Object System.Drawing.Point(410, ($y - 1))
    $btn.Size = New-Object System.Drawing.Size(80, 25)
    $btn.Text = "Browse..."
    $btn.Tag = $txt
    $btn.Add_Click({
        $targetBox = $this.Tag
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        if (Test-Path -LiteralPath $targetBox.Text) {
            $dlg.SelectedPath = $targetBox.Text
        }
        $dlg.Description = "Select Folder"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
            $targetBox.Text = $dlg.SelectedPath 
        }
    })
    $form.Controls.Add($btn)
    return $txt
}

# Source and Destination controls
CreateLabel "Source Folder (reads recursively from all subfolders):" 15
$txtSource = CreateBrowseSection 38 $PSScriptRoot

CreateLabel "Destination Folder:" 75
$txtDest = CreateBrowseSection 98 $PSScriptRoot

# Options Group
$grpOptions = New-Object System.Windows.Forms.GroupBox
$grpOptions.Text = "Options"
$grpOptions.Location = New-Object System.Drawing.Point(20, 135)
$grpOptions.Size = New-Object System.Drawing.Size(470, 115)
$form.Controls.Add($grpOptions)

$chkFlatten = New-Object System.Windows.Forms.CheckBox
$chkFlatten.Location = New-Object System.Drawing.Point(15, 25)
$chkFlatten.Size = New-Object System.Drawing.Size(440, 22)
$chkFlatten.Text = "Flatten subfolders (consolidate all photos into destination root)"
$chkFlatten.Checked = $true
$grpOptions.Controls.Add($chkFlatten)

$chkDeleteEmpty = New-Object System.Windows.Forms.CheckBox
$chkDeleteEmpty.Location = New-Object System.Drawing.Point(15, 52)
$chkDeleteEmpty.Size = New-Object System.Drawing.Size(440, 22)
$chkDeleteEmpty.Text = "Delete empty source subfolders after processing"
$chkDeleteEmpty.Checked = $true
$grpOptions.Controls.Add($chkDeleteEmpty)

$chkCopy = New-Object System.Windows.Forms.CheckBox
$chkCopy.Location = New-Object System.Drawing.Point(15, 79)
$chkCopy.Size = New-Object System.Drawing.Size(440, 22)
$chkCopy.Text = "Keep original files (Copy instead of Move)"
$chkCopy.Checked = $false
$grpOptions.Controls.Add($chkCopy)

# If copying originals, disable deleting empty folders
$chkCopy.Add_CheckedChanged({
    if ($this.Checked) {
        $chkDeleteEmpty.Checked = $false
        $chkDeleteEmpty.Enabled = $false
    } else {
        $chkDeleteEmpty.Enabled = $true
        $chkDeleteEmpty.Checked = $true
    }
}.GetNewClosure())

# Accept / Cancel buttons
$btnAccept = New-Object System.Windows.Forms.Button
$btnAccept.Location = New-Object System.Drawing.Point(140, 265)
$btnAccept.Size = New-Object System.Drawing.Size(110, 32)
$btnAccept.Text = "Start"
$btnAccept.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnAccept)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(270, 265)
$btnCancel.Size = New-Object System.Drawing.Size(110, 32)
$btnCancel.Text = "Cancel"
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($btnCancel)

$form.AcceptButton = $btnAccept
$form.CancelButton = $btnCancel

if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    exit
}

$sourceRaw = $txtSource.Text.Trim()
$destRaw = $txtDest.Text.Trim()

if (-not (Test-Path -LiteralPath $sourceRaw)) {
    [System.Windows.Forms.MessageBox]::Show("The selected source folder does not exist:`n$sourceRaw", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Resolve full canonical paths
$sourcePath = [System.IO.Path]::GetFullPath($sourceRaw)
$destPath = [System.IO.Path]::GetFullPath($destRaw)

# Create destination folder if it does not exist
if (-not (Test-Path -LiteralPath $destPath)) {
    try {
        [System.IO.Directory]::CreateDirectory($destPath) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not create destination directory:`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
}

$flatten = $chkFlatten.Checked
$deleteEmpty = $chkDeleteEmpty.Checked
$copyOnly = $chkCopy.Checked
$scriptName = $MyInvocation.MyCommand.Name

$sourcePrefix = $sourcePath.TrimEnd('\') + '\'
$destPrefix = $destPath.TrimEnd('\') + '\'
$isDestInsideSource = $destPath.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and ($destPath.Length -gt $sourcePath.Length)

try {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " Photo Migrator & Standardizer" -ForegroundColor Cyan
    Write-Host " Source:      $sourcePath" -ForegroundColor Gray
    Write-Host " Destination: $destPath" -ForegroundColor Gray
    Write-Host " Mode:        $(if ($flatten) { 'Flatten (all into destination root)' } else { 'Preserve subfolder structure' })" -ForegroundColor Gray
    Write-Host " Action:      $(if ($copyOnly) { 'Copy files' } else { 'Move files' })" -ForegroundColor Gray
    Write-Host "==========================================================`n" -ForegroundColor Cyan

    Write-Host "Scanning for files across all subfolders..." -ForegroundColor Yellow
    
    # Recursively discover all files from source
    $allFiles = Get-ChildItem -LiteralPath $sourcePath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        # Exclude files inside destination if destination is inside source
        if ($isDestInsideSource -and ($_.FullName.StartsWith($destPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or $_.DirectoryName -ieq $destPath)) {
            return $false
        }
        # Exclude running script and batch files
        if ($_.Name -ieq $scriptName -or $_.Extension.ToLower() -in @(".ps1", ".bat", ".cmd")) {
            return $false
        }
        # Filter by media extensions
        return ($validExtensions -contains $_.Extension.ToLower())
    }

    $totalFound = @($allFiles).Count
    Write-Host "Found $totalFound media files to process.`n" -ForegroundColor Green

    if ($totalFound -eq 0) {
        Write-Host "No media files found matching supported extensions." -ForegroundColor Yellow
    } else {
        $sourceNormalized = $sourcePath.TrimEnd('\')
        $processedCount = 0
        $skippedCount = 0
        $errorCount = 0
        $currentIndex = 0

        foreach ($file in $allFiles) {
            $currentIndex++
            $percent = [math]::Round(($currentIndex / $totalFound) * 100)

            # Determine target folder
            if ($flatten) {
                $targetDir = $destPath
            } else {
                # Preserve relative subfolder structure
                if ($file.DirectoryName.Length -gt $sourceNormalized.Length) {
                    $relSubDir = $file.DirectoryName.Substring($sourceNormalized.Length).TrimStart('\')
                    $targetDir = [System.IO.Path]::Combine($destPath, $relSubDir)
                } else {
                    $targetDir = $destPath
                }
            }

            # Ensure target folder exists
            if (-not (Test-Path -LiteralPath $targetDir)) {
                [System.IO.Directory]::CreateDirectory($targetDir) | Out-Null
            }

            # Determine standardized name from media timestamp (EXIF or filesystem)
            $date = Get-MediaTimestamp -fileInfo $file
            $baseName = $date.ToString("yyyyMMdd_HHmmss")
            $ext = $file.Extension.ToLower()
            $candidateName = $baseName + $ext
            $destFilePath = [System.IO.Path]::Combine($targetDir, $candidateName)

            # Resolve naming collisions
            $counter = 1
            while ((Test-Path -LiteralPath $destFilePath) -and ($file.FullName -ine $destFilePath)) {
                $candidateName = "${baseName}_${counter}${ext}"
                $destFilePath = [System.IO.Path]::Combine($targetDir, $candidateName)
                $counter++
            }

            # Check if file is already standardized at destination
            if ($file.FullName -ieq $destFilePath) {
                Write-Host "[$percent%] Skipped (already standardized): $($file.Name)" -ForegroundColor DarkGray
                $skippedCount++
                continue
            }

            try {
                if ($copyOnly) {
                    Copy-Item -LiteralPath $file.FullName -Destination $destFilePath -Force -ErrorAction Stop
                    Write-Host "[$percent%] Copied: $($file.Name) -> $candidateName" -ForegroundColor Gray
                } else {
                    Move-Item -LiteralPath $file.FullName -Destination $destFilePath -Force -ErrorAction Stop
                    Write-Host "[$percent%] Moved:  $($file.Name) -> $candidateName" -ForegroundColor Gray
                }
                $processedCount++
            } catch {
                Write-Host "[$percent%] Error with $($file.FullName): $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        }

        Write-Host "`n--- Summary ---" -ForegroundColor Cyan
        Write-Host "Processed: $processedCount" -ForegroundColor Green
        Write-Host "Skipped:   $skippedCount" -ForegroundColor Yellow
        Write-Host "Errors:    $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Gray' })
    }

    # Optional cleanup: Delete empty source subfolders (bottom-up)
    if ($deleteEmpty -and -not $copyOnly) {
        Write-Host "`n--- Cleaning empty folders in source ---" -ForegroundColor Yellow
        $dirs = Get-ChildItem -LiteralPath $sourcePath -Recurse -Directory -ErrorAction SilentlyContinue | 
                Sort-Object -Property { $_.FullName.Length } -Descending

        $deletedFolders = 0
        foreach ($dir in $dirs) {
            # Never delete destination directory or its subdirectories
            if ($dir.FullName.StartsWith($destPath.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            # Check if folder is empty (ignoring system hidden metadata files)
            $remaining = Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue | 
                         Where-Object { $_.Name -notin @('desktop.ini', 'Thumbs.db') }

            if ($remaining.Count -eq 0) {
                try {
                    Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
                    Write-Host "Empty folder removed: $($dir.FullName)" -ForegroundColor DarkGray
                    $deletedFolders++
                } catch { }
            }
        }
        Write-Host "Empty folders removed: $deletedFolders" -ForegroundColor Gray
    }

    Write-Host "`n--- Operation completed successfully! ---" -ForegroundColor Green
}
catch {
    Write-Host "`nAn unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Read-Host "Press Enter to exit..."
}
