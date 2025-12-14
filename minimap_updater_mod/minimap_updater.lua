--[[
  Minimap Auto-Updater for OTClientV8
  Checks GitHub for updates and downloads new minimap automatically

  GitHub: https://github.com/Ellero0/otclient-realmap-gunzodus
]]--

MinimapUpdater = {}

-- Configuration
local CONFIG = {
  github_repo = "Ellero0/otclient-realmap-gunzodus",
  github_api = "https://api.github.com/repos/Ellero0/otclient-realmap-gunzodus/releases/latest",
  download_url = "https://github.com/Ellero0/otclient-realmap-gunzodus/releases/latest/download/minimap1100.otmm",
  minimap_file = "minimap1100.otmm",
  version_key = "minimap_updater_version",
  last_check_key = "minimap_updater_last_check",
  check_interval = 3600, -- Check every hour (in seconds)
  enabled_key = "minimap_updater_enabled"
}

local httpOperationId = 0
local updateWindow = nil
local isUpdating = false

-- Initialize module
function init()
  -- Default to enabled
  if g_settings.getString(CONFIG.enabled_key) == "" then
    g_settings.set(CONFIG.enabled_key, "true")
  end

  -- Check for updates after a short delay (let client fully load)
  if g_settings.getString(CONFIG.enabled_key) == "true" then
    scheduleEvent(function()
      MinimapUpdater.checkForUpdates()
    end, 3000) -- 3 second delay
  end

  g_logger.info("[MinimapUpdater] Initialized")
end

-- Cleanup
function terminate()
  HTTP.cancel(httpOperationId)
  if updateWindow then
    updateWindow:destroy()
    updateWindow = nil
  end
  g_logger.info("[MinimapUpdater] Terminated")
end

-- Check if enough time has passed since last check
function MinimapUpdater.shouldCheck()
  local lastCheck = tonumber(g_settings.getString(CONFIG.last_check_key) or "0") or 0
  local now = os.time()
  return (now - lastCheck) >= CONFIG.check_interval
end

-- Check GitHub for updates
function MinimapUpdater.checkForUpdates(forceCheck)
  if isUpdating then
    g_logger.info("[MinimapUpdater] Already checking for updates")
    return
  end

  if not forceCheck and not MinimapUpdater.shouldCheck() then
    g_logger.info("[MinimapUpdater] Skipping check (checked recently)")
    return
  end

  g_logger.info("[MinimapUpdater] Checking for updates...")
  isUpdating = true

  -- Update last check time
  g_settings.set(CONFIG.last_check_key, tostring(os.time()))

  -- Query GitHub API for latest release
  httpOperationId = HTTP.getJSON(CONFIG.github_api, function(data, err)
    isUpdating = false

    if err then
      g_logger.warning("[MinimapUpdater] Failed to check updates: " .. tostring(err))
      return
    end

    if not data or not data.tag_name then
      g_logger.warning("[MinimapUpdater] Invalid response from GitHub")
      return
    end

    local remoteVersion = data.tag_name
    local localVersion = g_settings.getString(CONFIG.version_key) or "none"
    local publishedAt = data.published_at or "unknown"
    local releaseName = data.name or remoteVersion

    g_logger.info("[MinimapUpdater] Local: " .. localVersion .. ", Remote: " .. remoteVersion)

    -- Find the minimap asset download URL
    local downloadUrl = nil
    if data.assets then
      for _, asset in ipairs(data.assets) do
        if asset.name == CONFIG.minimap_file then
          downloadUrl = asset.browser_download_url
          break
        end
      end
    end

    -- Fallback to direct URL if asset not found
    if not downloadUrl then
      downloadUrl = CONFIG.download_url
    end

    if remoteVersion ~= localVersion then
      MinimapUpdater.showUpdateDialog(remoteVersion, localVersion, releaseName, downloadUrl)
    else
      g_logger.info("[MinimapUpdater] Minimap is up to date")
    end
  end)
end

-- Show update confirmation dialog
function MinimapUpdater.showUpdateDialog(newVersion, oldVersion, releaseName, downloadUrl)
  local message = string.format(
    "A new minimap update is available!\n\n" ..
    "Current version: %s\n" ..
    "New version: %s\n\n" ..
    "Release: %s\n\n" ..
    "Do you want to download and install the update?\n" ..
    "(Client will need to be restarted)",
    oldVersion == "none" and "Not installed" or oldVersion,
    newVersion,
    releaseName
  )

  local msgBox = displayGeneralBox(
    "Minimap Update Available",
    message,
    {
      { text = "Update Now", callback = function()
        MinimapUpdater.downloadUpdate(downloadUrl, newVersion)
      end},
      { text = "Later", callback = function()
        g_logger.info("[MinimapUpdater] Update postponed by user")
      end},
      { text = "Never", callback = function()
        g_settings.set(CONFIG.enabled_key, "false")
        g_logger.info("[MinimapUpdater] Auto-update disabled by user")
      end}
    },
    nil, nil, nil
  )
