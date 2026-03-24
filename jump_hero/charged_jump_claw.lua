-- 优化后的 PICO-8 蓄力跳跃代码 - 带蓄力条和下蹲动画 + 卷轴地图

-- 全局变量
page = 0          -- 0: 开始页, 1: 游戏中
player = nil
ground_y = 100    -- 地面高度（备用）
data1 = 0         -- 调试用，可删除
title_charge = 0  -- 标题页蓄力动画
camera_x = 0      -- 摄像机水平位置
map_width = 128   -- 地图宽度（以 tile 为单位，128*8=1024像素）

function _init()
    player = create_player()
    -- 标题页动画变量
    title_time = 0
    title_particles = {}
    for i = 1, 20 do
        title_particles[i] = {
            x = rnd(128),
            y = rnd(128),
            spd = 0.2 + rnd(0.5),
            size = 1 + flr(rnd(2))
        }
    end
end

function _update60()
    if page == 0 then
        -- 标题页动画更新
        title_time = title_time + 1
        
        -- 更新粒子
        for p in all(title_particles) do
            p.y = p.y - p.spd
            if p.y < 0 then
                p.y = 128
                p.x = rnd(128)
            end
        end
        
        if btnp(❎) then
            page = 1
            -- 重置玩家状态
            player.x = 64
            player.y = 64
            player.dx = 0
            player.dy = 0
            player.jump_charge = 1.5
            camera_x = 0
        end
    else
        update_player(player)
        update_camera()  -- 更新摄像机
    end
end

function _draw()
    if page == 0 then
        -- 标题页动画绘制
        cls(1)  -- 深蓝色背景
        
        -- 绘制背景粒子
        for p in all(title_particles) do
            pset(p.x, p.y, 6)
        end
        
        -- 标题上下浮动动画
        local title_y = 20 + sin(title_time * 0.05) * 3
        
        -- 绘制标题 "JUMP HERO"
        draw_text_shadow("JUMP", 38, title_y, 7)
        draw_text_shadow("HERO", 42, title_y + 10, 8)
        
        -- 绘制跳跃的小人预览
        local bob_y = 70 + sin(title_time * 0.1) * 4
        local jump_frame = flr(title_time / 10) % 4
        local preview_spr = 64 + jump_frame
        if (jump_frame == 2 or jump_frame == 3) then
            preview_spr = 68  -- 跳跃帧
        end
        spr(preview_spr, 60, bob_y, 1, 1, false, false)
        
        -- 按键提示闪烁
        if flr(title_time / 30) % 2 == 0 then
            print("PRESS X TO START", 30, 100, 6)
        else
            print("PRESS X TO START", 30, 100, 5)
        end
        
        -- 底部装饰
        print("by PicoSir", 45, 120, 4)
    else
        cls()
        -- 设置摄像机偏移
        camera(camera_x, 0)
        
        map()   -- 绘制地图（会自动根据 camera 偏移）
        
        draw_player(player)
        
        -- 恢复摄像机绘制 UI
        camera(0, 0)
        draw_charge_bar(player)  -- 绘制蓄力条（不随卷轴移动）
    end
end

-- 带阴影的文字绘制
function draw_text_shadow(txt, x, y, col)
    print(txt, x - 1, y, 0)  -- 阴影
    print(txt, x, y - 1, 0)
    print(txt, x, y, col)
end

-- 更新摄像机跟随玩家
function update_camera()
    -- 摄像机目标位置：玩家居中
    local target_x = player.x - 64
    
    -- 限制摄像机范围
    target_x = max(0, target_x)
    target_x = min(target_x, (map_width * 8) - 128)
    
    -- 平滑跟随
    camera_x = camera_x + (target_x - camera_x) * 0.1
end

