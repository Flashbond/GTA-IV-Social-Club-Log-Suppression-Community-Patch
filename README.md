# GTA IV - Social Club Log Suppression Community Patch

## The Issue

Excessive Social Club logging has been observed with the downloadable release of GTA IV Complete Edition v1.2.0.59. The `socialclub_LOG.txt` file may grow continuously while the game is running, with repeated entries being written over and over.

This constant logging activity may contribute to longer loading times and reduced in-game frame rates. Suppressing the repeated formatted output may reduce this overhead, potentially shortening loading times and improving FPS on affected systems. The actual performance impact varies depending on the system and DLL build.

## What Does This Patch Do?

This patch modifies `socialclub.dll` to disable the targeted `_fwprintf` routine by making it return immediately.

The PowerShell script searches for the following 15-byte signature:

`55 8B EC 83 EC 08 8D 45 10 89 45 FC 8B 4D FC`

If exactly one match is found, the script creates and verifies a backup before replacing the first three bytes with:

`33 C0 C3` — `XOR EAX,EAX; RET`

This prevents the targeted routine from performing its formatted output. The change affects the `_fwprintf` routine generally within `socialclub.dll`; it is **not limited to `socialclub_LOG.txt`**. Other output using this routine may also be suppressed.

The patch does not guarantee that all Social Club logging or file activity will stop, nor does it guarantee a performance improvement.

## Target Version and Compatibility

This patcher was written specifically with GTA IV version **1.2.0.59** in mind.

Different downloadable releases and DLL builds may contain different code. The script uses a byte signature instead of relying on a specific file size or hash. However, finding the signature does not guarantee that every DLL containing it is compatible with this patch.

**If you are not experiencing excessive `socialclub_LOG.txt` growth or related loading-time or performance problems, using this patch is NOT recommended.**

Do not apply the patch just because it is available. Use it only if you understand what it changes and accept the associated risks.

## How to Use

Close GTA IV before running the patch.

### Option 1: Run the Script

1. Place `Patch-SocialClubLog.ps1` in the GTA IV game folder, alongside `socialclub.dll`.
2. Right-click the downloaded `.ps1` file, select **Properties**, check **Unblock**, then click **Apply** and **OK**. *(Note: If the Unblock option is not shown, skip this step).*
3. Right-click the `.ps1` file and select **Run with PowerShell**.

### Option 2: Run It in Terminal

1. Right-click an empty space inside the game folder and select **Open in Terminal**.
1. Copy the entire content of `Patch-SocialClubLog.ps1` file.
1. Paste the script into the Terminal window and press **Enter**.

> [!IMPORTANT]
> * The script must run with the GTA IV game folder as the current working directory. Read the messages displayed by the script and follow any instructions if an error occurs.
> * If the patch succeeds, keep the backup until you have tested the game and confirmed that it works as expected.

## Backup and Restore

The script creates a timestamped backup of `socialclub.dll` before modifying the original file and verifies the backup.

After writing the patch, the script verifies the modified file. If writing or verification fails, it attempts to restore the original DLL from the backup.

If automatic restoration fails, close the game and manually restore the backup before launching it again.

Keep the original backup in a safe location.

## Disclaimer

This is an unofficial community patch. It is provided **AS IS**, without warranties or guarantees of any kind.

This patch modifies `socialclub.dll` and may affect other functionality that relies on the targeted formatting routine. Compatibility, stability, and performance improvements are not guaranteed.

**Use this patch entirely at your own risk.** The decision to use it and any consequences resulting from its use are the user's responsibility. The author and distributor accept no responsibility for crashes, corrupted files, lost data, or other problems resulting from this modification.

This patch is not affiliated with, endorsed by, or supported by Rockstar Games or Take-Two Interactive.
