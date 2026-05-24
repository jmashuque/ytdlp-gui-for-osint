# yt-dlp GUI for OSINT

A portable Windows GUI wrapper for an OSINT-oriented `yt-dlp` capture workflow.

This app is designed to make repeatable web and video captures easier by exposing common capture settings through a simple Tkinter interface while still calling an underlying PowerShell capture script.

The app does not replace `yt-dlp`. It provides a guided interface for selecting inputs, cookies, output folders, VPN adapter checks, profiles, and capture options.

## Main capabilities

- Run a PowerShell-based `yt-dlp` capture script from a GUI.
- Capture URLs from a selected input text file or from URLs pasted directly into the GUI.
- Save pasted URLs to a text file.
- Load URLs from an existing input file into the URL box.
- Use browser-exported or manually supplied cookies files.
- Export cookies from supported installed browsers using `yt-dlp`'s built-in `--cookies-from-browser` method.
- Encrypt and decrypt cookies files for safer storage.
- Select a VPN/network adapter and check whether it is currently up.
- Select an impersonation target such as `chrome`, `edge`, or `firefox`.
- Query available `yt-dlp` impersonation targets.
- Prefer MP4-compatible output when desired.
- Run a preflight check before capture.
- Start and stop captures from the GUI.
- Save and load portable settings JSON files.
- Use named profiles stored inside the same settings JSON file.
- Open the current case folder directly from the Case Name row.
- View capture output and status in the GUI log pane.

## Typical folder layout

A typical portable layout is:

```text
yt-dlp-gui-folder\
    gui.py
    script.ps1
    yt-dlp.exe
    deno.exe
    cookies.txt
    gui-settings.json
    ffmpeg\
        ffmpeg.exe
        ffprobe.exe
    Investigations\
        Case-YYYY-MM-DD\
```

The app can run from a local folder or a synced folder, but a local folder is recommended for reliability, such as:

```text
C:\InvestigationToolkit\
```

For active captures, a local output folder is also recommended:

```text
C:\Investigations\
```

You can archive or copy completed case folders to OneDrive or another approved storage location after the capture completes.

## Required tools

### Python

Required if running the `.py` version directly.

The app uses only Python standard-library modules, including:

- `tkinter`
- `subprocess`
- `json`
- `tempfile`
- `hashlib`
- `hmac`
- `secrets`

No virtual environment is required unless you want one for your own packaging workflow.

### PowerShell capture script

The GUI calls:

```text
script.ps1
```

The GUI passes the relevant fields as PowerShell parameters.

### yt-dlp

The GUI expects a local `yt-dlp.exe`.

Default path:

```text
.\yt-dlp.exe
```

### Deno

Deno is expected to be located beside `yt-dlp.exe`.

Default expected path:

```text
.\deno.exe
```

### FFmpeg

The GUI expects an FFmpeg folder containing:

```text
ffmpeg.exe
ffprobe.exe
```

## Basic workflow

1. Launch the GUI.
2. Confirm or select:
   - Script Path
   - yt-dlp Path
   - Input File, or paste URLs into the URL box
   - Case Name
   - Cookies File, if needed
   - Output Root
   - FFmpeg Folder
   - Impersonate Target
   - VPN Adapter
3. Click **Check VPN** if VPN status matters for the capture.
4. Click **Preflight Check**.
5. Confirm the preflight checkbox is ticked.
6. Click **▶ Start Capture**.
7. Review the output log.
8. Open the case folder with the **Open** button beside the Case Name field.

## Input URLs

You can provide URLs in two ways.

### Input File

Set **Input File** to a `.txt` file containing one URL per line.

Example:

```text
https://example.com/video1
https://example.com/video2
https://example.com/post/123
```

### Pasted URL box

Paste URLs directly into the large URL box.

If the URL box contains text, it overrides the Input File field for that run.

Blank lines and lines starting with `#` are ignored.

## Case Name and output structure

The **Case Name** is used to create the case folder under the selected **Output Root**.

Example:

```text
Output Root: C:\Investigations
Case Name:   Case-2026-05-23
```

Expected case folder:

```text
C:\Investigations\Case-2026-05-23\
```

The PowerShell script is expected to create or use subfolders such as:

```text
media\
logs\
manifests\
```

The GUI run summary attempts to report:

