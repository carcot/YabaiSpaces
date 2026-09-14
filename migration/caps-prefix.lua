return function()
    assert(rightcmdf19, "Window-management prefix must be initialized")
    local timer
    capsPrefixHotkey = hs.hotkey.bind({}, 'f20', function()
        if timer then timer:stop() end
        rightcmdf19:enter()
        timer = hs.timer.doAfter(3, function()
            rightcmdf19:exit()
            timer = nil
        end)
    end)
end
