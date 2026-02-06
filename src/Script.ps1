# Cargar ensamblados para GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Configuración del formulario
$form = New-Object System.Windows.Forms.Form
$form.Text = "Migrador de Fotos"
$form.Size = New-Object System.Drawing.Size(500, 260)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Función auxiliar para crear controles
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
    $btn.Text = "Examinar"
    $btn.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.SelectedPath = $txt.Text
        if ($dlg.ShowDialog() -eq "OK") { $txt.Text = $dlg.SelectedPath }
    })
    $form.Controls.Add($btn)
    return $txt
}

# Controles del formulario
CreateLabel "Carpeta de Origen:" 20
$txtSource = CreateBrowseSection 20 $PSScriptRoot

CreateLabel "Carpeta de Destino:" 80
$txtDest = CreateBrowseSection 80 $PSScriptRoot

# Botones Aceptar / Cancelar
$btnAccept = New-Object System.Windows.Forms.Button
$btnAccept.Location = New-Object System.Drawing.Point(140, 160)
$btnAccept.Size = New-Object System.Drawing.Size(100, 30)
$btnAccept.Text = "Aceptar"
$btnAccept.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnAccept)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(260, 160)
$btnCancel.Size = New-Object System.Drawing.Size(100, 30)
$btnCancel.Text = "Cancelar"
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
    [System.Windows.Forms.MessageBox]::Show("Las rutas seleccionadas no existen.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

try {
    Write-Host "--- Paso 1: Extrayendo archivos de subcarpetas ---" -ForegroundColor Cyan

    # 1. Mover archivos de subcarpetas a la carpeta de destino
    # Buscamos en todas las subcarpetas (-Recurse)
    $allFiles = Get-ChildItem -Path $sourcePath -Recurse -File | Where-Object { 
        ($_.DirectoryName -ne $destPath) -and $_.Name -ne $MyInvocation.MyCommand.Name 
    }

    $validExtensions = @(".jpg", ".jpeg", ".png", ".heic", ".mov", ".mp4")

    foreach ($file in $allFiles) {
        if ($file.Extension.ToLower() -notin $validExtensions) { continue }

        $targetPath = Join-Path $destPath $file.Name
        
        # Si el archivo ya existe en la raíz con el mismo nombre, le añade un sufijo para no sobrescribir
        $finalTarget = $targetPath
        $count = 1
        while (Test-Path $finalTarget) {
            $finalTarget = Join-Path $destPath ($file.BaseName + "_" + $count + $file.Extension)
            $count++
        }
        
        try {
            Move-Item -Path $file.FullName -Destination $finalTarget -ErrorAction Stop
            Write-Host "Movido: $($file.Name) desde $($file.Directory.Name)" -ForegroundColor Gray
        }
        catch {
            Write-Host "Error moviendo $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n--- Paso 2: Renombrando archivos por fecha ---" -ForegroundColor Cyan

    # 2. Renombrar todos los archivos en la carpeta de destino
    $filesToRename = Get-ChildItem -Path $destPath -File | Where-Object { 
        $_.Extension -match "jpg|jpeg|png|heic|mov|mp4" -and $_.Name -ne $MyInvocation.MyCommand.Name 
    }

    foreach ($file in $filesToRename) {
        # Usar la fecha mas antigua entre Creacion y Modificacion para aproximar mejor la fecha original
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
                Write-Host "Error renombrando $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    # 3. Limpieza opcional: Borrar carpetas vacias
    Write-Host "`n--- Limpiando carpetas vacias ---" -ForegroundColor Yellow
    Get-ChildItem -Path $sourcePath -Directory | ForEach-Object {
        if ((Get-ChildItem -Path $_.FullName -Recurse -File).Count -eq 0) {
            Remove-Item -Path $_.FullName -Recurse
            Write-Host "Carpeta vacia eliminada: $($_.Name)"
        }
    }

    Write-Host "`n--- Todo listo! Fotos movidas, renombradas y carpetas limpias." -ForegroundColor Green
}
catch {
    Write-Host "`nOcurrio un error inesperado: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Read-Host "Presione Enter para salir..."
}