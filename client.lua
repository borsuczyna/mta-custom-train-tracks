local serverTick = nil
local lastUpdate = 0

local function updateServerTick()
    if not serverTick then return end
    
    local current = getTickCount()
    local diff = current - serverTick.startClient
    serverTick.current = serverTick.startServer + diff
end

local function findRotation3D(a, b) -- takes 2 vector3, returns vector3 euler rotation, z is up vector
    local offX = b.x - a.x
    local offY = b.y - a.y
    local offZ = b.z - a.z

    local distanceXY = math.sqrt(offX * offX + offY * offY)
    local pitch = math.atan2(offZ, distanceXY)
    local yaw = math.atan2(offY, offX)

    pitch = pitch * (180 / math.pi)
    yaw = yaw * (180 / math.pi)

    return Vector3(pitch, 0, yaw - 90)
end

local function calculateTrackPosition(train, offset)
    local trackId = getElementData(train, 'btrain:track')
    local trackPosition = getElementData(train, 'btrain:trackPosition') or 0
    local currentTrackId = getElementData(train, 'btrain:currentTrack')
    local owner = getElementData(train, 'btrain:owner')

    local track = trainTracks[trackId]
    if not track then return end

    local currentTrack = Vector3(unpack(track[currentTrackId]))
    local nextTrack = Vector3(unpack(track[currentTrackId + 1] or track[1]))
    local length = (currentTrack - nextTrack):getLength()
    trackPosition = trackPosition + offset / length

    local position = currentTrack + (nextTrack - currentTrack) * trackPosition

    local trainTick = getElementData(train, 'btrain:trackTick')
    local tick = serverTick.current
    local elapsed = tick - trainTick

    local speed = getElementData(train, 'btrain:speed')
    local driven = speed * elapsed / 10

    local newPosition = trackPosition + driven / length

    if newPosition >= 1 then
        newPosition = newPosition - 1
        currentTrackId = currentTrackId + 1
        if currentTrackId > #track then
            currentTrackId = 1
        end

        local nlength = (Vector3(unpack(track[currentTrackId])) - Vector3(unpack(track[currentTrackId + 1] or track[1]))):getLength()
        newPosition = newPosition * length / nlength

        if offset == 0 and owner == localPlayer then
            setElementData(train, 'btrain:currentTrack', currentTrackId)
            setElementData(train, 'btrain:trackPosition', newPosition)
            setElementData(train, 'btrain:trackTick', serverTick.current)
        end
    end

    return newPosition, currentTrackId
end

local function getTrackPosition(train, offset)
    local position, currentTrackId = calculateTrackPosition(train, offset)

    local trackId = getElementData(train, 'btrain:track')
    local track = trainTracks[trackId]
    local currentTrack = Vector3(unpack(track[currentTrackId]))
    local nextTrack = Vector3(unpack(track[currentTrackId + 1] or track[1]))
    local position = currentTrack + (nextTrack - currentTrack) * position
    
    return position
end

local function updateCustomTrain(train)
    local trackId = getElementData(train, 'btrain:track')
    if not trackId then return end

    local model = getElementModel(train)
    local backPosition = getTrackPosition(train, 0)
    local frontPosition = getTrackPosition(train, (trainData[model] and trainData[model].size or 5))
    local position = (backPosition + frontPosition) / 2
    local rotation = findRotation3D(backPosition, frontPosition)

    setElementPosition(train, position + Vector3(0, 0, (trainData[model] and trainData[model].height or 0.5)))
    setElementRotation(train, rotation.x, rotation.y, rotation.z)
    setElementFrozen(train, true)

    if DRAW_DEBUG then
        dxDrawLine3D(position.x, position.y, position.z + 8, position.x, position.y, position.z, tocolor(255, 0, 0), 4)
        dxDrawLine3D(frontPosition.x, frontPosition.y, frontPosition.z + 8, frontPosition.x, frontPosition.y, frontPosition.z, tocolor(0, 255, 0), 4)
        dxDrawLine3D(backPosition.x, backPosition.y, backPosition.z + 8, backPosition.x, backPosition.y, backPosition.z, tocolor(0, 0, 255), 4)
    end

    local function updatePosition()
        local position, currentTrackId = calculateTrackPosition(train, 0)
        setElementData(train, 'btrain:trackPosition', position)
        setElementData(train, 'btrain:currentTrack', currentTrackId)
        setElementData(train, 'btrain:trackTick', serverTick.current)
    end

    local owner = getElementData(train, 'btrain:owner')
    if owner == localPlayer and lastUpdate + 100 < getTickCount() then
        if getKeyState('w') then
            local speed = getElementData(train, 'btrain:speed') or 0

            local maxSpeed = trainData[model] and trainData[model].maxSpeed or 0.2
            local acceleration = trainData[model] and trainData[model].acceleration or 0.002
            speed = math.min(maxSpeed, speed + acceleration)

            setElementData(train, 'btrain:speed', speed)
            lastUpdate = getTickCount()
            updatePosition()
        elseif getKeyState('s') then
            local speed = getElementData(train, 'btrain:speed') or 0

            local braking = trainData[model] and trainData[model].braking or 0.003
            speed = math.max(0, speed - braking)

            setElementData(train, 'btrain:speed', speed)
            lastUpdate = getTickCount()
            updatePosition()
        end        
    end
end

local function drawCustomTrainDebug(train)
    local x, y, z = getElementPosition(train)
    local trackId = getElementData(train, 'btrain:track')
    local owner = getElementData(train, 'btrain:owner')
    local currentTrackId = getElementData(train, 'btrain:currentTrack')
    local trackPosition = getElementData(train, 'btrain:trackPosition')
    local speed = getElementData(train, 'btrain:speed')
    
    local text = 'Train: ' .. getPlayerName(owner) .. '\n'
    if trackId then
        text = text .. 'Track: ' .. trackId .. '\n'
    end
    if currentTrackId then
        text = text .. 'Current track: ' .. currentTrackId .. '\n'
    end
    if trackPosition then
        text = text .. 'Track position: ' .. trackPosition .. '\n'
    end
    if speed then
        text = text .. 'Speed: ' .. speed .. '\n'
    end

    x, y = getScreenFromWorldPosition(x, y, z)
    if x and y then
        dxDrawText(text, x, y, x, y, tocolor(255, 255, 255), 1, 'default-bold', 'center', 'center')
    end
end

local function updateTrains()
    if not serverTick then return end

    updateServerTick()

    if DRAW_DEBUG then
        for i, track in ipairs(trainTracks) do
            for j, point in ipairs(track) do
                local x, y, z = unpack(point)
                local x2, y2, z2 = unpack(track[j + 1] or track[1])
                dxDrawLine3D(x, y, z, x2, y2, z2, tocolor(255, 0, 0), 2)
            end
        end
    end

    local trains = getElementsByType('vehicle', true)
    for i, train in ipairs(trains) do
        if getElementData(train, 'btrain:owner') then
            updateCustomTrain(train)

            if DRAW_DEBUG then drawCustomTrainDebug(train) end
        end
    end
end

addEvent('btrain:trainCreated', true)
addEventHandler('btrain:trainCreated', resourceRoot, function(train)
    setCameraTarget(train)
end)

addEvent('btrain:tick', true)
addEventHandler('btrain:tick', resourceRoot, function(tick)
    serverTick = {
        startServer = tick,
        current = tick,
        startClient = getTickCount()
    }
end)

triggerServerEvent('btrain:requestTick', resourceRoot)
addEventHandler("onClientRender", root, updateTrains)