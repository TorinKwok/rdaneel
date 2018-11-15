local rdaneel = {
    VERSION = '0.1',
    _constants = {},
    _pri = {
        --  Workaround to Lua's nature that it's not possible to create
        --  constants
        protect = function ( tbl )
            return setmetatable( {}, {
                    __index = tbl,
                    __newindex = function( t, k, v )
                        error( "attempting to change constant " 
                                   .. tostring( k ) .. " to " .. tostring( v ), 2 )
                    end
            } )
        end,
    }
}

rdaneel._constants = { slotsNum = 16, }
rdaneel._constants = rdaneel._pri.protect( rdaneel._constants )

function turtle:goup( destroy )
    if self and turtle.detectUp() then
        turtle.digUp()
    end
    turtle.up()
end

function turtle:godn( destroy )
    if self and turtle.detectDown() then
        turtle.digDown()
    end
    turtle.down()
end

function turtle:gofd( destroy )
    if self and turtle.detect() then
        turtle.dig()
    end
    turtle.forward()
end

-- rdaneel:selectItem() selects the inventory slot with the names item,
-- returns `true` if found and `false` if not

function rdaneel:selectItem( name )
    local currentSlot = turtle.getItemDetail( turtle.getSelectedSlot() )

    if currentSlot and currentSlot['name'] == name then
        return true
    end

    -- check all inventory slots

    local item = nil

    for slot = 1, rdaneel._constants.slotsNum do
        item = turtle.getItemDetail( slot )
        if item and item['name'] == name then
            return turtle.select( slot )
        end
    end

    return false -- couldn't find item
end

-- rdaneel:selectEmptySlot() selects inventory slot that is empty,
-- returns `true` if found, `false` if no empty spaces

function rdaneel:selectEmptySlot()
    if turtle.getItemCount( turtle.getSelectedSlot() ) == 0 then
        return true
    end

    -- loop through all slots
    for slot = 1, rdaneel._constants.slotsNum do
        if turtle.getItemSpace( slot ) == 64 then
            turtle.select( slot )
            return true
        end
    end

    return false -- couldn't find empty space
end

-- rdaneel:countInventory() returns the total number of items in the
-- inventory

function rdaneel:countInventory()
    local total = 0

    for slot = 1, rdaneel._constants.slotsNum do
        total = total + turtle.getItemCount( slot )
    end

    return total
end

-- selectAndPlaceDown() selects a nonempty slot and places a
-- block from it under the turtle

function rdaneel:selectAndPlaceDown( destroy )
    for slot = 1, rdaneel._constants.slotsNum do
        if turtle.getItemCount( slot ) > 0 then

            turtle.select( slot )

            local needToPlace = true
            local exists, details = turtle.inspectDown()

            if exists and destroy then
                if details.name == turtle.getItemDetail( turtle.getSelectedSlot() ).name then
                    needToPlace = false
                else
                    turtle.digDown()
                end
            elseif exists and not destroy then
                needToPlace = false
            end

            if needToPlace then
                turtle.placeDown()
            end

            return true
        end
    end

    return false
end

function rdaneel:sweepField( length, width, sweepCallback )

    local minimum = length * width

    if turtle.getFuelLevel() < minimum then
        return false, 'HAVE NO ENOUGH FUEL'
    -- elseif rdaneel:countInventory() < minimum then
    --     return false, 'HAVE NO ENOUGH BLOCKS'
    end

    turtle.goup( true )

    local roundIdx = 0 -- Yes, we count the number of rounds from zero

    -- Instead of using an infinite loop, I'm waiting for a brief
    -- but elegant mathematical proof that is able to help us
    -- figure out in advance how exactly many rounds the turtle
    -- should move

    while true do
        local paths = nil

        if roundIdx == 0 then
            paths = { width - 1, length - 1, width - 1, length - 2 }
        else
            local evenDelta = roundIdx * 2
            local oddDelta = evenDelta + 1

            --[[
                               right >
                         +-----------------+
                         | ^ ------------> |
                         | | ^ --------> | |
                         | | | + + + + | | |
                   ^     | | | + + + + | | |  back
                forward  | | | ^ + + + | | |   v
                         | | | | + + + | | |
                         | | | | <-----v | |
                         | O <-----------v |
                         +-----------------+
                               < left
            ]]

            paths = {
                [1] = width  - evenDelta,        -- forward
                [2] = length - oddDelta,         -- right
                [3] = width  - oddDelta,         -- back
                [4] = length - ( evenDelta + 2 ) -- left
            }
        end

        -- Mark `done` as true in order to get rid of the nested
        -- loop.  Lua does not support goto-style statement until
        -- 5.2.0-beta-rc1

        local done = false

        if sweepCallback then
            assert( type( sweepCallback ) == 'function', 'Callback is required to be a function' )
        end

        local x = roundIdx
        local y = 0

        for direction, nsteps in ipairs( paths ) do
            local infoTbl = {
                round = roundIdx, direction = direction,
                steps = nil, x = nil, y = nil,
            }
            if nsteps == 0 then
                if sweepCallback then
                    infoTbl.x = x; infoTbl.y = y; infoTbl.steps = 0
                    sweepCallback( infoTbl )
                end
                done = true
                break
            else
                for n = 0, nsteps - 1 do
                    if sweepCallback then
                        if direction == 1 then y = y + 1
                        elseif direction == 2 then x = x + 1
                        elseif direction == 3 then y = y - 1
                        elseif direction == 4 then x = x - 1
                        end

                        infoTbl.x = x; infoTbl.y = y; infoTbl.steps = n
                        sweepCallback( infoTbl )
                    end
                    turtle.gofd( true )
                end
                turtle.turnRight()
            end
        end

        if done then break end
        roundIdx = roundIdx + 1
    end
    return true
end

local logFH = fs.open( 'log', 'w' )
local success, err = rdaneel:sweepField( 10, 10,
    function ( info )
        local log = string.format(
            "Round: %d; Dir: %d; X: %d", info.round, info.direction, info.x )

        logFH.writeLine( log )

        local exists, details = turtle.inspectDown()
        if exists then
            logFH.writeLine( details.name )
        end

        logFH.writeLine( '*' )
        logFH.flush()
    end
)

assert( success, err )