require("helpers")
shapes = require("shapes")
require("help")

-- Ego
player = nil

-- The target zooms in from the background to reveal what shape you must choose next
target = nil

-- The fadeshape is a shadow-like copy of the target that fades out of view
fadeshape = nil

-- The text shape overlays large words on the play area
textshape = nil

-- Manages game states
state = {
    current = nil,
    next = nil,
    timeout = nil
    }

-- Game config
config = {
    version = "1",
    debug = false,
    sparkleOnRotation = false,
    targetTestBegin = 1.5,
    targetTestEnd = 2.0,
    titleHue = 0,
    autoShiftTimeout = 3,
    wonCooldown = 0
}

-- Define the level progression
levels = {}
levels[1] = {maxShapeID = 5, targetSpeed = 0.2, nextLevelIn = 5}
levels[2] = {maxShapeID = 6, targetSpeed = 0.3, nextLevelIn = 10}
levels[3] = {maxShapeID = 7, targetSpeed = 0.6, nextLevelIn = 15}
levels[4] = {maxShapeID = 8, targetSpeed = 0.8, nextLevelIn = 20}
levels[5] = {maxShapeID = 9, targetSpeed = 1.0, nextLevelIn = 25}
levels[6] = {maxShapeID = 10, targetSpeed = 1.2, nextLevelIn = 30}
levels[7] = {maxShapeID = 11, targetSpeed = 1.4, nextLevelIn = 35}


function love.load ()
    
    -- seed
    love.math.setRandomSeed(os.time())
    
    -- dimensions
    scrWidth, scrHeight = love.graphics.getDimensions()
    cenX, cenY = scrWidth * 0.5, scrHeight * 0.5
    
    -- fonts
    defaultFont = love.graphics.getFont()
    bigFont = love.graphics.newFont("FontdinerSwanky.ttf", 60)
    smallFont = love.graphics.newFont("FontdinerSwanky.ttf", 20)
    
    -- logo
    loveLogo = love.graphics.newImage("love-app-0.10.png")
    
    -- colors
    love.graphics.setBackgroundColor({64, 92, 128})
    config.titleHue = love.math.random(0, 255)
    
    -- sounds
    winSound = love.audio.newSource("win.wav", "static")
    lossSound = love.audio.newSource("loss.wav", "static")
    musicSource = love.audio.newSource("polyshift.ogg", "stream")
    musicSource:setLooping(true)
    musicSource:setVolume(0.5)
    love.audio.play(musicSource)
    
    -- reset
    resetGame()
end


function love.resize(w, h)
    scrWidth, scrHeight = w, h
    cenX, cenY = scrWidth * 0.5, scrHeight * 0.5
end


function love.draw ()
    
    if state.current == "play" then
        drawTargetShape()
        drawFadeShape()
        drawPlayerStats()
        drawShapeGuide()
    elseif state.current == "intro" then
        drawTitle()
    elseif state.current == "won" then
        -- allow fadeouts after won
        drawFadeShape()
        drawWonScreen()
        drawPlayerStats()
    elseif state.current == "paused" then
        drawPaused()
    elseif state.current == "help" then
        drawShapeGuide()
    end
    
    drawPlayerShape()
    drawTextShape()
    drawHelp()    
    
    if config.debug then
        love.graphics.setBlendMode("alpha")
        love.graphics.setFont(defaultFont)
        love.graphics.setColor({255, 255, 0, 128})
        love.graphics.print(love.timer.getFPS() .. " fps", 10, 10)
        love.graphics.print("shape " .. player.shapeid, 10, 20)
        love.graphics.print("wins " .. player.wins, 10, 30)
        love.graphics.print("losses " .. player.losses, 10, 40)
        love.graphics.print("direction counter " .. player.directionCounter, 10, 50)
        love.graphics.setFont(bigFont)
        love.graphics.print("DEBUG", 10, scrHeight - 120)
    end