- case folder
- media folder
- logs folder
- manifests folder
- download archive
- number of manifest CSV files
- number of log files

## Cookies features

The GUI includes a **Cookies** menu with:

- Export Browser Cookies
- Encrypt Cookies for Storage
- Decrypt Cookies from Storage

### Export Browser Cookies

This uses `yt-dlp`'s built-in browser cookie extraction.

Supported browser choices in the GUI:

- Chrome
- Edge
- Firefox

The export uses a hardcoded single reference URL and runs `yt-dlp` with simulation/no-playlist behavior to avoid walking homepage feeds or playlists.

The export dialog includes this checkbox:

```text
Update main Cookies File field after export
```

When checked, the main Cookies File field is updated to the exported file path.

### Cookie security warning

A raw cookies file can behave like a browser login session. Treat it like a credential.

Recommended handling:

```text
cookies.txt      local, short-lived, do not share
cookies.txt.enc  safer for storage or transfer if protected with a strong password
```

Do not store or share raw cookies files unless your organization explicitly permits that handling.

### Encrypt Cookies for Storage

This encrypts a raw cookies file using Python standard-library cryptographic primitives:

- PBKDF2-HMAC-SHA256 key derivation
- HMAC-SHA256 stream XOR encryption
- HMAC-SHA256 integrity checking

Minimum password length:

```text
8 characters
```

This feature is intended for basic storage protection. It does not delete the original plaintext cookies file.

### Decrypt Cookies from Storage

This decrypts an encrypted cookies file to a plaintext cookies file selected by the user.

`yt-dlp` requires plaintext cookies at capture time.

## VPN adapter check

The GUI lists all detected Windows network adapters.

The user chooses which adapter represents the VPN.

The selected adapter is saved in settings.

The **Check VPN** button checks whether the selected adapter status is:

```text
Up
```

If the selected adapter is up, the GUI reports:

```text
VPN: Connected
```

If not, it reports that the adapter is not connected or not found.

The VPN check is informational. Starting a capture with VPN not connected prompts the user to confirm whether to continue.

## Impersonate Target

The **Impersonate Target** dropdown defaults to:

- None
- chrome
- edge
- firefox

The **Check Targets** button queries:

```text
yt-dlp --list-impersonate-targets
```

The GUI filters returned targets to Windows browser targets when possible.

Use **None** to omit `--impersonate`.

## Prefer MP4

When **Prefer MP4** is enabled, the GUI passes the MP4 preference flag to the PowerShell script.

The PowerShell script should then apply the intended `yt-dlp` arguments, such as:

```text
--format bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/best
--merge-output-format mp4
```

This is useful when MP4 output is preferred for compatibility.

## Update yt-dlp

When **Update yt-dlp** is checked, the GUI passes the update flag to the PowerShell script.

The script is expected to handle the actual update behavior.

If your environment uses a specific update channel, confirm the PowerShell script uses the intended `yt-dlp` update target.

## Preflight Check

The **Preflight Check** validates common requirements before capture:

- PowerShell script exists
- `yt-dlp.exe` exists
- `deno.exe` exists beside `yt-dlp.exe`
- `ffmpeg.exe` exists in the FFmpeg folder
- `ffprobe.exe` exists in the FFmpeg folder
- input URLs are available from either the URL box or input file
- cookies file exists, if specified
- output root exists or can be created
- `yt-dlp` can run

After preflight runs, the checkbox beside the button is ticked.

The checkbox is a status indicator, not a user-controlled setting.

## Profiles

The app supports profiles stored inside the same settings JSON file.

The title bar always shows the active profile:

```text
yt-dlp GUI for OSINT - Profile: Default
```

### Default profile

The **Default** profile always loads at startup.

Automatic persistent saves always write the current GUI settings to the **Default** profile.

This includes saves when:

- the app closes
- a capture starts
- default portable settings are saved

### Custom profiles

Custom profiles are only created or overwritten through the **Profile** menu.

Use custom profiles for different workflows, such as:

```text
Video Host capture
Social Media capture
High compatibility MP4
No cookies
Specific VPN adapter
```

### Profile menu commands

The Profile menu includes:

- Save Current Settings to Profile...
- Delete Selected Profile...
- Load Default Profile
- Existing Profiles

### Reset Defaults and profiles

