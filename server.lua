local trains = {}

local function __deleteTrainVehicle(vehicle)
    destroyElement(vehicle)
end

function deleteCustomTrain(trainOrOwner)
    if getElementType(trainOrOwner) == 'vehicle' then
        __deleteTrainVehicle(trainOrOwner)
    else
        local train = trains[trainOrOwner]
        if train then
            __deleteTrainVehicle(train)
            trains[trainOrOwner] = nil
        end
    end
end

function createCustomTrain(model, owner, x, y, z)
    local vehicle = createVehicle(model, x, y, z)
    setTrainDerailed(vehicle, true)
    setElementPosition(vehicle, x, y, z)

    setElementData(vehicle, 'btrain:owner', owner)
    setElementSyncer(vehicle, owner)
    triggerClientEvent(owner, 'btrain:trainCreated', resourceRoot, vehicle)

    trains[owner] = vehicle

    return vehicle
end

local function calculateTrackPosition(train)
    local trackId = getElementData(train, 'btrain:track')
    local trackPosition = getElementData(train, 'btrain:trackPosition') or 0
    local currentTrackId = getElementData(train, 'btrain:currentTrack')

    local track = trainTracks[trackId]
    if not track then return end

    local currentTrack = Vector3(unpack(track[currentTrackId]))
    local nextTrack = Vector3(unpack(track[currentTrackId + 1] or track[1]))
    local position = currentTrack + (nextTrack - currentTrack) * trackPosition
    local length = (currentTrack - nextTrack):getLength()

    local trainTick = getElementData(train, 'btrain:trackTick')
    local tick = getTickCount()
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
    end

    setElementData(train, 'btrain:trackPosition', newPosition)
    setElementData(train, 'btrain:currentTrack', currentTrackId)
    setElementData(train, 'btrain:trackTick', tick)
end

function setTrainTrack(train, track)
    setElementData(train, 'btrain:track', track)
    setElementData(train, 'btrain:trackPosition', 0)
    setElementData(train, 'btrain:currentTrack', 1)
    setElementData(train, 'btrain:trackTick', getTickCount())
end

function setTrainSpeed(train, speed)
    setElementData(train, 'btrain:speed', speed)
    calculateTrackPosition(train)
end

addEvent('btrain:requestTick', true)
addEventHandler('btrain:requestTick', resourceRoot, function()
    triggerClientEvent(client, 'btrain:tick', resourceRoot, getTickCount())
end)

addEvent('btrain:calculateTrackPosition', true)
addEventHandler('btrain:calculateTrackPosition', resourceRoot, function()
    local train = trains[client]
    if not train then return end

    calculateTrackPosition(train)
end)

addEventHandler('onPlayerQuit', root, function()
    local train = trains[source]
    if train then
        deleteCustomTrain(train)
    end
end)