end


function love.update (dt)
    if state.current == "play" then
        updateTargetShape(dt)
        updateFadeShape(dt)
        testMatchCondition()
    elseif state.current == "intro" then
        config.titleHue = (config.titleHue + dt * 42) % 255
    elseif state.current == "won" then
        -- allow updating fadeouts after won
        config.wonCooldown = config.wonCooldown - dt
        updateFadeShape(dt)
        config.titleHue = (config.titleHue + dt * 42) % 255
        config.autoShiftTimeout = config.autoShiftTimeout - dt
        if config.autoShiftTimeout < 0 then
            config.autoShiftTimeout = 3
            if player.shapeid == #shapes then
                morph(3)
            else
                morph(player.shapeid+1)
            end
        end
    end
    updateTextShape(dt)
    updatePlayerShape(dt)
    
    -- update help
    if help.on then
        if help.pages[help.step].advanceFunc() then
            help.nextstep()
        end
    end
end


function love.keypressed (key)
    
    skipIntroOrEndScreen()
    
    -- quit on q while paused
    if state.current == "paused" then
        if key == "q" then
            love.event.quit()
        else
            state.current = state.previous
            love.audio.play(musicSource)
        end
    end
    
    if key == "escape" then
        if state.current ~= "paused" then
            state.previous = state.current
            state.current = "paused"
            love.audio.pause(musicSource)
        end
    elseif key == "z" or key == "left" then
        player.directionCounter = player.directionCounter - 1
        morph(player.shapeid - 1)
    elseif key == "x" or key == "right" then
        player.directionCounter = player.directionCounter + 1
        morph(player.shapeid + 1)
    end
    if config.debug then
        if key == "r" then resetGame() end
        if key == "n" then 
            help.on = false
            state.current = "play"
            gotoNextLevel(true)
            end
    end
end


function love.mousepressed (x, y, button, istouch)
    skipIntroOrEndScreen()
    if x < cenY then
        player.directionCounter = player.directionCounter - 1
        morph(player.shapeid - 1)
    else
        player.directionCounter = player.directionCounter + 1
        morph(player.shapeid + 1)
    end
end


function skipIntroOrEndScreen ()
    
    if state.current == "intro" then
        if help.hasShown then
            state.current = "play"
        else
            state.current = "help"
            help.on = true
        end
    elseif state.current == "won" then
        if config.wonCooldown < 0 then
            resetGame()
        end
    end

end


function resetGame ()
    
    config.wonCooldown = 10
    state.current = "intro"
    state.next = "play"
    state.timeout = nil
    
    player = { 
        shapeid = 3, 
        angle = 0, 
        scale = 1, 
        wiggler = 0, 
        level = 1, 
        wins = 0,
        losses = 0,
        winrate = 0,
        directionCounter = 0,
        nextLevelIn = levels[1].nextLevelIn,
        shape = shallowcopy(shapes[3])
        }
    target = { 
        shapeid = 3, 
        angle = 0, 
        scale = 0.1,
        shape = shallowcopy(shapes[3])
        }
end


function morph (index)
    
    -- wrap around
    if index == 2 then
        index = levels[player.level].maxShapeID
    elseif index > levels[player.level].maxShapeID then
        index = 3
    end
    
    -- invalid selection
    if not shapes[index] then return end
    
    -- level boundary
    if index > levels[player.level].maxShapeID then return end
    
    -- count our eggs
    local hasPoints = #player.shape
    local needPoints = #shapes[index]
    
    -- our goal
    player.shapeid = index
    
    -- insert additional points
    while #player.shape < needPoints do
        table.insert(player.shape, player.shape[hasPoints-1])
        table.insert(player.shape, player.shape[hasPoints])
    end
    
    -- remove superfluous points
    while #player.shape > needPoints do
        table.remove(player.shape)
    end
    
end


