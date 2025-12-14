# OTClient Real Map - Gunzodus

Pre-generated minimap files for OTClientV8 based on [tibiamaps.io](https://tibiamaps.io/) data.

## Quick Install

### Option 1: Auto-Updater (Recommended) - NOT YET WORKING

### Option 2: Manual Download

1. Download `minimap1100.otmm` from [Releases](https://github.com/Ellero0/otclient-realmap-gunzodus/releases)
2. Copy to your OTClient data folder:
   ```
   %APPDATA%\OTClientV8\gunzodus\minimap1100.otmm
   ```
3. Restart OTClient

---

## Auto-Updater Mod

The `minimap_updater_mod` folder contains a Lua module that:
- Checks GitHub for new minimap releases on startup
- Shows a popup when updates are available
- Downloads and installs updates automatically

### Installation

```
[YourOTClient]\
  mods\
    minimap_updater_mod\      <-- Copy this folder here
      minimap_updater.otmod
      minimap_updater.lua
      README.txt
```

### Console Commands

Open OTClient terminal (Ctrl+T) and use:

```lua
MinimapUpdater.forceCheck()      -- Force check for updates
MinimapUpdater.setEnabled(true)  -- Enable auto-updates
MinimapUpdater.setEnabled(false) -- Disable auto-updates
MinimapUpdater.getStatus()       -- Show current status
```

### Troubleshooting

If automatic installation fails, the downloaded file is saved to:
```
[OTClient]\downloads\minimap1100.otmm
```

Copy it manually to:
```
%APPDATA%\OTClientV8\gunzodus\minimap1100.otmm
```

---

## Files

| File | Description |
|------|-------------|
| `minimap1100.otmm` | Latest minimap file |
| `minimap_updater_mod/` | Auto-updater Lua module |
| `CHANGELOG.md` | Update history |

## Data Source

- Map data: [tibiamaps/tibia-map-data](https://github.com/tibiamaps/tibia-map-data)
- 6,276 markers included
- 16 floor levels (z=0 to z=15)

## Generation

Generated using C# parallel minimap generator (~1.5 seconds)

Generator source: `E:\OTC_MINIMAP_GEN\`

---

*Last update: 2025-12-14*
