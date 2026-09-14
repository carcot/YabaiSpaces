return function()
    assert(hs and hs.hotkey and hs.hotkey.disableAll, "Hammerspoon hotkey API required")
    if cycle_windows_in_space_mode then cycle_windows_in_space_mode:exit() end
    if cycle_spaces_mode then cycle_spaces_mode:exit() end
    hs.hotkey.disableAll('alt', 'f19')
    hs.hotkey.disableAll('cmd', 'l')
    hs.hotkey.disableAll('cmd', '.')
end
