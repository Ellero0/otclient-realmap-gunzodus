--[[
  Minimap Auto-Updater for OTClientV8
  Checks GitHub for updates BEFORE character list is shown

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
local updateReady = true  -- Set to false while checking
local pendingCallback = nil
local originalCharacterListShow = nil

-- Initialize module - runs early before character list
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
  if updateWindow then
    updateWindow:destroy()
    updateWindow = nil
  end
  -- Restore original function
  if originalCharacterListShow and CharacterList then
    CharacterList.show = originalCharacterListShow
  end
  g_logger.info("[MinimapUpdater] Terminated")
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

-- Check GitHub for updates
function MinimapUpdater.checkForUpdates()
  if isChecking then return end

  isChecking = true
  g_logger.info("[MinimapUpdater] Checking for updates...")

  -- Show checking window
  MinimapUpdater.showCheckingWindow()

  -- Query GitHub API for latest release
  httpOperationId = HTTP.getJSON(CONFIG.github_api, function(data, err)
    isChecking = false

    if err then
      g_logger.warning("[MinimapUpdater] Check failed: " .. tostring(err))
      MinimapUpdater.closeWindowAndContinue()
      return
    end

    if not data or not data.tag_name then
      g_logger.warning("[MinimapUpdater] Invalid GitHub response")
      MinimapUpdater.closeWindowAndContinue()
      return
    end

    local remoteVersion = data.tag_name
    local localVersion = g_settings.getString(CONFIG.version_key) or "none"
    local releaseName = data.name or remoteVersion

    g_logger.info("[MinimapUpdater] Local: " .. localVersion .. ", Remote: " .. remoteVersion)

    -- Find download URL
    local downloadUrl = nil
    if data.assets then
      for _, asset in ipairs(data.assets) do
        if asset.name == CONFIG.minimap_file then
          downloadUrl = asset.browser_download_url
          break
        end
      end
    end

    if not downloadUrl then
      downloadUrl = "https://github.com/Ellero0/otclient-realmap-gunzodus/releases/latest/download/" .. CONFIG.minimap_file
    end

    if remoteVersion ~= localVersion then
      MinimapUpdater.showUpdateDialog(remoteVersion, localVersion, releaseName, downloadUrl)
    else
      g_logger.info("[MinimapUpdater] Minimap is up to date")
      MinimapUpdater.closeWindowAndContinue()
    end
  end)
end

-- Show "Checking for updates" window
function MinimapUpdater.showCheckingWindow()
  if updateWindow then
    updateWindow:destroy()
  end

  updateWindow = g_ui.createWidget('MainWindow', rootWidget)
  updateWindow:setId('minimapUpdateWindow')
  updateWindow:setText('Minimap Updater')
  updateWindow:setSize({width = 300, height = 100})
  updateWindow:center()

  local label = g_ui.createWidget('Label', updateWindow)
  label:setId('statusLabel')
  label:setText('Checking for minimap updates...')
  label:setTextAlign(AlignCenter)
  label:addAnchor(AnchorTop, 'parent', AnchorTop)
  label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  label:addAnchor(AnchorRight, 'parent', AnchorRight)
  label:setMarginTop(30)
end

-- Show update available dialog
function MinimapUpdater.showUpdateDialog(newVersion, oldVersion, releaseName, downloadUrl)
  if updateWindow then
    updateWindow:destroy()
    updateWindow = nil
  end

  local message = string.format(
    "New minimap update available!\n\n" ..
    "Current: %s\n" ..
    "New: %s (%s)\n\n" ..
    "Download now?",
    oldVersion == "none" and "Not installed" or oldVersion,
    newVersion,
    releaseName
  )

  local msgBox = displayGeneralBox(
    "Minimap Update",
    message,
    {
      { text = "Yes, Update", callback = function()
        MinimapUpdater.downloadUpdate(downloadUrl, newVersion)
      end},
      { text = "No, Skip", callback = function()
        g_logger.info("[MinimapUpdater] Update skipped by user")
        MinimapUpdater.continueToCharacterList()
      end},
      { text = "Disable Updates", callback = function()
        g_settings.set(CONFIG.enabled_key, "false")
        g_logger.info("[MinimapUpdater] Auto-update disabled")
        MinimapUpdater.continueToCharacterList()
      end}
    },
    nil, nil, nil
  )
end

-- Download and install update
function MinimapUpdater.downloadUpdate(downloadUrl, newVersion)
  g_logger.info("[MinimapUpdater] Downloading: " .. downloadUrl)
  isDownloading = true

  -- Create progress window
  updateWindow = g_ui.createWidget('MainWindow', rootWidget)
  updateWindow:setId('minimapDownloadWindow')
  updateWindow:setText('Downloading Minimap')
  updateWindow:setSize({width = 350, height = 130})
  updateWindow:center()

  local label = g_ui.createWidget('Label', updateWindow)
  label:setId('statusLabel')
  label:setText('Downloading minimap update...')
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
  progressBar:setMarginTop(15)
  progressBar:setMarginLeft(20)
  progressBar:setMarginRight(20)
  progressBar:setHeight(20)

  local speedLabel = g_ui.createWidget('Label', updateWindow)
  speedLabel:setId('speedLabel')
  speedLabel:setText('')
  speedLabel:setTextAlign(AlignCenter)
  speedLabel:addAnchor(AnchorTop, 'progressBar', AnchorBottom)
  speedLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  speedLabel:addAnchor(AnchorRight, 'parent', AnchorRight)
  speedLabel:setMarginTop(5)

  -- Download the file
  httpOperationId = HTTP.download(downloadUrl, CONFIG.minimap_file,
    function(path, checksum, err)
      isDownloading = false

      if updateWindow then
        updateWindow:destroy()
        updateWindow = nil
      end

      if err then
        g_logger.error("[MinimapUpdater] Download failed: " .. tostring(err))
        displayErrorBox("Download Failed", "Failed to download minimap:\n" .. tostring(err)).onOk = function()
          MinimapUpdater.continueToCharacterList()
        end
        return
      end

      g_logger.info("[MinimapUpdater] Download complete!")

      -- Save version
      g_settings.set(CONFIG.version_key, newVersion)

      -- Show success and continue
      displayInfoBox("Update Complete",
        "Minimap updated to " .. newVersion .. "!\n\n" ..
        "File saved to downloads folder.\n" ..
        "Copy to your minimap folder if needed."
      ).onOk = function()
        MinimapUpdater.continueToCharacterList()
      end
    end,
    function(progress, speed)
      if updateWindow then
        local progressBar = updateWindow:getChildById('progressBar')
        local statusLabel = updateWindow:getChildById('statusLabel')
        local speedLabel = updateWindow:getChildById('speedLabel')
        if progressBar then
          progressBar:setPercent(progress)
        end
        if statusLabel then
          statusLabel:setText(string.format('Downloading... %d%%', progress))
        end
        if speedLabel then
          speedLabel:setText(speed .. ' KB/s')
        end
      end
    end
  )
end

-- Close window and continue to character list
function MinimapUpdater.closeWindowAndContinue()
  if updateWindow then
    updateWindow:destroy()
    updateWindow = nil
  end
  MinimapUpdater.continueToCharacterList()
end

-- Continue to show character list
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
