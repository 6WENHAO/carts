
count = 0
page = 0
start_flag = false
X = 64 Y = 64
speed = 2
ground_y = 100


function _init()
    cls()
    print("Hello, World!", 0, 0)
    print("Press X to start", 0, 8)
    player = create_player()
    data1 = 0
end


function _update60()
    if page==0 then
        if btnp(❎) then
            page = 1
            start_flag = true
        end
    end

    if page==1 then
        if start_flag then
            update_player(player)
        end

    end



end


function _draw()
    if page==1 then
        cls()
        map() -- Draw the map
        draw_player(player)
        print(mget(flr(player.x/8),flr((player.y+player.h)/8)), 2, 2)
        print(flr(player.x), 0, 8)
        print(flr(player.y), 0, 16)
        print('jump_charge:' .. tostr(player.jump_charge), 0, 24)
        print('z_prev:' .. tostr(player.z_prev), 0, 32)
        print('jump_status:' .. tostr(player.jump_status), 0, 40)
    end
end

function zbutton(p)
    if p.z_prev then
        if not btn(🅾️) then
            p.jump_status = true
        else
            if p.jump_charge<4 then
                p.jump_charge += 0.1
            end
        end
    end
    p.z_prev = btn(🅾️)

end


function create_player()
    local player = {
        x = 64,
        y = 64,
        w = 8, --width
        h = 8, --height
        dx = 0,
        dy = 0,
        speed = 1,
        jump_force = -3, -- jump power
        gravity = 0.2,   -- Gravity
        max_fall = 3,    -- fall speed limit
        is_grounded = false, -- is on the ground
        z_prev = false,
        hp = 3,
        max_hp = 3,
        score = 0,
        spr = 64,
        flip_x = false,
        invincible = 0,
        direction = 1,
        jump_charge = 1.5, -- charge for jump
        jump_status = false, -- is jumping
    }
    return player
end

function update_player(p)
    p.dx = p.dx* 0.8 -- friction
    
    if btn(⬅️) then
        p.dx = -p.speed
        p.flip_x = true
        p.direction = -1
    end
    if btn(➡️) then
        p.dx = p.speed
        p.flip_x = false
        p.direction = 1
    end
    
    if p.is_grounded then
        zbutton(p)
        if p.jump_status then
            p.dy = -p.jump_charge
            p.jump_charge = 1.5
            p.jump_status = false
            p.is_grounded = false
            
            if p.dy>0 then
                p.spr = 65
            elseif p.dy==0 then
                p.spr = 66
            else
                p.spr = 67
            end

        end
    end

    if btn(❎) then
        p.speed = 2
    else
        p.speed = 1
    end
    
    p.dy += p.gravity
    p.dy = mid(p.jump_force, p.dy, p.max_fall)
    

    

    if mget(p.x/8+0.1 ,(p.y+p.h)/8) == 5 or mget(p.x/8 +0.7,(p.y+p.h)/8) == 5   then
        data1 += 1
        p.dy = min(p.dy,0)
        if p.dy==0 then
            p.y = flr((p.y + p.h) / 8) * 8 - p.h 

        end
        if not p.is_grounded then
            p.spr = 69
        else
            p.spr = 64
        end
        p.is_grounded = true
    else
        if p.y >= ground_y - p.h then
            p.y = ground_y - p.h
            p.dy = min(p.dy,0)
            if not p.is_grounded then
                p.spr = 69
            else
                p.spr = 64 
            end
            p.is_grounded = true
        else
            if p.dy>0 then
                p.spr = 65
            elseif p.dy==0 then
                p.spr = 66
            else
                p.spr = 67
            end
            p.is_grounded = false
        end
    end

    p.x += p.dx
    p.y += p.dy

    p.x = mid(0, p.x, 128 - p.w)
end

function draw_player(p)
    spr(p.spr, p.x, p.y, 1, 1, p.flip_x)
    
    rectfill(0, ground_y, 127, 127, 6)
    
    for i=1,p.hp do
        spr(2, 4 + (i-1)*10, 4) 
    end
end

function game_over()
    cls()
    page = 0
    print("Game Over", 40, 60)
    print("Press ❎ to restart", 20, 70)
end

function player_hit(p)
    if p.invincible <= 0 then
        p.hp -= 1
        p.invincible = 30 
        if p.hp <= 0 then
            game_over()
        end
    end
end

-- function update_player(p)
    
--     p.is_moving = (dx != 0 or dy != 0)
    
--     if p.is_moving then
--         p.anim_timer += 1
--         if p.anim_timer > 10 then
--             p.anim_timer = 0
--             p.anim_frame = (p.anim_frame + 1) % 2 
--         end
--     else
--         p.anim_frame = 0
--         p.anim_timer = 0
--     end
-- end

-- function draw_player(p)
--     local spr_to_draw = p.spr + p.anim_frame
-- end

function check_collision(a, b)
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + b.h and
           a.y + a.h > b.y
end
