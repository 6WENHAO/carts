X = 64
Y = 64
data = 0
function _init()
    cls()
    map(0, 0, 0, 0, 16, 16) -- Draw the map
end

function _update60()

    if btn(1) then x-=1 end
    if btn(2) then x+=1 end
    if btn(3) then y-=1 end
    if btn(4) then y+=1 end
    data = mget(X,Y) -- Load the map data
end

function _draw()
    cls()
    map(0, 0, 0, 0, 16, 16) -- Draw the map
    spr(1, X, Y) -- Draw a sprite at the current position
    print(data, 0, 8) -- Print the map data
end