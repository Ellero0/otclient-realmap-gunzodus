===============================================
  MINIMAP AUTO-UPDATER FOR OTCLIENTV8
  GitHub: Ellero0/otclient-realmap-gunzodus
===============================================

INSTALLATION
------------
1. Copy the entire "minimap_updater" folder to your OTClient mods directory:
   [OTClient folder]\mods\minimap_updater\

2. The folder should contain:
   - minimap_updater.otmod
   - minimap_updater.lua
   - README.txt

3. Start OTClient - the mod will auto-load and check for updates.


HOW IT WORKS
------------
- On client startup, checks GitHub for the latest minimap release
- If a new version is found, shows a popup with options:
  * "Update Now" - Downloads and installs the update
  * "Later" - Skip this time (will ask again next session)
  * "Never" - Disable auto-update completely

- After download, you need to restart the client for changes to take effect.


CONSOLE COMMANDS
----------------
You can use these in the OTClient terminal (Ctrl+T):

  MinimapUpdater.forceCheck()     - Force check for updates now
  MinimapUpdater.setEnabled(true) - Enable auto-updates
  MinimapUpdater.setEnabled(false)- Disable auto-updates
  MinimapUpdater.getStatus()      - Show current status


MANUAL INSTALLATION (if auto-install fails)
-------------------------------------------
If the automatic installation doesn't work:

1. The minimap file is downloaded to:
   [OTClient folder]\downloads\minimap1100.otmm

2. Copy it manually to your minimap folder:
   %APPDATA%\OTClientV8\gunzodus\minimap1100.otmm

3. Restart OTClient


TROUBLESHOOTING
---------------
- If updates don't show: Check your internet connection
- If download fails: The GitHub API may be rate-limited, try again later
- If minimap doesn't update: Copy the file manually from downloads folder


VERSION INFO
------------
The mod stores version info in OTClient settings:
- minimap_updater_version: Current installed version
- minimap_updater_last_check: Last update check timestamp
- minimap_updater_enabled: Auto-update enabled/disabled


GITHUB REPOSITORY
-----------------
https://github.com/Ellero0/otclient-realmap-gunzodus

Data source: https://github.com/tibiamaps/tibia-map-data
