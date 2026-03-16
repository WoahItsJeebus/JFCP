> [!NOTE]
> This tool is written in AutoHotkey and compiled with ahk2exe, meaning AutoHotkey is bundled and does not need to be installed separately.

This script follows the steps provided in [this Reddit post](https://www.reddit.com/r/farcry/comments/q4qola/solved_far_cry_6_fov_fix_pc/) to prevent Far Cry 6 from reducing the player's field of view when entering vehicles, riding horses, swimming, or performing similar actions.

By default, the game temporarily lowers the FOV during these states. This patch modifies the `FC_m64d3d12.dll` binary to disable that behavior, allowing the player's configured FOV to remain consistent. (This dll can be found in `<FarCry6Directory>/bin`, you will have to set the location at least once, the location is then saved in an ini file located in `%LocalAppData%/JFCP/FC6` for future runs.)

The tool automatically:
- Locates the byte pattern described in the original guide
- Applies the required hex patch
- Creates a .bak backup of the original DLL before modifying it