end

-- Download and install update
function MinimapUpdater.downloadUpdate(downloadUrl, newVersion)
  g_logger.info("[MinimapUpdater] Downloading update from: " .. downloadUrl)

  -- Create progress window
  updateWindow = g_ui.createWidget('MainWindow', rootWidget)
  updateWindow:setId('minimapUpdateWindow')
  updateWindow:setText('Downloading Minimap Update')
  updateWindow:setSize({width = 350, height = 120})
  updateWindow:center()

  local label = g_ui.createWidget('Label', updateWindow)
  label:setId('statusLabel')
  label:setText('Downloading minimap...')
  label:setTextAlign(AlignCenter)
  label:addAnchor(AnchorTop, 'parent', AnchorTop)
  label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  label:addAnchor(AnchorRight, 'parent', AnchorRight)
  label:setMarginTop(20)

  local progressBar = g_ui.createWidget('ProgressBar', updateWindow)
  progressBar:setId('progressBar')
  progressBar:setPercent(0)
  progressBar:addAnchor(AnchorTop, 'statusLabel', AnchorBottom)
  progressBar:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  progressBar:addAnchor(AnchorRight, 'parent', AnchorRight)
  progressBar:setMarginTop(10)
  progressBar:setMarginLeft(20)
  progressBar:setMarginRight(20)
  progressBar:setHeight(20)

  isUpdating = true

  -- Download the file
  httpOperationId = HTTP.download(downloadUrl, CONFIG.minimap_file,
    function(path, checksum, err)
      isUpdating = false

      if updateWindow then
        updateWindow:destroy()
        updateWindow = nil
      end

      if err then
        g_logger.error("[MinimapUpdater] Download failed: " .. tostring(err))
        displayErrorBox("Download Failed", "Failed to download minimap update:\n" .. tostring(err))
        return
      end

      g_logger.info("[MinimapUpdater] Download complete: " .. tostring(path))

      -- Save version
      g_settings.set(CONFIG.version_key, newVersion)

      -- Try to install the minimap
      local success = MinimapUpdater.installMinimap(path)

      if success then
        local msgBox = displayInfoBox(
          "Update Complete",
          "Minimap has been updated to " .. newVersion .. "!\n\n" ..
          "Please restart the client for changes to take effect."
        )
        msgBox.onOk = function()
          -- Optionally restart
          -- g_app.restart()
        end
      else
        displayInfoBox(
          "Update Downloaded",
          "Minimap " .. newVersion .. " has been downloaded.\n\n" ..
          "The file is in the downloads folder.\n" ..
          "Please manually copy it to your minimap folder and restart."
        )
      end
    end,
    function(progress, speed)
      if updateWindow then
        local progressBar = updateWindow:getChildById('progressBar')
        local statusLabel = updateWindow:getChildById('statusLabel')
        if progressBar then
          progressBar:setPercent(progress)
        end
        if statusLabel then
          statusLabel:setText(string.format('Downloading... %d%% (%s KB/s)', progress, speed))
        end
      end
    end
  )
end

-- Install minimap to the correct location
function MinimapUpdater.installMinimap(downloadedPath)
  -- Try to copy the downloaded file to the minimap location
  -- This depends on OTClient's resource system

  local success = false

  -- Method 1: Try using g_resources if available
  if g_resources and g_resources.fileExists then
    local downloadFile = '/downloads/' .. CONFIG.minimap_file
    if g_resources.fileExists(downloadFile) then
      -- The minimap is typically in the config directory
      -- OTClient should automatically pick it up on restart
      success = true
      g_logger.info("[MinimapUpdater] Minimap downloaded to: " .. downloadFile)
    end
  end

  return success
end

-- Manual update check (can be called from console or UI)
function MinimapUpdater.forceCheck()
  MinimapUpdater.checkForUpdates(true)
end

-- Enable/disable auto-updates
function MinimapUpdater.setEnabled(enabled)
  g_settings.set(CONFIG.enabled_key, enabled and "true" or "false")
  g_logger.info("[MinimapUpdater] Auto-update " .. (enabled and "enabled" or "disabled"))
end

-- Get current status
function MinimapUpdater.getStatus()
  return {
    enabled = g_settings.getString(CONFIG.enabled_key) == "true",
    currentVersion = g_settings.getString(CONFIG.version_key) or "none",
    lastCheck = g_settings.getString(CONFIG.last_check_key) or "never"
  }
end