-- Transform the player shape vertices to match the template shapes
function updatePlayerShape (dt)
    
    -- rotate 10 degrees each second
    if state.current == "play" then
        player.angle = (player.angle + dt * 30 * player.level) % 360
    else
        -- slow rotation for non-play states
        player.angle = (player.angle + dt * 30) % 360
    end
    
    player.wiggler = (player.wiggler + dt) % 360
    
    for i, p in ipairs(player.shape) do
        local diff = shapes[player.shapeid][i] - p
        -- limit vertex movement to nearest as possible without overlap
        if math.abs(diff) > 0.1 then
            player.shape[i] = p + diff * dt * math.max(player.level, 4)
        end
    end
end


function drawPlayerShape ()
    love.graphics.push()
    love.graphics.setColor({32, 192, 255, 255})
    love.graphics.setLineWidth(8)
    love.graphics.setBlendMode("add")
    love.graphics.translate(cenX, cenY)
    love.graphics.rotate(math.rad(player.angle))
    love.graphics.polygon("line", player.shape)
    love.graphics.setLineWidth(4)
    love.graphics.setBlendMode("multiply")
    love.graphics.polygon("line", player.shape)
    sparkleshape(player.shape)
    love.graphics.pop()
end


-- draws a shape and wiggle the points
function sparkleshape (shape)
    if config.sparkleOnRotation then
        shape = shallowcopy(shape)
        for i=1, #shape, 2 do
            local x = shape[i]
            local y = shape[i+1]
            shape[i] = x + math.sin(i + player.wiggler) * 0.5
            shape[i+1] = y + math.sin(i + player.wiggler) * 0.5
        end
        love.graphics.setLineWidth(1)
        love.graphics.setBlendMode("add")
        love.graphics.polygon("line", shape)
    end
end


function updateTargetShape (dt)
    target.angle = (target.angle - dt * 10 * player.level) % 360
    target.scale = target.scale + levels[player.level].targetSpeed * dt
end


function drawTargetShape ()
    love.graphics.push()
    love.graphics.setColor({0, 0, 0, 128})
    love.graphics.setLineWidth(20)
    love.graphics.setBlendMode("alpha")
    love.graphics.translate(cenX, cenY)
    love.graphics.scale(target.scale)
    love.graphics.rotate(math.rad(target.angle))
    love.graphics.polygon("line", target.shape)
    -- highlight when in the match zone
    if target.scale > config.targetTestBegin then
        love.graphics.setLineWidth(10)
        love.graphics.setColor({255, 255, 0, 64})
        love.graphics.circle("line", 0, 0, 30 * target.scale)
    end
    love.graphics.pop()
end


