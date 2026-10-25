# Photo Migrator & Renamer

A PowerShell tool designed to organize and standardize your photo and video collections. It recursively scans folders and nested subfolders at any depth, extracts accurate capture dates (via EXIF metadata or filesystem timestamps), and standardizes file names to `YYYYMMDD_HHmmss`.

## Features

- **Graphical User Interface:** Windows Forms interface to select Source and Destination folders with customization options.
- **Deep Recursive Traversal:** Reads from any directory structure, including folders with multiple levels of nested subfolders (`Folder -> Subfolders -> Sub-subfolders -> Media`).
- **Flexible Organization Modes:**
  - **Flatten (Consolidate):** Extracts all photos from all subfolders into a single destination folder.
  - **Preserve Hierarchy:** Maintains the relative subfolder structure in the destination, renaming files in-place or replicating the folder tree.
- **EXIF Date Taken Support:** Prioritizes real photo capture date from camera EXIF metadata (`DateTimeOriginal`), falling back safely to the earliest filesystem timestamp.
- **Single-Pass Processing:** Directly calculates the target standardized name and moves/copies files in a single pass, avoiding duplicate disk operations.
- **Copy or Move Options:** Choose to move files (default) or copy them safely to preserve your original source files.
- **Conflict Resolution:** Automatically prevents name collisions by appending an incrementing counter (`YYYYMMDD_HHmmss_1.ext`).
- **Wide Format Support:** Supports standard photos (`.jpg`, `.jpeg`, `.png`, `.heic`, `.heif`, `.webp`, `.bmp`, `.tiff`, `.tif`, `.gif`), camera RAW (`.cr2`, `.cr3`, `.nef`, `.arw`, `.dng`, `.orf`, `.rw2`), and videos (`.mov`, `.mp4`, `.avi`, `.mkv`, `.m4v`, `.3gp`, `.wmv`).
- **Smart Cleanup:** Optional bottom-up cleanup of empty source subfolders, ignoring system files (like `desktop.ini` and `Thumbs.db`) while protecting the destination folder.

## Usage

1. Run the script `Script.ps1` with PowerShell or double-click `executeScript.bat`.
2. Select the **Source Folder** (containing your media or nested subfolders).
3. Select the **Destination Folder** (where files will be organized).
4. Configure your options:
   - **Flatten subfolders:** Check to consolidate all media into the root destination folder, or uncheck to preserve the subfolder hierarchy.
   - **Delete empty source folders:** Remove empty subfolders in the source folder once files are moved.
   - **Keep original files (Copy instead of Move):** Leave source files intact by copying instead of moving.
5. Click **Start** to begin.

## Requirements

- Windows PowerShell 5.1 or later
- .NET Framework (included with Windows)
