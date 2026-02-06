# Load assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Form configuration
$form = New-Object System.Windows.Forms.Form
$form.Text = "Photo Migrator"
$form.Size = New-Object System.Drawing.Size(500, 260)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Helper function to create controls
function CreateLabel ($text, $y) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(20, $y)
    $lbl.Size = New-Object System.Drawing.Size(440, 20)
    $lbl.Text = $text
    $form.Controls.Add($lbl)
}

function CreateBrowseSection ($y, $defaultPath) {
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, ($y + 25))
    $txt.Size = New-Object System.Drawing.Size(350, 20)
    $txt.Text = $defaultPath
    $form.Controls.Add($txt)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Location = New-Object System.Drawing.Point(380, ($y + 23))
    $btn.Size = New-Object System.Drawing.Size(80, 23)
    $btn.Text = "Browse"
    $btn.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.SelectedPath = $txt.Text
        if ($dlg.ShowDialog() -eq "OK") { $txt.Text = $dlg.SelectedPath }
    })
    $form.Controls.Add($btn)
    return $txt
}

# Form controls
CreateLabel "Source Folder:" 20
$txtSource = CreateBrowseSection 20 $PSScriptRoot

CreateLabel "Destination Folder:" 80
$txtDest = CreateBrowseSection 80 $PSScriptRoot

# Accept / Cancel buttons
$btnAccept = New-Object System.Windows.Forms.Button
$btnAccept.Location = New-Object System.Drawing.Point(140, 160)
$btnAccept.Size = New-Object System.Drawing.Size(100, 30)
$btnAccept.Text = "Accept"
$btnAccept.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnAccept)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(260, 160)
$btnCancel.Size = New-Object System.Drawing.Size(100, 30)
$btnCancel.Text = "Cancel"
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($btnCancel)

$form.AcceptButton = $btnAccept
$form.CancelButton = $btnCancel

if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    exit
}

$sourcePath = $txtSource.Text
$destPath = $txtDest.Text

if (-not (Test-Path $sourcePath) -or -not (Test-Path $destPath)) {
    [System.Windows.Forms.MessageBox]::Show("The selected paths do not exist.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

try {
    Write-Host "--- Step 1: Extracting files from subfolders ---" -ForegroundColor Cyan

    # 1. Move files from subfolders to destination folder
    # Search in all subfolders (-Recurse)
    $allFiles = Get-ChildItem -Path $sourcePath -Recurse -File | Where-Object { 
        ($_.DirectoryName -ne $destPath) -and $_.Name -ne $MyInvocation.MyCommand.Name 
    }

    $validExtensions = @(".jpg", ".jpeg", ".png", ".heic", ".mov", ".mp4")

    foreach ($file in $allFiles) {
        if ($file.Extension.ToLower() -notin $validExtensions) { continue }

        $targetPath = Join-Path $destPath $file.Name
        
        # If the file already exists in the root with the same name, append a suffix to avoid overwriting
        $finalTarget = $targetPath
        $count = 1
        while (Test-Path $finalTarget) {
            $finalTarget = Join-Path $destPath ($file.BaseName + "_" + $count + $file.Extension)
            $count++
        }
        
        try {
            Move-Item -Path $file.FullName -Destination $finalTarget -ErrorAction Stop
            Write-Host "Moved: $($file.Name) from $($file.Directory.Name)" -ForegroundColor Gray
        }
        catch {
            Write-Host "Error moving $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n--- Step 2: Renaming files by date ---" -ForegroundColor Cyan

    # 2. Rename all files in the destination folder
    $filesToRename = Get-ChildItem -Path $destPath -File | Where-Object { 
        $_.Extension -match "jpg|jpeg|png|heic|mov|mp4" -and $_.Name -ne $MyInvocation.MyCommand.Name 
    }

    foreach ($file in $filesToRename) {
        # Use the oldest date between Creation and Modification to better approximate the original date
        $date = $file.LastWriteTime
        if ($file.CreationTime -lt $date) { $date = $file.CreationTime }

        $newName = $date.ToString("yyyyMMdd_HHmmss")
        $extension = $file.Extension.ToLower()
        $finalName = $newName + $extension
        
        $count = 1
        while (Test-Path (Join-Path $destPath $finalName)) {
            $finalName = $newName + "_" + $count + $extension
            $count++
        }
        
        if ($file.Name -ne $finalName) {
            try {
                Rename-Item -Path $file.FullName -NewName $finalName -ErrorAction Stop
            }
            catch {
                Write-Host "Error renaming $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    # 3. Optional cleanup: Delete empty folders
    Write-Host "`n--- Cleaning empty folders ---" -ForegroundColor Yellow
    Get-ChildItem -Path $sourcePath -Directory | ForEach-Object {
        if ((Get-ChildItem -Path $_.FullName -Recurse -File).Count -eq 0) {
            Remove-Item -Path $_.FullName -Recurse
            Write-Host "Empty folder removed: $($_.Name)"
        }
    }

    Write-Host "`n--- All done! Photos moved, renamed, and folders cleaned." -ForegroundColor Green
}
catch {
    Write-Host "`nAn unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Read-Host "Press Enter to exit..."
}