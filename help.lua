help = { on = false, hasShown = false, step = 1, pages = {} }
help.nextstep = function() help.step = math.min(help.step+1, #help.pages) end

help.pages[1] = {
    advanceFunc = function()
        return player.shapeid == 5
        end,
    text = "Welcome to polyshift! Use your arrow keys to shift your shape. You can also touch the left or right halves of the screen to shift..."
}

help.pages[2] = {
    advanceFunc = function()
        return player.shapeid == 3
        end,
    text = "Good job! Now shift back to the left..."
}

help.pages[3] = {
    advanceFunc = function()
        if player.shapeid == 4 then
            state.current = "play"
            return true
        else
            return false
        end
        end,
    text = "Hey you're good at this! Next we'll play a round. A dark shape will move towards you, shift so you match this shape. Touch 'right' to begin..."
    }

help.pages[4] = {
    advanceFunc = function()
        return player.wins == 2
    end,
    text = ""
    }

help.pages[5] = {
    advanceFunc = function()
        return player.wins == 3
    end,
    text = "Nice! Try the next shape..."
    }

help.pages[6] = {
    advanceFunc = function()
        -- pause game so player can read.
        if not help.waitstep6 then
            help.waitstep6 = true
            morph(3)
            state.current = "help"
            return false
        end
        -- proceed when player morphs again
        return player.shapeid == 4
    end,
    text = "A few more and you reach the next level. Each level adds more shapes, with less time to shift. Good luck!"
    }

help.pages[7] = {
    advanceFunc = function()
        if player.shapeid == 4 then
            help.waitstep6 = false
            state.current = "play"
            help.on = false
            help.hasShown = true
            return true
        else
            return false
        end
    end,
    text = ""
    }
