# XPDF

A minimal, ad-free PDF reader for personal use. Open, read, and manage PDF files on your device — including PDFs handed to the app through Android's "Open with" dialog.

---

## Features

- **PDF viewing** — rendered by `pdfrx` (PDFium). Pinch-to-zoom (100–300%), in-document text search with prev/next navigation and a match counter, jump-to-page dialog, outline/bookmarks panel, share the file via the share sheet, and a `current / total` page indicator.
- **Reading defaults (Settings)** — default page layout for newly opened files (Single — one page per viewport with a custom layout callback — or Continuous scroll), and a "Remember last page" toggle that controls both restore-on-open and save-on-close.
- **Import sources** — pick a PDF via the system file picker, download a PDF from a pasted URL, scan documents with the camera (ML Kit document scanner → single PDF), and convert picked/captured photos into a PDF (Images to PDF tool).
- **Recents list** — files are automatically added when opened; each entry keeps size, relative last-opened time, favorite flag, last-read page, and folder assignment. Sortable (recency, name, size) with a cached sort/filter pipeline and a name search filter.
- **Favorites view** — dedicated starred-files tab.
- **Library / folders** — create, rename, recolor, and delete color-coded folders; move files between folders (deleting a folder only un-categorizes its files).
- **"Open with" file association (Android)** — the app registers for `ACTION_VIEW` on `application/pdf` and routes imported PDFs straight into the viewer on both cold and warm starts.
- **Light / dark theme** — Material 3, persisted, no flash on launch.
- **Settings screen** — storage stats for files stored inside the app, "clear all imported files" (permanently deletes app-owned copies), "clear recent list", camera permission status with a link to system settings, and version info.

---

## Project Structure

```
lib/
├── main.dart                         → Entry point, theme setup, MultiProvider, navigatorKey, OpenWithListener wiring
├── colors.dart                       → All color constants + dark/light variant resolution (AppColors.colorOf)
├── models/
│   ├── recent_file.dart              → RecentFile: path/name/size/lastOpened/lastPage/isFavorite/folderId, JSON (de)serialization
│   ├── folder.dart                   → Folder: id/name/colorHex, fixed 6-color palette, JSON (de)serialization
│   └── selected_image.dart           → Ephemeral selected image for the Images-to-PDF flow
├── providers/
│   ├── recent_files_provider.dart    → Recents list state; sorting, favorites, folders, page tracking, persistence
│   ├── folders_provider.dart         → Folder CRUD; delete coordination via injected onFolderDeleted callback
│   ├── settings_provider.dart        → Reading defaults (page layout, remember last page)
│   ├── theme_provider.dart           → Light/dark preference (loaded before first frame)
│   └── image_to_pdf_provider.dart    → Local-to-screen state for the Images-to-PDF flow
├── screens/
│   ├── home_screen.dart              → Home/Favorites/Library/Settings tabs, search, import buttons, floating nav pill
│   ├── library_screen.dart           → Folder grid, Uncategorized pseudo-folder, FolderFilesScreen detail list
│   ├── settings_screen.dart          → All settings sections (Appearance/Reading/Storage/Recents/Permissions/About)
│   ├── pdf_viewer_screen.dart        → Full-screen pdfrx viewer: search, zoom, jump-to-page, bookmarks, share
│   ├── image_to_pdf_screen.dart      → Gallery/Camera pick, preview grid, convert, success sheet (Open/Share/Done)
│   └── isolation_test_screen.dart    → DEBUG ONLY: bare PdfViewer without any app wiring (not reachable in the UI)
├── services/
│   ├── file_service.dart             → file_picker wrapper, URL download with PDF content check, document scanning
│   ├── image_to_pdf_service.dart     → Image picking (gallery/camera) and pure-Dart PDF generation (pdf package)
│   ├── storage_service.dart          → All SharedPreferences access (recent files, folders, settings, dark mode)
│   └── open_with_listener.dart       → Root-level "Open with" intent listener (receive_sharing_intent)
└── widgets/
    ├── import_section.dart           → Files / Drive / Scan / URL import buttons
    ├── recent_file_card.dart         → File card: PDF badge, metadata, favorite star, 3-dot menu
    ├── folia_search_bar.dart         → Reusable search input (query owned by the parent)
    ├── empty_state.dart / empty_favorites_state.dart / no_search_results.dart
    ├── folder_card.dart / create_folder_dialog.dart / confirm_dialog.dart / move_to_folder_sheet.dart / sort_sheet.dart
    ├── url_import_dialog.dart        → Pasted-URL → download flow
    └── image_preview_grid.dart / selected_image_tile.dart → Images-to-PDF thumbnails
```

---

## Setup

Requirements:

