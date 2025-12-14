--[[
  Minimap Auto-Updater for OTClientV8
  Checks GitHub for updates BEFORE character list is shown
  Waits for complete download and verifies file size

  GitHub: https://github.com/Ellero0/otclient-realmap-gunzodus
]]--

MinimapUpdater = {}

-- Configuration
local CONFIG = {
  github_api = "https://api.github.com/repos/Ellero0/otclient-realmap-gunzodus/releases/latest",
  minimap_file = "minimap1100.otmm",
  version_key = "minimap_updater_version",
  enabled_key = "minimap_updater_enabled"
}

local httpOperationId = 0
local updateWindow = nil
local isChecking = false
local isDownloading = false
local pendingCallback = nil
local originalCharacterListShow = nil
local expectedFileSize = 0

-- Initialize module
function init()
  -- Default to enabled
  if g_settings.getString(CONFIG.enabled_key) == "" then
    g_settings.set(CONFIG.enabled_key, "true")
  end

  -- Hook into CharacterList.show to check updates first
  if CharacterList and CharacterList.show then
    originalCharacterListShow = CharacterList.show
    CharacterList.show = function()
      MinimapUpdater.onBeforeCharacterList(function()
        if originalCharacterListShow then
          originalCharacterListShow()
        end
      end)
    end
  end

  g_logger.info("[MinimapUpdater] Initialized - will check before character list")
end

-- Cleanup
function terminate()
  HTTP.cancel(httpOperationId)
  MinimapUpdater.destroyWindow()
  if originalCharacterListShow and CharacterList then
    CharacterList.show = originalCharacterListShow
  end
  g_logger.info("[MinimapUpdater] Terminated")
end

-- Destroy update window
function MinimapUpdater.destroyWindow()
  if updateWindow then
    updateWindow:destroy()
    updateWindow = nil
  end
end

-- Called before character list is shown
function MinimapUpdater.onBeforeCharacterList(callback)
  if g_settings.getString(CONFIG.enabled_key) ~= "true" then
    g_logger.info("[MinimapUpdater] Auto-update disabled, skipping check")
    callback()
    return
  end

  if isChecking or isDownloading then
    pendingCallback = callback
    return
  end

  pendingCallback = callback
  MinimapUpdater.checkForUpdates()
end

-- Cancel button handler
function MinimapUpdater.onCancel()
  HTTP.cancel(httpOperationId)
  isChecking = false
  isDownloading = false
  MinimapUpdater.destroyWindow()
  MinimapUpdater.continueToCharacterList()
end

-- Check GitHub for updates
function MinimapUpdater.checkForUpdates()
  if isChecking then return end

  isChecking = true
  g_logger.info("[MinimapUpdater] Checking for updates...")

  MinimapUpdater.showWindow("Checking for minimap updates...", 0)

  httpOperationId = HTTP.getJSON(CONFIG.github_api, function(data, err)
    isChecking = false

    if err then
      g_logger.warning("[MinimapUpdater] Check failed: " .. tostring(err))
      MinimapUpdater.destroyWindow()
      MinimapUpdater.continueToCharacterList()
      return
    end

    if not data or not data.tag_name then
      g_logger.warning("[MinimapUpdater] Invalid GitHub response")
      MinimapUpdater.destroyWindow()
      MinimapUpdater.continueToCharacterList()
      return
    end

    local remoteVersion = data.tag_name
    local localVersion = g_settings.getString(CONFIG.version_key) or "none"
    local releaseName = data.name or remoteVersion

    g_logger.info("[MinimapUpdater] Local: " .. localVersion .. ", Remote: " .. remoteVersion)

    -- Find download URL and file size from assets
    local downloadUrl = nil
    expectedFileSize = 0

    if data.assets then
      for _, asset in ipairs(data.assets) do
        if asset.name == CONFIG.minimap_file then
          downloadUrl = asset.browser_download_url
          expectedFileSize = asset.size or 0
          g_logger.info("[MinimapUpdater] Found asset: " .. asset.name .. " size: " .. tostring(expectedFileSize))
          break
        end
      end
    end

    if not downloadUrl then
      downloadUrl = "https://github.com/Ellero0/otclient-realmap-gunzodus/releases/latest/download/" .. CONFIG.minimap_file
      g_logger.info("[MinimapUpdater] Using fallback URL (no size check)")
    end

    MinimapUpdater.destroyWindow()

    if remoteVersion ~= localVersion then
      MinimapUpdater.showUpdateDialog(remoteVersion, localVersion, releaseName, downloadUrl, expectedFileSize)
    else
      g_logger.info("[MinimapUpdater] Minimap is up to date")
      MinimapUpdater.continueToCharacterList()
    end
  end)
