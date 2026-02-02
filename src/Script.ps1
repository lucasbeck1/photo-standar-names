# Obtiene la ruta de la carpeta donde esta el script
$currentPath = $PSScriptRoot
Set-Location $currentPath

Write-Host "--- Paso 1: Extrayendo archivos de subcarpetas ---" -ForegroundColor Cyan

# 1. Mover archivos de subcarpetas a la carpeta raíz
# Buscamos en todas las subcarpetas (-Recurse) pero excluimos el propio script
$allFiles = Get-ChildItem -Path $currentPath -Recurse -File | Where-Object { 
    $_.DirectoryName -ne $currentPath -and $_.Name -ne $MyInvocation.MyCommand.Name 
}

foreach ($file in $allFiles) {
    $targetPath = Join-Path $currentPath $file.Name
    
    # Si el archivo ya existe en la raíz con el mismo nombre, le añade un sufijo para no sobrescribir
    $finalTarget = $targetPath
    $count = 1
    while (Test-Path $finalTarget) {
        $finalTarget = Join-Path $currentPath ($file.BaseName + "_" + $count + $file.Extension)
        $count++
    }
    
    Move-Item -Path $file.FullName -Destination $finalTarget
    Write-Host "Movido: $($file.Name) desde $($file.Directory.Name)" -ForegroundColor Gray
}

Write-Host "`n--- Paso 2: Renombrando archivos por fecha ---" -ForegroundColor Cyan

# 2. Renombrar todos los archivos en la carpeta actual
$filesToRename = Get-ChildItem -Path $currentPath -File | Where-Object { 
    $_.Extension -match "jpg|jpeg|png|heic|mov|mp4" -and $_.Name -ne $MyInvocation.MyCommand.Name 
}

foreach ($file in $filesToRename) {
    $date = $file.LastWriteTime
    $newName = $date.ToString("yyyyMMdd_HHmmss")
    $extension = $file.Extension.ToLower()
    $finalName = $newName + $extension
    
    $count = 1
    while (Test-Path (Join-Path $currentPath $finalName)) {
        $finalName = $newName + "_" + $count + $extension
        $count++
    }
    
    Rename-Item -Path $file.FullName -NewName $finalName
}

# 3. Limpieza opcional: Borrar carpetas vacias
Write-Host "`n--- Limpiando carpetas vacias ---" -ForegroundColor Yellow
Get-ChildItem -Path $currentPath -Directory | ForEach-Object {
    if ((Get-ChildItem -Path $_.FullName -Recurse -File).Count -eq 0) {
        Remove-Item -Path $_.FullName -Recurse
        Write-Host "Carpeta vacia eliminada: $($_.Name)"
    }
}

Write-Host "`n--- Todo listo! Fotos movidas, renombradas y carpetas limpias." -ForegroundColor Green
Pause