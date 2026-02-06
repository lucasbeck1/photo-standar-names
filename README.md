# Photo Migrator & Renamer

A PowerShell tool designed to organize your photo and video collections. It consolidates files from subdirectories into a single folder and renames them based on their timestamp.

## Features

- **Graphical User Interface:** Simple Windows Forms interface to select Source and Destination folders.
- **Flatten Directories:** Recursively moves files from all subfolders in the source to the destination folder.
- **Smart Renaming:** Renames media files (`jpg`, `jpeg`, `png`, `heic`, `mov`, `mp4`) to a standard `YYYYMMDD_HHmmss` format based on the `LastWriteTime`.
- **Conflict Resolution:** Automatically handles duplicate file names by appending a counter.
- **Cleanup:** Removes empty subfolders in the source directory after processing.

## Usage

1. Run the script `Script.ps1` with PowerShell or run executeScript file.
2. Select the **Source Folder** (containing the original files).
3. Select the **Destination Folder** (where files will be moved and renamed).
4. Click **Accept** to begin.

## Requirements

- Windows PowerShell
- .NET Framework (for Windows Forms)