end

-- Show progress window
function MinimapUpdater.showWindow(status, percent)
  MinimapUpdater.destroyWindow()

  updateWindow = g_ui.displayUI('minimap_updater')
  if updateWindow then
    updateWindow:show()
    updateWindow:raise()
    updateWindow:focus()

    local statusLabel = updateWindow:getChildById('statusLabel')
    local progressBar = updateWindow:getChildById('progressBar')
    local speedLabel = updateWindow:getChildById('speedLabel')

    if statusLabel then
      statusLabel:setText(status)
    end
    if progressBar then
      progressBar:setPercent(percent)
    end
    if speedLabel then
      speedLabel:setText("")
    end
  end
end

-- Update progress
function MinimapUpdater.updateProgress(status, percent, speed)
  if not updateWindow then return end

  local statusLabel = updateWindow:getChildById('statusLabel')
  local progressBar = updateWindow:getChildById('progressBar')
  local speedLabel = updateWindow:getChildById('speedLabel')

  if statusLabel then
    statusLabel:setText(status)
  end
  if progressBar then
    progressBar:setPercent(percent)
  end
  if speedLabel and speed then
    speedLabel:setText(speed .. " KB/s")
  end
end

-- Show update dialog
function MinimapUpdater.showUpdateDialog(newVersion, oldVersion, releaseName, downloadUrl, fileSize)
  local sizeStr = ""
  if fileSize > 0 then
    sizeStr = string.format("\nSize: %.2f MB", fileSize / 1024 / 1024)
  end

  local message = string.format(
    "New minimap update available!\n\n" ..
    "Current: %s\n" ..
    "New: %s%s\n\n" ..
    "Download now?",
    oldVersion == "none" and "Not installed" or oldVersion,
    newVersion,
    sizeStr
  )

  local msgBox = displayGeneralBox(
    "Minimap Update",
    message,
    {
      { text = "Yes, Update", callback = function()
        MinimapUpdater.downloadUpdate(downloadUrl, newVersion, fileSize)
      end},
      { text = "No, Skip", callback = function()
        g_logger.info("[MinimapUpdater] Update skipped by user")
        MinimapUpdater.continueToCharacterList()
      end},
      { text = "Disable", callback = function()
        g_settings.set(CONFIG.enabled_key, "false")
        g_logger.info("[MinimapUpdater] Auto-update disabled")
        MinimapUpdater.continueToCharacterList()
      end}
    },
    nil, nil, nil
  )
end