-- 创建玩家对象
function create_player()
    return {
        x = 64, y = 64,
        w = 8, h = 8,
        dx = 0, dy = 0,
        speed = 0.3,                -- 基础速度
        run_mult = 2,               -- 按住 X 的加速倍数
        gravity = 0.2,
        max_fall = 4,               -- 最大下落速度
        base_jump = -1.5,             -- 基础跳跃力量（负值向上）
        max_charge = 3.5,             -- 最大蓄力值
        jump_charge = 1.5,          -- 当前蓄力
        jump_request = false,       -- 请求跳跃
        o_prev = false,             -- 上一帧 O 键状态
        is_grounded = false,
        is_charging = false,        -- 当前是否正在蓄力
        flip_x = false,
        direction = 1,
        spr = 64,                   -- 当前精灵
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

    -- 水平边界限制（适应卷轴地图）
    p.x = mid(0, p.x, map_width * 8 - p.w)

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
    -- 计算当前蓄力比例 (0-1)
    local charge_ratio = (p.jump_charge - 1.5) / (p.max_charge - 1.5)
    charge_ratio = mid(0, charge_ratio, 1)
    
    -- 始终应用基础摩擦力
    p.dx *= 0.8
    
    -- 蓄力超过50%时额外减速（模拟人蓄力跳时减速直到停止）
    if p.is_charging and charge_ratio > 0.5 then
        local slow_amount = (charge_ratio - 0.5) * 0.15  -- 每帧额外减速
        p.dx *= (1 - slow_amount)
    end

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

    -- 加速（按住 X）- 蓄力时不加速
    local current_speed = p.speed
    if btn(❎) and not p.is_charging then
        current_speed = p.speed * p.run_mult
    end

    -- 蓄力时不增加新的移动（让人停下来蓄力跳）
    if not p.is_charging then
        p.dx += move * current_speed
    end
end

-- 处理蓄力跳跃（仅地面调用）
function handle_jump_charge(p)
    local o_now = btn(🅾️)

    -- 检测玩家是否在跑动
    local is_running = abs(p.dx) > 0.3
    
    -- 跑动蓄力时：蓄力更快 + 跳跃更高
    -- 静止蓄力时：蓄力慢 + 跳跃低
    local charge_speed = is_running and 0.1 or 0.05  -- 跑动蓄力快一倍
    local jump_boost = is_running and 1.5 or 1.0      -- 跑动跳跃力量+50%

    -- 如果上一帧按着 O 且这一帧松开 → 触发跳跃
    if p.o_prev and not o_now then
        p.jump_request = true
    end

    -- 如果当前按着 O，则蓄力增加
    if o_now then
        p.jump_charge = min(p.jump_charge + charge_speed, p.max_charge)
        p.is_charging = true      -- 标记蓄力状态
    else
        p.is_charging = false     -- 不蓄力时清除标记
    end

    p.o_prev = o_now

    -- 执行跳跃
    if p.jump_request then
        -- 跳跃速度 = 基础跳跃力量 × (当前蓄力 / 默认蓄力) × 跑动加成
        local jump_power = p.base_jump * (p.jump_charge / 1.5) * jump_boost
        p.dy = jump_power
        p.jump_charge = 1.5       -- 重置蓄力
        p.jump_request = false
        p.is_grounded = false
        p.is_charging = false
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
    -- 蓄力时显示下蹲 sprite (69)
    if p.is_charging then
        p.spr = 69
        return
    end

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

-- 绘制蓄力条 UI
function draw_charge_bar(p)
    local bar_x = 50      -- 蓄力条 X 位置
    local bar_y = 4       -- 蓄力条 Y 位置
    local bar_w = 30      -- 蓄力条宽度
    local bar_h = 4       -- 蓄力条高度
    
    -- 蓄力比例 (0-1)
    local charge_ratio = (p.jump_charge - 1.5) / (p.max_charge - 1.5)
    charge_ratio = mid(0, charge_ratio, 1)
    
    -- 绘制背景槽
    rectfill(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, 1)
    -- 绘制边框
    rect(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, 7)
    
    -- 绘制蓄力填充
    if charge_ratio > 0 then
        local fill_w = flr(bar_w * charge_ratio)
        local color = 11  -- 黄色
        -- 满蓄力时闪烁变色
        if charge_ratio >= 1 then
            local flash = flr(time() * 10) % 2
            color = flash == 0 and 8 or 12  -- 红黄交替闪烁
        end
        rectfill(bar_x + 1, bar_y + 1, bar_x + fill_w, bar_y + bar_h - 1, color)
    end
    
    -- 满蓄力时显示 "MAX!" 提示
    if charge_ratio >= 1 then
        local flash = flr(time() * 8) % 2
        if flash == 0 then
            print("MAX!", bar_x + 2, bar_y - 4, 8)
        end
    end
end

-- 绘制玩家与 UI
function draw_player(p)
    -- 绘制玩家精灵（闪烁无敌效果）
    if p.invincible % 6 < 3 then
        spr(p.spr, p.x, p.y, 1, 1, p.flip_x)
    end
    
    -- 蓄力时在玩家上方显示蓄力粒子效果
    if p.is_charging then
        local ratio = (p.jump_charge - 1.5) / (p.max_charge - 1.5)
        if ratio > 0.5 then
            -- 蓄力超过50%时显示粒子
            local particles = flr(ratio * 4)
            for i=1,particles do
                local px = p.x + 2 + flr(rnd(4))
                local py = p.y - 2 - flr(rnd(4))
                pset(px, py, 7)
            end
        end
    end

    -- 绘制地面线（可选）
    rectfill(0, ground_y, map_width * 8 - 1, 127, 6)

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