function testMatchCondition ()
    -- When the target is in the scale range for matching
    if target.scale > config.targetTestBegin and target.scale < config.targetTestEnd then
        -- A Win!
        if target.shapeid == player.shapeid then
            fadeshape = shallowcopy(target)
            fadeshape.alpha = 128
            fadeshape.tint = {r=255, g=255, b=255}
            gotoNextTarget()
            addWin()
        end
    elseif target.scale > config.targetTestEnd then
        -- The target passed by without a successful match :(
        addLoss()
        fadeshape = shallowcopy(target)
        fadeshape.alpha = 128
        fadeshape.tint = {r=255, g=0, b=0}
        gotoNextTarget() 
    end
end


function addWin ()
    player.nextLevelIn = player.nextLevelIn - 1
    player.wins = player.wins + 1
    player.winrate = player.wins / (player.wins + player.losses) * 100
    showtext("+1", {0, 255, 128, 255})
    gotoNextLevel()
    if help.on then
        help.nextstep()
    end
    love.audio.play(winSound)
end


function addLoss ()
    player.losses = player.losses + 1
    player.winrate = player.wins / (player.wins + player.losses) * 100
    if help.on then
        showtext("Whoops, try again.", {255, 128, 0, 255})
    else
        showtext("-1", {255, 128, 0, 255})
    end
    love.audio.play(lossSound)
end


function gotoNextLevel (forced)
    if forced or player.nextLevelIn == 0 then
        if player.level == #levels then
            state.current = "won"
            showtext("Game Complete!", {128, 255, 128, 255})
            assignRank()
        else
            player.level = player.level + 1
            player.nextLevelIn = levels[player.level].nextLevelIn
            showtext("LEVEL " .. player.level, {0, 128, 255, 255})
        end
    end
end


function gotoNextTarget ()
    local nextMaxID = math.min(#shapes, levels[player.level].maxShapeID)
    target.shapeid = love.math.random(3, nextMaxID)
    target.shape = shallowcopy(shapes[target.shapeid])
    target.scale = 0.1
end


function updateFadeShape (dt)
    if fadeshape then
        fadeshape.angle = (fadeshape.angle + dt * 100) % 360
        fadeshape.scale = fadeshape.scale + 3 * dt
        fadeshape.alpha = math.min(255, fadeshape.alpha - dt * 255)
        if fadeshape.scale > config.targetTestEnd * 2 then
            fadeshape = nil
        end
    end
end


function drawFadeShape ()
    if fadeshape then
        love.graphics.push()
        love.graphics.setColor({fadeshape.tint.r, fadeshape.tint.g, fadeshape.tint.b, fadeshape.alpha})
        love.graphics.setLineWidth(20)
        love.graphics.setBlendMode("alpha")
        love.graphics.translate(cenX, cenY)
        love.graphics.scale(fadeshape.scale)
        love.graphics.rotate(math.rad(fadeshape.angle))
        love.graphics.polygon("line", fadeshape.shape)
        love.graphics.pop()
    end
end


function updateTextShape (dt)
    if textshape then
        textshape.angle = (textshape.angle + dt * 2) % 360
        textshape.scale = textshape.scale - dt * 0.1
        textshape.life = textshape.life - dt
        if textshape.life < 0 then
            textshape = nil
        end
    end
end


function drawTextShape ()
    if textshape then
        love.graphics.push()
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(textshape.color)
        love.graphics.scale(textshape.scale)
        love.graphics.rotate(math.rad(textshape.angle))
        love.graphics.setFont(bigFont)
        love.graphics.printf(textshape.text, 0, 10, scrWidth, "center")
        love.graphics.pop()
    end
end


function drawTitle ()
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(bigFont)
    -- shadow
    love.graphics.setColor(HSV(config.titleHue, 128, 128))
    love.graphics.printf("polyshift", 2, cenY+2, scrWidth, "center")
    -- title
    love.graphics.setColor(HSV(config.titleHue, 192, 192))
    love.graphics.printf("polyshift", 0, cenY, scrWidth, "center")
    -- Credit
    love.graphics.setFont(smallFont)
    love.graphics.setColor(HSV(config.titleHue, 255, 164))
    -- Version
    love.graphics.printf("version " .. config.version, 0, cenY + 100, scrWidth, "center")
    love.graphics.printf("Created by Wesley \"keyboard monkey\" for Ludum Dare 35", 
        0, cenY + 140, scrWidth, "center")
    -- Logo
    love.graphics.setColor({255, 255, 255, 128})
    love.graphics.draw(loveLogo, 30, scrHeight - 160, 0, 0.6, 0.6)
end


function showtext (text, color)
    textshape = { 
        text = text,
        color = color,
        angle = 0,
        scale = 1.5,
        life = 5
        }
end


function drawHelp ()

    if help.on then
        
        love.graphics.setBlendMode("alpha")
        love.graphics.setFont(smallFont)
        love.graphics.setColor({192, 192, 255, 255})
        love.graphics.printf(help.pages[help.step].text, 0, 10, scrWidth, "center")
        
    end
    
end


function drawPlayerStats ()
    
    local y = scrHeight - 40
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(smallFont)
    love.graphics.setColor({192, 192, 255, 255})
    love.graphics.print("Level " .. player.level, 10, y)
    love.graphics.print(
        string.format("Skill %d%%", player.winrate), 110, y)
    love.graphics.print("Remain " .. player.nextLevelIn, 240, y)
    
end


function drawWonScreen ()
    
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(smallFont)
    love.graphics.setColor({192, 192, 255, 255})
    
    local victory = string.format("You matched %d shapes, you missed %d shapes, your skill is %d%%", player.wins, player.losses, player.winrate)
    
    love.graphics.printf(victory, 0, 20, scrWidth, "center")
    love.graphics.printf("Your rank is", 0, 100, scrWidth, "center")
    
    -- shadow
    love.graphics.setFont(bigFont)
    love.graphics.setColor(HSV(config.titleHue, 128, 128))
    love.graphics.printf(player.rank, 2, 142, scrWidth, "center")
    -- ranking
    love.graphics.setColor(HSV(config.titleHue, 192, 192))
    love.graphics.printf(player.rank, 0, 140, scrWidth, "center")
    
    if config.wonCooldown < 0 then
        love.graphics.setFont(smallFont)
        love.graphics.setColor({255, 192, 255, 255})
        love.graphics.printf("Touch to replay", 0, scrHeight - 100, scrWidth, "center")
    end
    
end


function drawPaused ()
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(bigFont)
    love.graphics.setColor({128, 255, 255, 255})
    love.graphics.printf("PAUSED", 0, scrHeight - 200, scrWidth, "center")
    love.graphics.setFont(smallFont)
    love.graphics.printf("Press Q to quit", 0, scrHeight - 60, scrWidth, "center")
end


function drawShapeGuide ()
    
    -- show for level 1, or level 3 onwards if the p
    --if player.level == 1 or (player.level > 2 and player.winrate < 50) then
    if true then
        
        love.graphics.setBlendMode("alpha")
        love.graphics.setLineWidth(1)
        love.graphics.push()
        
        -- bottom corner
        love.graphics.translate(scrWidth - 20, scrHeight - 20)
        
        -- very small
        love.graphics.scale(0.2)
        
        -- each available shape
        for i=3, levels[player.level].maxShapeID, 1 do
            local x = (levels[player.level].maxShapeID - i) * 200
            love.graphics.setColor({255, 255, 255, 32})
            love.graphics.push()
            love.graphics.translate(-x, 0)
            -- hilight
            if i == player.shapeid then
                love.graphics.setColor({255, 255, 0, 128})
            end
            love.graphics.polygon("line", shapes[i])
            love.graphics.pop()
        end
        love.graphics.pop()
    end
end



function assignRank ()
    
    local rankings = {
        "Mooch",
        "Sloth",
        "Soft-tapper",
        "Slowpoke",
        "Old Toothpaste",
        "Slimey Slug",
        "Dry Cabbage",
        "Sleeping Shifter",
        "Try Again, Sir/Madam",
        "Snorez",
        
        "The Normalizer",
        "The 2.5th Child",
        "Room for Improvement",
        "Data Capturer",
        "Novice Tapper",
        "Eat Your Vegetables",
        "Wildcat",
        "Crooked Fingers",
        "Cherry-Cherry-Bomb",
        "No Cigar",

        "Professional",
        "Your Excellency",
        "Ninja",
        "Master of the Shape",
        "Neo",
        "Wizard of Shift",
        "Touch Sensation",
        "Hummingbird",
        "Greased Lightning",
        "Lucky Charm",
        "Superioso",

    }
    
    if player.winrate < 33 then
        player.rank = rankings[math.random(1, 10)]
    elseif player.winrate < 66 then
        player.rank = rankings[math.random(11, 20)]
    else
        player.rank = rankings[math.random(21, 31)]
    end
    
    if math.abs(player.directionCounter) > 200 then
        player.rank = "cheater"
    end

        
end