**Reset Defaults** only resets the GUI fields and the **Default** profile.

It does not erase custom profiles.

Custom profiles can only be deleted through the Profile menu.

## Settings files

The app uses a portable JSON settings file in the same folder as the GUI:

```text
gui-settings.json
```

The settings file stores:

- Default profile
- Custom profiles
- paths and options for each profile

The URL box contents are not saved.

### Save Settings As...

The Settings menu includes:

```text
Save Settings As...
```

This opens a file dialog and saves the complete settings JSON, including all profiles.

### Load Settings...

The Settings menu includes:

```text
Load Settings...
```

This opens a file dialog and loads a settings JSON file.

When loading a settings file, all profiles in the file are remembered. The **Default** profile is applied immediately.

### Save Default Portable Settings

This saves the current GUI settings to the default portable `gui-settings.json`.

## Menu overview

### File

- Load URLs From Input File
- Save URLs To File
- Clear URL Box
- Open Output Folder
- Open Current Case Folder
- Exit

### Capture

- Preflight Check
- Start Capture
- Stop Capture
- Delete Current Case Folder

### Cookies

- Export Browser Cookies
- Encrypt Cookies for Storage
- Decrypt Cookies from Storage

### Tools

- Check Impersonate Targets
- Refresh VPN Adapters
- Check VPN

### Profile

- Save Current Settings to Profile...
- Delete Selected Profile...
- Load Default Profile
- Existing Profiles

### Settings

- Save Settings As...
- Load Settings...
- Reset Defaults
- Save Default Portable Settings

## Security and organizational compatibility notes

This tool is designed to run without installation, but organizational security controls may still affect it.

Potentially sensitive or controlled behaviors include:

- launching PowerShell scripts
- running `yt-dlp.exe`
- running FFmpeg
- accessing browser cookies
- downloading or capturing online media
- writing case data to synced folders
- storing cookies files

For managed environments:

- Prefer locally staged, approved binaries.
- Avoid downloading binaries from inside the GUI.
- Keep raw cookies local and short-lived.
- Use encrypted cookies files for storage.
- Store active captures on a local disk.
- Archive completed case folders to approved storage after capture.
- Avoid running the toolkit from shared folders where multiple users may overwrite settings.
- Ensure the toolkit folder is writable if using portable settings.

## OneDrive notes

The app can run from a OneDrive folder and can output to OneDrive folders, but this is not ideal for active captures.

If OneDrive must be used:

- mark the toolkit folder as **Always keep on this device**
- mark the output folder as **Always keep on this device**
- avoid storing raw cookies in OneDrive
- expect possible sync conflicts or performance impact during active captures

Recommended workflow:

```text
Run locally
Capture locally
Copy or archive completed case folder to OneDrive afterward
```

## Troubleshooting

### No adapters appear

Click:

```text
Tools > Refresh VPN Adapters
```

If still empty, confirm this works in PowerShell:

```powershell
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status
```

### VPN says not connected

Confirm the selected adapter is the actual VPN adapter.

Some VPN clients create more than one adapter. Select the one whose status changes to `Up` when VPN connects.

### Cookie export succeeds but yt-dlp returns exit code 1

The GUI treats cookie export as successful if a non-empty cookies file exists or if `yt-dlp` output indicates cookies were extracted/exported.

A non-zero exit code can occur while processing the harmless reference URL even after cookies were exported.

### Preflight fails on ffmpeg

Confirm the selected FFmpeg folder contains:

```text
ffmpeg.exe
ffprobe.exe
```

### Preflight fails on Deno

Confirm `deno.exe` is beside `yt-dlp.exe`.

### Settings are not saving

The app saves settings beside the GUI file:

```text
gui-settings.json
```

Confirm the folder is writable.

### URL box overrides Input File

If the URL box contains any usable URLs, the GUI creates a temporary URL file for that run and ignores the Input File field.

Clear the URL box to use the Input File field.

## Important limitations

- The app does not validate whether a capture is legally or organizationally authorized.
- The app does not guarantee that a website will permit access or download.
- The app does not bypass access controls.
- The VPN check only checks adapter status; it does not prove traffic is routed through VPN.
- Cookies must be handled according to your organization's security and privacy policies.
- The GUI depends on the behavior and parameters supported by the underlying PowerShell script.
