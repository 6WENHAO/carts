-- 优化后的 PICO-8 蓄力跳跃代码

-- 全局变量
page = 0          -- 0: 开始页, 1: 游戏中
player = nil
ground_y = 100    -- 地面高度（备用）
data1 = 0         -- 调试用，可删除

function _init()
    cls()
    print("Hello, World!", 0, 0)
    print("Press X to start", 0, 8)
    player = create_player()
end

function _update60()
    if page == 0 then
        if btnp(❎) then
            page = 1
        end
    else
        update_player(player)
    end
end

function _draw()
    if page == 1 then
        cls()
        map()   -- 绘制地图
        draw_player(player)
        -- 调试信息（可注释）
        print(mget(flr(player.x/8), flr((player.y+player.h)/8)), 2, 2)
        print(flr(player.x), 0, 8)
        print(flr(player.y), 0, 16)
        print('charge:' .. tostr(player.jump_charge), 0, 24)
        print('o_prev:' .. tostr(player.o_prev), 0, 32)
        print('jump:' .. tostr(player.jump_request), 0, 40)
    end
end

-- 创建玩家对象
function create_player()
    return {
        x = 64, y = 64,
        w = 8, h = 8,
        dx = 0, dy = 0,
        speed = 0.4,                -- 基础速度
        run_mult = 2,             -- 按住 X 的加速倍数
        gravity = 0.2,
        max_fall = 4,             -- 最大下落速度
        base_jump = -2,           -- 基础跳跃力量（负值向上）
        max_charge = 3,           -- 最大蓄力值
        jump_charge = 1.5,        -- 当前蓄力
        jump_request = false,     -- 请求跳跃
        o_prev = false,           -- 上一帧 O 键状态
        is_grounded = false,
        flip_x = false,
        direction = 1,
        spr = 64,                 -- 当前精灵
        hp = 3,
        max_hp = 3,
        invincible = 0,
        score = 0,
    }
end

-- 玩家主更新逻辑
function update_player(p)
    -- 处理输入（移动、加速）
    handle_input(p)

    -- 处理跳跃蓄力与触发（仅在地面）
    if p.is_grounded then
        handle_jump_charge(p)
    end

    -- 应用重力
    p.dy += p.gravity
    p.dy = mid(-p.max_charge, p.dy, p.max_fall)   -- 向上速度不会超过 -max_charge

    -- 水平移动
    p.x += p.dx
    p.y += p.dy

    -- 水平边界限制
    p.x = mid(0, p.x, 128 - p.w)

    -- 碰撞检测与地面状态更新
    update_collision(p)

    -- 更新无敌计时器
    if p.invincible > 0 then
        p.invincible -= 1
    end

    -- 根据状态设置精灵
    update_sprite(p)
end

-- 处理左右移动和加速
function handle_input(p)
    -- 摩擦力
    p.dx *= 0.8

    local move = 0
    if btn(⬅️) then
        move = -1
        p.flip_x = true
        p.direction = -1
    elseif btn(➡️) then
        move = 1
        p.flip_x = false
        p.direction = 1
    end

    -- 加速（按住 X）
    local current_speed = p.speed
    if btn(❎) then
        current_speed = p.speed * p.run_mult
    end

    p.dx += move * current_speed
end

-- 处理蓄力跳跃（仅地面调用）
function handle_jump_charge(p)
    local o_now = btn(🅾️)

    -- 如果上一帧按着 O 且这一帧松开 → 触发跳跃
    if p.o_prev and not o_now then
        p.jump_request = true
    end

    -- 如果当前按着 O，则蓄力增加
    if o_now then
        p.jump_charge = min(p.jump_charge + 0.1, p.max_charge)
    end

    p.o_prev = o_now

    -- 执行跳跃
    if p.jump_request then
        -- 跳跃速度 = 基础跳跃力量 × (当前蓄力 / 默认蓄力)
        -- 默认蓄力为 1.5，因此完全蓄力 (4) 时跳跃高度约为 2.67 倍
        local jump_power = p.base_jump * (p.jump_charge / 1.5)
        p.dy = jump_power
        p.jump_charge = 1.5       -- 重置蓄力
        p.jump_request = false
        p.is_grounded = false
    end
end

-- 更新碰撞检测与地面状态
function update_collision(p)
    -- 计算玩家脚底的行（tile y）
    local foot_row = flr((p.y + p.h) / 8)
    -- 左、右两个检测点（基于玩家宽度）
    local left_col = flr(p.x / 8)
    local right_col = flr((p.x + p.w - 1) / 8)

    -- 检测脚下两个 tile 是否为地面（这里用 tile 5 表示）
    local ground_left = mget(left_col, foot_row) == 5
    local ground_right = mget(right_col, foot_row) == 5

    if ground_left or ground_right then
        -- 站在地图砖块上
        p.dy = min(p.dy, 0)
        -- 将玩家 y 对齐到砖块顶部
        p.y = foot_row * 8 - p.h
        p.is_grounded = true
    elseif p.y >= ground_y - p.h then
        -- 碰到备用地面线
        p.y = ground_y - p.h
        p.dy = min(p.dy, 0)
        p.is_grounded = true
    else
        p.is_grounded = false
    end

    -- 防止飞出屏幕上方
    if p.y < 0 then
        p.y = 0
        p.dy = 0
    end
end

-- 根据状态更新精灵
function update_sprite(p)
    if p.is_grounded then
        if p.dx == 0 then
            p.spr = 64   -- 站立
        else
            p.spr = 64   -- 跑动（可替换为动画）
        end
    else
        if p.dy < 0 then
            p.spr = 67   -- 上升
        elseif p.dy > 0 then
            p.spr = 65   -- 下落
        else
            p.spr = 66   -- 顶点
        end
    end
end

-- 绘制玩家与 UI
function draw_player(p)
    -- 绘制玩家精灵（闪烁无敌效果）
    if p.invincible % 6 < 3 then
        spr(p.spr, p.x, p.y, 1, 1, p.flip_x)
    end

    -- 绘制地面线（可选）
    rectfill(0, ground_y, 127, 127, 6)

    -- 绘制生命值
    for i=1,p.hp do
        spr(2, 4 + (i-1)*10, 4)
    end
end

-- 玩家受伤
function player_hit(p)
    if p.invincible <= 0 then
        p.hp -= 1
        p.invincible = 30
        if p.hp <= 0 then
            game_over()
        end
    end
end

-- 游戏结束
function game_over()
    page = 0
    cls()
    print("Game Over", 40, 60)
    print("Press ❎ to restart", 20, 70)
    -- 重新创建玩家（重置状态）
    player = create_player()
end

-- 碰撞检测辅助（可用于敌人等）
function check_collision(a, b)
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + b.h and
           a.y + a.h > b.y
end