- Flutter 3.47+ with Dart SDK `^3.13.0` (see `pubspec.yaml`).
- Android: `compileSdk = 37`, `minSdk = 24`, `targetSdk` follows `flutter.targetSdkVersion`. AGP `9.1.0`, Kotlin `2.4.0`, Java 17 (`android/settings.gradle.kts` / `android/app/build.gradle.kts`).
- iOS: `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are declared in `Info.plist`.

```sh
flutter pub get
flutter run                # debug on a connected device/emulator
flutter build apk --release
```

> The release build currently signs with the debug keystore (`android/app/build.gradle.kts`).

---

## Notable Technical Details

### "Open with" file association (receive_sharing_intent)

The app appears in Android's "Open with" chooser for PDFs via `ACTION_VIEW` intent filters on `application/pdf` in `AndroidManifest.xml` (mime-only plus explicit `content://` and `file://` schemes for OEM/browser compatibility).

`OpenWithListener` (`lib/services/open_with_listener.dart`) wraps the root screen and handles both delivery paths:

- **Cold start** — the launch intent is read once via `ReceiveSharingIntent.instance.getInitialMedia()` and then consumed with `reset()` so it is never re-delivered.
- **Warm start** — subsequent intents arrive on the `getMediaStream()` stream.

Key behaviors:

- The plugin resolves `content://` URIs into a real local cache file, so pdfrx can open the result directly.
- The listener still copies the file into the app documents directory (`shared_<timestamp>_<name>.pdf`) so the recents entry survives system cache cleanup — matching how downloads/scans are persisted.
- The recent list is hydrated first (`loadFiles()`) before injecting a new entry, so `HomeScreen`'s pending load can't overwrite it.
- Navigation happens through a shared `navigatorKey` (`main.dart`) because the listener lives below the `MaterialApp`'s widget tree.

### Persistence (SharedPreferences)

Whole lists are stored as a single JSON string per key — no database, no codegen:

| Key | Content |
|---|---|
| `recent_files` | Encoded `List<RecentFile>` (path, name, size, lastOpened, lastPage, isFavorite, folderId) |
| `folders` | Encoded `List<Folder>` (id, name, colorHex) |
| `default_page_layout` | `"single"` or `"continuous"` (default) |
| `remember_last_page` | bool (default `true`) |
| `sort_mode` | `recent`, `name_asc`, `name_desc`, `size_largest`, `size_smallest` |
| `dark_mode` | bool (default `true`) |

`RecentFile.fromJson` falls back gracefully when pre-favorites/pre-folders saved data lacks the new keys.

### PDF rendering and layout

Rendering is `pdfrx` (PDFium). "Single" page layout is not built into pdfrx 2.x, so the viewer supplies a custom `layoutPages` callback that places each page inside its own viewport-height slot; the callback re-runs when the viewport height changes (`onViewSizeChanged` → `controller.invalidate()`). Reading defaults are captured **once in `initState`**, so changing a setting mid-session never mutates an already-open viewer.

The "last page restore" flow: page changes update `_currentPage`; on `dispose()`, `updatePageNumber()` persists it via the provider (unless "Remember last page" is off); on open, `_currentPage` is seeded from `file.lastPage` and passed to `initialPageNumber`.

### Search filtering (recents)

The home-screen search query is local `StatefulWidget` state (`_searchQuery`): a purely visual filter, kept out of the provider. Sorted/filtered results are cached and invalidated only when the provider's monotonic `version` counter bumps or the query/sort-mode changes, avoiding re-sorting on every rebuild frame.

---

## Known Issues & Limitations

- **Google Drive import is a placeholder** — the Drive button in the import section shows a "coming soon" snackbar; it is not implemented.
- **Temporary debug logging is still present** — `pdf_viewer_screen.dart` logs a per-second `[Perf 1s]` counter line and several `[PdfViewer]`/`[Settings]` `debugPrint` traces. Harmless in release but noisy in development logs.
- **`isolation_test_screen.dart` is debug-only** — a bare pdfrx viewer used to isolate rendering-lag causes; not reachable from the UI.
- **Text selection is disabled** in the viewer (`textSelectionParams.enabled: false`).
- **Externally referenced files can go stale** — files picked from storage are referenced by absolute path only; if the file is moved or deleted externally, its recents entry still exists (Settings' storage stats silently skip missing files).
- **Removing a recents entry does not delete the file** — only files the app owns (copies in the documents directory: downloads, scans, shared imports, image-to-PDF conversions) can be permanently deleted via Settings → Clear all imported files.
- **Unused declared dependencies** — `open_filex` and `cupertino_icons` are in `pubspec.yaml` but not referenced in `lib/`.
- **Image-to-PDF page order** is selection order; images can be removed but not reordered.

---

## License

A personal-use app. No license configured.