-- Download update with size verification
function MinimapUpdater.downloadUpdate(downloadUrl, newVersion, fileSize)
  g_logger.info("[MinimapUpdater] Downloading: " .. downloadUrl)
  g_logger.info("[MinimapUpdater] Expected size: " .. tostring(fileSize) .. " bytes")

  isDownloading = true
  expectedFileSize = fileSize

  MinimapUpdater.showWindow("Starting download...", 0)

  local downloadStartTime = os.time()
  local lastProgress = 0

  httpOperationId = HTTP.download(downloadUrl, CONFIG.minimap_file,
    function(path, checksum, err)
      isDownloading = false

      if err then
        g_logger.error("[MinimapUpdater] Download failed: " .. tostring(err))
        MinimapUpdater.destroyWindow()
        displayErrorBox("Download Failed", "Failed to download minimap:\n" .. tostring(err)).onOk = function()
          MinimapUpdater.continueToCharacterList()
        end
        return
      end

      g_logger.info("[MinimapUpdater] Download complete, path: " .. tostring(path))
      g_logger.info("[MinimapUpdater] Checksum: " .. tostring(checksum))

      -- Update status
      MinimapUpdater.updateProgress("Verifying download...", 100, nil)

      -- Verify file exists in downloads
      local downloadedFile = '/downloads/' .. CONFIG.minimap_file
      if not g_resources.fileExists(downloadedFile) then
        g_logger.error("[MinimapUpdater] Downloaded file not found: " .. downloadedFile)
        MinimapUpdater.destroyWindow()
        displayErrorBox("Download Failed", "Downloaded file not found.\nPlease try again.").onOk = function()
          MinimapUpdater.continueToCharacterList()
        end
        return
      end

      -- Check file size if we know expected size
      if expectedFileSize > 0 then
        local localSize = g_resources.fileSize(downloadedFile)
        g_logger.info("[MinimapUpdater] Local size: " .. tostring(localSize) .. ", Expected: " .. tostring(expectedFileSize))

        if localSize and localSize > 0 then
          if localSize < expectedFileSize * 0.9 then
            -- File is too small (less than 90% of expected)
            g_logger.error("[MinimapUpdater] File too small: " .. tostring(localSize) .. " < " .. tostring(expectedFileSize))
            MinimapUpdater.destroyWindow()
            displayErrorBox("Download Incomplete",
              string.format("Download incomplete!\n\nExpected: %.2f MB\nGot: %.2f MB\n\nPlease try again.",
                expectedFileSize / 1024 / 1024,
                localSize / 1024 / 1024)
            ).onOk = function()
              MinimapUpdater.continueToCharacterList()
            end
            return
          end
        end
      end

      -- Try to copy to minimap location
      MinimapUpdater.updateProgress("Installing minimap...", 100, nil)

      -- Copy file to minimap locations
      local success = MinimapUpdater.installMinimap(downloadedFile)

      MinimapUpdater.destroyWindow()

      -- Save version
      g_settings.set(CONFIG.version_key, newVersion)

      if success then
        displayInfoBox("Update Complete",
          "Minimap updated to " .. newVersion .. "!\n\n" ..
          "Restart the client to use the new minimap."
        ).onOk = function()
          MinimapUpdater.continueToCharacterList()
        end
      else
        displayInfoBox("Download Complete",
          "Minimap " .. newVersion .. " downloaded!\n\n" ..
          "File is in the downloads folder.\n" ..
          "Please copy it manually to your minimap folder."
        ).onOk = function()
          MinimapUpdater.continueToCharacterList()
        end
      end
    end,
    function(progress, speed)
      lastProgress = progress
      local sizeInfo = ""
      if expectedFileSize > 0 then
        local downloaded = (progress / 100) * expectedFileSize
        sizeInfo = string.format(" (%.1f / %.1f MB)", downloaded / 1024 / 1024, expectedFileSize / 1024 / 1024)
      end
      MinimapUpdater.updateProgress(
        string.format("Downloading... %d%%%s", progress, sizeInfo),
        progress,
        speed
      )
    end
  )
end

-- Install minimap to correct locations
function MinimapUpdater.installMinimap(sourcePath)
  local success = false

  -- Try to copy to various minimap locations
  local destinations = {
    '/' .. CONFIG.minimap_file,
    '/minimap.otmm',
    '/minimap1000.otmm'
  }

  for _, dest in ipairs(destinations) do
    local ok = pcall(function()
      if g_resources.fileExists(sourcePath) then
        -- Read source file
        local content = g_resources.readFileContents(sourcePath)
        if content and #content > 1000000 then  -- At least 1MB
          g_resources.writeFileContents(dest, content)
          g_logger.info("[MinimapUpdater] Copied to: " .. dest)
          success = true
        end
      end
    end)
    if not ok then
      g_logger.warning("[MinimapUpdater] Failed to copy to: " .. dest)
    end
  end

  return success
end

-- Continue to character list
function MinimapUpdater.continueToCharacterList()
  if pendingCallback then
    local callback = pendingCallback
    pendingCallback = nil
    callback()
  end
end

-- Manual commands
function MinimapUpdater.forceCheck()
  pendingCallback = function() end
  MinimapUpdater.checkForUpdates()
end

function MinimapUpdater.setEnabled(enabled)
  g_settings.set(CONFIG.enabled_key, enabled and "true" or "false")
  g_logger.info("[MinimapUpdater] " .. (enabled and "Enabled" or "Disabled"))
end

function MinimapUpdater.getStatus()
  local status = {
    enabled = g_settings.getString(CONFIG.enabled_key) == "true",
    version = g_settings.getString(CONFIG.version_key) or "none"
  }
  g_logger.info("[MinimapUpdater] Enabled: " .. tostring(status.enabled) .. ", Version: " .. status.version)
  return status
end
