--> commander boss oval bomb
local _OVALB = BaseObject:subclass ( "boss_commander_oval_bomb" )

_OVALB.static.IS_PERSISTENT          = true
_OVALB.static.NO_DATA_CHIP           = true
_OVALB.static.USES_POOLING           = true
_OVALB.static.HAS_DESPAWN_MECHANISM  = true

_OVALB.static.preload = function ( ) 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc, "projectiles" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Initialize ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _OVALB:finalize ( )
  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "projectiles", 1 )

  self.ring   = {
    active = false,
    ox     = 16,
    oy     = 15,
    r      = 0,
    t      = 40,
  }
  self.ring.tween = Tween.new ( 24, self.ring, { r  = 38, t  = 0 }, "outQuad" )

  self.ring2   = {
    active = false,
    ox     = 16,
    oy     = 15,
    r      = 0,
    t      = 18,
  }
  self.ring2.tween = Tween.new ( 24, self.ring2, { r  = 18, t  = 0 }, "outQuad" )

  self.layer  = Layers:get ( "ENEMIES", "PARTICLES" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Reset --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _OVALB:reset ( projSpeed, projLayer )
  self.timer            = 180
  self.projSpeed        = projSpeed or 3
  self.projectileLayer  = projLayer or self.layer
  self.spawned          = false

  self.sprite:change ( 1, "omnishot-walker-crystal-shot-flash", 1, true )
  self.sprite:flip   ( 1, 1 )

  local cx, cy = Camera:getPos ( )
  local x, y   = self:getPos   ( )
  if x < cx + 24 then
    x = cx + 24
  elseif x > cx + GAME_WIDTH - 27 then
    x = cx + GAME_WIDTH - 27
  end

  if y > cy + GAME_HEIGHT - 42 then
    y = cy + GAME_HEIGHT - 42
  end

  self.floatTime = 0--GetTime()

  self.ring.active = true
  self.ring.tween:reset ( )

  self.ring2.active = false
  self.ring2.tween:reset ( )

  self:setPos           ( x, y )
  Audio:playSound       ( SFX.gameplay_big_guy_bomb_spawn )
  Audio:playSound       ( SFX.gameplay_breakable_crate_timer_1_short )
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Everything else ----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _OVALB:lateUpdate ( )
  self.ring.tween:update ( 1 )
  self.sprite:update     (   )

  self.floatTime = self.floatTime + 0.10

  if not self.ring2.active and GetTime()%4 == 0 then

    local mx, my = self:getPos()
    mx = mx - 1
    my = my + 1
    local l = self.layer()-1


    --Particles:addFromCategory ( "warp_particle_ray", mx+16, my,     1,  1,  1, 0.5, l, false, nil, true )
    --Particles:addFromCategory ( "warp_particle_ray", mx-16, my,     1,  1, -1, 0.5, l, false, nil, true )
    Particles:addFromCategory ( "warp_particle_ray", mx+RNG:range(0,4)*RNG:rsign(), my+16+RNG:range(0,3),  1, -1,  0,  1, l, false, nil, true )
    Particles:addFromCategory ( "warp_particle_ray", mx+RNG:range(0,4)*RNG:rsign(), my-16-RNG:range(0,3),  1,  1,  0, -1, l, false, nil, true )

    --type, x, y, sx, sy, rx, ry, depth, UI, initialDelay, noRandomness, framerate
    --[[
    Particles:add ( "cannoneer-shot-particle3", mx-16, my,    1, 1, -1,  0, self.layer()-1, false, nil, true )
    Particles:add ( "cannoneer-shot-particle3", mx+16, my,    1, 1,  1,  0, self.layer()-1, false, nil, true )
    Particles:add ( "cannoneer-shot-particle3", mx,    my-16, 1, 1,  0, -1, self.layer()-1, false, nil, true )
    Particles:add ( "cannoneer-shot-particle3", mx,    my+16, 1, 1,  0,  1, self.layer()-1, false, nil, true )
    ]]
  end

  if self.timer == 5 then
    local mx, my = self:getPos()
    mx = mx + 1
    --my = my
    local l = self.layer()
    Particles:add ( "beam_palm_purge_flash_v_com", mx,my, math.rsign(), 1, 0, 0, l )
  end

  self.timer = self.timer - 1
  if self.timer <= 0 and not self.spawned then



    self.ring2.active = true
    Audio:playSound ( SFX.gameplay_enemy_explosion      )
    Audio:playSound       ( SFX.gameplay_big_guy_bomb_explode, 0.75 )
    self.spawned = true
    local x, y       = self:getPos ( )

    local cols, len = Physics:queryRect ( x-20, y-20, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x+7, y+7, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x+37, y+7, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x+7, y+37, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x+37, y+37, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x-27, y+7, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x+7, y-27, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x+37, y-27, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x-27, y+37, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end
    local cols, len = Physics:queryRect ( x-27, y-27, 40, 40 )
    for i = 1, len do
      if cols[i] and cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
        break
      end
    end


    -------------------
    -- spawn bullets --
    -------------------
    x = x - 7
    y = y - 6
    local speed      = self.projSpeed
    local dirX, dirY = math.nineWayShotAngles ( 6 )


    --Particles:addSpecial("small_explosions_in_a_circle", x, y, self.projectileLayer()+2, false, 3.25, 1.75, 0.005 )

    Particles:addSpecial("small_explosions_in_a_circle", x+7, y+7, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x+37, y+7, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x+7, y+37, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x+37, y+37, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x-27, y+7, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x+7, y-27, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x-27, y+37, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x+37, y-27, self.projectileLayer()+2, false, 1 )
    Particles:addSpecial("small_explosions_in_a_circle", x-27, y-27, self.projectileLayer()+2, false, 1 )

  end

  if self.spawned then
    self.ring2.tween:update(1)
    if self.ring2.t <= 0 then
      self:delete ( )
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _OVALB:draw ( )
  local l    = self.layer   ( )
  local x, y = self:getPos  ( )
  if not self.ring2.active then
    self.sprite:draw ( 1, x, y+math.sin(self.floatTime)*3, l, false )
  end

  if self.ring.t > 0 then
    GFX:push ( l, love.graphics.setLineWidth, self.ring.t   )
    GFX:push ( l, love.graphics.circle, "line", x, y, self.ring.r )
    GFX:push ( l, love.graphics.setLineWidth, 1 )
  end

  if self.ring2.active and self.ring2.t > 0 then
    GFX:push ( l, love.graphics.setLineWidth, self.ring2.t   )
    GFX:push ( l, love.graphics.circle, "line", x, y, self.ring2.r )
    GFX:push ( l, love.graphics.setLineWidth, 1 )
  end
end

return _OVALB