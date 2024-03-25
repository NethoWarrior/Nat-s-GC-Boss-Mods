--> [VIRUS HELI MISSILE] - what virus heli shoots
local _MISSILE = BaseObject:subclass ( "VIRUS_HELI_MISSILE" )
  Mixins:attach( _MISSILE, "particleSpawning"  )
  Mixins:attach( _MISSILE, "applyPhysics"      )
  Mixins:attach( _MISSILE, "afterImages"       )
  Mixins:attach( _MISSILE, "shake"             )
  Mixins:attach( _MISSILE, "grabObject"        )
  Mixins:attach( _MISSILE, "pullObject"        )


_MISSILE.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles" )
end

_MISSILE.static.USES_POOLING          = true
_MISSILE.static.HAS_DESPAWN_MECHANISM = true
_MISSILE.static.NO_DATA_CHIP          = true

_MISSILE.static.EDITOR_DATA = {
  width       = 1,
  height      = 1,
  ox          = 0,
  oy          = 0,
  mx          = 8,
  category    = "obstacle",
  properties  = {
    --isStaticSpawn = true,
  },
  parameters = {
    isStaticSpawn = true,
  },
}

_MISSILE.static.DIMENSIONS = {
  x   = 0,
  y   = 3,
  w   = 32,
  h   = 10,

  grabX =  10,
  grabY =  3,
  grabW =  9,
  grabH =  10,

  grabPosX = -3,
  grabPosY = 9,
}

_MISSILE.static.FILTERS = {
  collision = Filters:get ( "bulletFilter"          ),
  explosion = Filters:get ( "queryExplosionFilter"  ),
  player    = Filters:get ( "queryPlayer"           ),
  ground    = function (other) return other.isTile and other.isSolid and not other.isMinibossGenerated end--Filters:get ( "queryTileFilter"       ),
}

_MISSILE.static.LAYERS = {
  particles = Layer:get ( "ENEMIES", "PARTICLES"     ),
}

_MISSILE.static.PROPERTIES = {
  isSolid               = false,
  isDamaging            = true,
  isBulletType          = true,
  isFreezing            = true,
  isHittableProjectile  = false,
  isEnergyless          = true,
  ignoresPassables      = true,

  isBonkable            = true,
}

_MISSILE.static.PALETTE = createColorVector ( 
  Colors.black, 
  Colors.green_blue,
  Colors.shopkeeper_blue,
  Colors.kernel_light_green,
  Colors.white,
  Colors.whitePlus
)
_MISSILE.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_blue,
  Colors.green_blue, 
  Colors.green_blue, 
  Colors.shopkeeper_blue, 
  Colors.shopkeeper_blue,
  Colors.shopkeeper_blue
)

_MISSILE.static.DAMAGE = {
  HIT = GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT,
}

_MISSILE.static.SENSORS = {
  player = 
    Sensor
      :new               ( nil, _MISSILE.FILTERS.player, -194-244, -8, 502+288, 2, 0, 0 )
      :isScaleAgnostic   ( true )
      :expectOnlyOneItem ( true )
      :disableDraw       ( true ),
  ground_down =
      Sensor
        :new             ( nil, _MISSILE.FILTERS.ground, -33-20, -8, 52, 18+10, 0, 0 )
        :isScaleAgnostic ( true ),
  explosion = 
    Sensor
        :new            ( nil, _MISSILE.FILTERS.explosion, -18, -18, 15+_MISSILE.DIMENSIONS.w, 15+_MISSILE.DIMENSIONS.h, 0, 0 )
      :disableDraw       ( true ),
}

_MISSILE.static.SENSORS_VERT = {
  explosion = 
    Sensor
        :new            ( nil, _MISSILE.FILTERS.explosion, -24, -19, 14, 34, 0, 0 ),
}

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Initialize ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MISSILE:finalize ( )
  self.sprite  = Sprite:new ( SPRITE_FOLDERS.projectiles, "projectiles", 1 )
  self.sprite:addInstance ( 2 )

  self:addCollider ( "collision", self.dimensions.x,      self.dimensions.y,      self.dimensions.w,      self.dimensions.h,    self.properties )
  self:addCollider ( "grabbox",   self.dimensions.x-2,    self.dimensions.y-2,    self.dimensions.w+4,    self.dimensions.h+4, self.class.GRABBOX_PROPERTIES )
  self:addCollider ( "grabbed",   self.dimensions.grabX,  self.dimensions.grabY,  self.dimensions.grabW,  self.dimensions.grabH )
  self.updatePhysics = true

  self:setAfterImagesDelay   ( 0 )
  self.l1 = Layer:get ( "ENEMY-BEHIND-PHYSICAL-TILES" )
  self.l2 = Layer:get ( "ENEMIES", "PROJECTILES") 
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Reset --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

local lastDir = 0
function _MISSILE:reset ( parameters, dir, spawner, vertical )
  if not self.explosionHitTable then
    self.explosionHitTable = {}
  else
    cleanTable(self.explosionHitTable)
  end
  self.IGNORED_TILES_FOR_COLLISION = nil

  local static = false
  if parameters and parameters.isStaticSpawn then
    self:setPos ( Camera:getX() + GAME_WIDTH + 16, self:getY() )
    dir      = -1
    vertical = false
    static   = true
  end

  local vy,vx   = self.velocity.vertical, self.velocity.horizontal  
  if not vertical then
    vy.current    = 2.0
    vy.direction  = 1
    vy.update     = true
    vx.current    = -0.5
    vx.direction  = dir
    self.vertical = false

    self.colliders.collision.rect.x = self.dimensions.x
    self.colliders.collision.rect.y = self.dimensions.y
    self.colliders.collision.rect.w = self.dimensions.w
    self.colliders.collision.rect.h = self.dimensions.h

    self.colliders.grabbox.rect.x   = self.dimensions.x-2
    self.colliders.grabbox.rect.y   = self.dimensions.y-2
    self.colliders.grabbox.rect.w   = self.dimensions.w+4
    self.colliders.grabbox.rect.h   = self.dimensions.h+4

    self.colliders.grabbed.rect.x   = self.dimensions.grabX
    self.colliders.grabbed.rect.y   = self.dimensions.grabY
    self.colliders.grabbed.rect.w   = self.dimensions.grabW
    self.colliders.grabbed.rect.h   = self.dimensions.grabH

    self.lateUpdate = self._lateUpdate

    self.sprite:stopRewind  ( 1, false )
    self.sprite:change      ( 1, "virus-heli-missile", 1, false )
    self.sprite:change      ( 2, nil )
    self.sprite:flip        ( dir or 1, 1 )

    self.sensors = self.class.SENSORS
  else
    self.sensors = self.class.SENSORS_VERT

    vy.current    = -2
    vy.update     = false
    vy.direction  = 1
    vx.current    = 0
    vx.direction  = 0
    self.vertical = true

    self.colliders.collision.rect.x = self.dimensions.x + 10
    self.colliders.collision.rect.y = self.dimensions.y - 10
    self.colliders.collision.rect.w = self.dimensions.w - 22
    self.colliders.collision.rect.h = self.dimensions.h + 20

    self.colliders.grabbox.rect.x   = self.dimensions.x+9
    self.colliders.grabbox.rect.y   = self.dimensions.y-14
    self.colliders.grabbox.rect.w   = self.dimensions.w-20
    self.colliders.grabbox.rect.h   = self.dimensions.h+24

    self.colliders.grabbed.rect.x   = self.dimensions.grabX
    self.colliders.grabbed.rect.y   = self.dimensions.grabY
    self.colliders.grabbed.rect.w   = self.dimensions.grabW
    self.colliders.grabbed.rect.h   = self.dimensions.grabH

    self.lateUpdate = self._vertUpdate

    self.sprite:stopRewind  ( 1, false )
    self.sprite:change      ( 1, "virus-heli-missile-pink",         1, false )
    self.sprite:change      ( 2, "virus-heli-missile-exhaust-pink", 1, true  )
    self.sprite:flip        ( 1, 1 )
  end

  self.inserted         = false
  self.isDestroyed      = false
  self.isReflected      = false
  self.tookDamage       = false
  self.exploded         = false

  self.spawnerObjectToIgnore = spawner
  self.isIgnoringTiles       = false

  self.etimer = 5
  self.timer  = 0

  self.layer = vertical and self.l1 or self.l2

  if static then
    self.isAwakened = true
    --self:activate_from_drop()
    self.addTimer = 0
    self.isStatic = true
    self.wtimer   = 0
    self.velocity.horizontal.current = 4

    self.lateUpdate = self._warningUpdate
    self.draw       = self._warningDraw
    self.wcount     = -1
    self.wx         = 0
    self.deleteAfterWards = false
  else
    self:insertCollider ( "collision" ) 
    self:insertCollider ( "grabbox"   )
    self:insertCollider ( "grabbed"   )  
    self.inserted   = true

    self.isAwakened = false 
    self.addTimer   = 0
    self.isStatic   = false
    self.draw       = self._draw
  end
end

_MISSILE.LAST_PLAYER_CHECK_TIME   = -1
_MISSILE.LAST_PLAYER_CHECK_RESULT = false

_MISSILE.CHECK_FLOAT_RIDER_FILTER = function ( other ) return other.isFloatRider end

function _MISSILE:checkPlayer ( )
  local t = GetTime()
  if t == self.class.LAST_PLAYER_CHECK_TIME then
    return self.class.LAST_PLAYER_CHECK_RESULT
  end
  self.class.LAST_PLAYER_CHECK_TIME = t
  local p = GlobalObserver:single ("GET_PLAYER_OBJECT")
  if not p or (p.state.isEmergencyWarping) then
    self.class.LAST_PLAYER_CHECK_RESULT = true
    return true
  end
  local cx, cy     = Camera:getPos()
  local obj, len   = Physics:queryRect ( cx-10, cy-64, GAME_WIDTH+20, GAME_HEIGHT+128, self.class.CHECK_FLOAT_RIDER_FILTER )
  if len == 0 or (len >= 1 and obj[1].parent.velocity.horizontal.current < 0) then
    self.class.LAST_PLAYER_CHECK_RESULT = true
    return true
  end

  self.class.LAST_PLAYER_CHECK_RESULT = false
end

function _MISSILE:giveIgnoredTiles ( tiles )
  self.IGNORED_TILES_FOR_COLLISION = tiles
  return self
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Warning version     ------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _MISSILE:_warningUpdate ( )
  if not self.deleteAfterWards and self:checkPlayer() then
    self.wcount           = 6
    self.deleteAfterWards = true
    return 
  end

  if self.wtimer%30 == 0 and self.wcount < 2 then
    Audio:playSound ( SFX.gameplay_medley_wink, 0.7 )
  end


  self.wtimer = self.wtimer + 1
  if self.wtimer > 15 then
    self.wtimer = 0
  end
  if self.wtimer == 14 then
    self.wcount = self.wcount + 1
  end
  if self.wcount < 3 then
    if self.wx < 30 then
      self.wx = math.min ( self.wx + 3, 48 )
    elseif self.wx < 40 then
      self.wx = math.min ( self.wx + 2, 48 )
    else
      self.wx = math.min ( self.wx + 1, 48 )
    end
  else 
    self.wx = self.wx - 3
    if self.wx <= 0 then
      if self.deleteAfterWards then
        self:delete()
        return
      end
      self:setPos ( Camera:getX() + GAME_WIDTH + 16, self:getY() )
      self:insertCollider ( "collision" ) 
      self:insertCollider ( "grabbox"   )
      self:insertCollider ( "grabbed"   )  
      self.inserted = true

      self:activate_from_drop ( true )
      self.sprite:change      ( 1, "virus-heli-missile", 1, false )
      self.velocity.horizontal.current   = 4
      self.velocity.horizontal.direction = -1

      self.lateUpdate = self._lateUpdate
      self.draw       = self._draw
    end
  end
end

function _MISSILE:_warningDraw ( )
  local f = 1
  if self.wtimer > 5 and self.wtimer <= 8 then
    f = 2
  elseif self.wtimer > 8 and self.wtimer <= 14 then
    f = 3
  elseif self.timer > 14 then
    f = 4
  end
  --if self.wtimer < 13 and self.wtimer > 0 then
    self.sprite:drawFrame ( "virus-heli-missile-warning", f, Camera:getX() + GAME_WIDTH - 6 - self.wx, self:getY()-16, self.layer() )
  --end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Horizontal version  ------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _MISSILE:_lateUpdate(dt)
  local x, y = self:getPos()
  if not Camera:isWithinView ( x, y, 30) then
    self.isDestroyed = true
    self:delete ()
    return
  end

  if self.sprite:isRewinding() and self.sprite:getFrame() == 1 and self.sprite:getFrameTime() == 0 then
    self.sprite:setFrame ( 1, 8 )
    self.sprite:rewind   ( 1, true )
  end

  self.sprite:update     ( dt )
  self:handleAfterImages ( )
  self:updateShake       ( )

  if not self.isAwakened and not self.isReflected then
    local hit, player = self.sensors.player:check(nil,nil,self)
    if hit then
      self:activate_from_drop ( )
    else
      hit = self.sensors.ground_down:check(nil,nil,self)
      if hit then
        self:activate_from_drop ( )
      end
    end
  end


  if not self.isChainedByHookshot then
    local a = self.sprite:getAnimation()
    local p = self.sprite:isPlaying()
    if not p and a == "virus-missile-spin-pink" then
      self.sprite:resume()
    elseif not p and a == "virus-missile-spin" then
      self.sprite:resume()
    end
  end

  if not self.exploded then
    if self.isAwakened and not self.isReflected then
      if not self.isStatic then
        if self.addTimer < 6 then 
          if self.addTimer%2 == 0 then
            self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.25, 5.5 )
          end
        else
          self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.5, 5.5 )
        end
        self.addTimer = self.addTimer + 1
      end

      if self.timer % 4 == 0 then
        local sx     = self.sprite:getScaleX ( )
        local mx, my = self:getMiddlePoint   ( "collision" )
        mx           = mx + (sx > 0 and -24 or 10)
        my           = my - 10
        Particles:addFromCategory ( 
          "directionless_dust", 
          mx, 
          my, 
          math.rsign(), 
          1, 
          self.isStatic and 5.5 or 0, 
          0,
          self.layer()-1,
          false,
          nil,
          true
        )
      end
      self.timer = self.timer + 1

    end
    self:applyPhysics ( )

    if self.exploded then
      Audio:playSound ( SFX.gameplay_enemy_projectile_explosion )
      self:removeCollidersFromPhysicalWorld ( )
      self.timer = 5
      self:addExplosion ( "small_orange_explosion" )
      local sx     = self.sprite:getScaleX()
      local mx, my = self:getMiddlePoint("collision")
      mx, my       = mx+2+(sx>0 and 8 or -10), my+2
      Particles:add       ( "death_trigger_flash", mx+(sx>0 and -2 or 2),my-2, math.rsign(), 1, 0, 0, self.layers.particles() )
      Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.7, 0.6 )
    end
  else

    local hit, cols, len = self.sensors.explosion:check(nil,nil,self)
    if hit then
      local other
      for i = 1, len do
        other = cols[i]
        if other and (other.isPlayer or other.isEnemy) and not self.explosionHitTable[other.ID] then
          if self:callObserver(other) then
            self.explosionHitTable[other.ID] = true
          end
        end
      end
    end

    if self.etimer > 0 then
      self.etimer = self.etimer - 1
    else
      self.isDestroyed = true
      self:delete()
    end
  end
end

function _MISSILE:activate_from_drop ( noShake )
  Audio:playSound ( SFX.gameplay_missile_shot )
  if not noShake then
    self:applyVerticalShake ( 2, 0.5, 1 )
  end
  self.sprite:change      ( 2, "virus-heli-missile-exhaust", 2, true )
  self.velocity.vertical.current   = 0
  self.velocity.vertical.update    = false
  self.velocity.horizontal.current = -1
  self.isAwakened = true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Vertical version    ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MISSILE:_vertUpdate ( dt )
  local x, y    = self:getPos()
  local cx, cy  = Camera:getPos()
  if self.isAwakened and (x < (cx-64) or x > (cx+GAME_WIDTH+64) or y < (cy - 128) or y > (cy + GAME_HEIGHT + 48)) then
    self.isDestroyed = true
    self:delete()
    return
  end

  if not self.isAwakened and y < (cy - 64) then
    local px, py = GlobalObserver:single ( "GET_PLAYER_MIDDLE_POINT" )
    if not px then
      px = x + RNG:rsign() * 32
    else
      px = px - 12
    end

    self.colliders.collision.HAS_FINISHED_FIRST_TICK = false
    self:setActualPos ( px, y )
    self.sprite:flip  ( 1, -1 )
    self.isAwakened                = true
    self.velocity.vertical.current = 5
    self.layer = self.l2
  elseif not self.isAwakened then
    self.velocity.vertical.current = math.max ( self.velocity.vertical.current - 0.5, -5 )
  end

  self.sprite:update     ( dt )
  self:handleAfterImages ( )
  self:updateShake       ( )

  if not self.exploded then
    if not self.isReflected then
      if self.timer % 4 == 0 then
        local sy     = self.sprite:getScaleY()
        local mx, my = self:getMiddlePoint   ( "collision" )
        mx           = mx - 14
        my           = my + (sy > 0 and 0 or -24)
        Particles:addFromCategory ( 
          "directionless_dust", 
          mx, 
          my, 
          math.rsign(), 
          1, 
          0, 
          0,
          self.layer()-1,
          false,
          nil,
          true
        )
      end
    end
    self.timer = self.timer + 1

    self:applyPhysics ( )

    if self.exploded then
      Audio:playSound ( SFX.gameplay_enemy_projectile_explosion )
      self:removeCollidersFromPhysicalWorld ( )
      self.timer = 5
      self:addExplosion ( "small_orange_explosion" )
      local sx     = self.sprite:getScaleX()
      local mx, my = self:getMiddlePoint("collision")
      mx, my       = mx, my-1
      Particles:add       ( "death_trigger_flash", mx, my-2, math.rsign(), 1, 0, 0, self.layers.particles() )
      Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.7, 0.6 )
    end
  else
    local hit, cols, len = self.sensors.explosion:check(nil,nil,self)
    if hit then
      local other
      for i = 1, len do
        other = cols[i]
        if other and (other.isPlayer or other.isEnemy) and not self.explosionHitTable[other.ID] then
          if self:callObserver(other) then
            self.explosionHitTable[other.ID] = true
          end
        end
      end
    end

    if self.etimer > 0 then
      self.etimer = self.etimer - 1
    else
      self.isDestroyed = true
      self:delete()
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §misc -              ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MISSILE:callObserver (obj)
  if not (obj.isPlayer or obj.isEnemy or obj.isBreakable) then return end
  if obj.isPlayer then
    if not self.isReflected then
      GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", self.class.DAMAGE.HIT, "weak", self.velocity.horizontal.direction )
      return true
    end
  elseif (self.isReflected or obj.isTile) and obj then
    if (obj.parent and obj.parent.takeDamage and not self.explosionHitTable[obj.parent.ID] and not obj.parent.state.hasBonked) then
      if obj.parent:takeDamage (GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE, self.velocity.horizontal.direction, 2, 0, "grenade") then
        self.explosionHitTable[obj.parent.ID] = true
        return true
      end
    end
  elseif obj.isBreakable then
    obj.parent:takeDamage(nil, self.velocity.horizontal.direction)
    return true
  end
end

function _MISSILE:handleCollisions (colsX, lenX, colsY, lenY )
  for i = 1, lenX do
    if self:callObserver(colsX[i].other) then
      self.exploded = true
    end
  end

  for i = 1, lenY do
    if self:callObserver(colsY[i].other) then
      self.exploded = true
    end
  end
end

function _MISSILE:chain ( )
  self.updatePhysics       = false
  self.isChainedByHookshot = true
  self.sprite:stop(1)
  self:applyShake(3)
  return true
end

function _MISSILE:isSuplexable ( )
  return false
end

function _MISSILE:isGrabbable ()
  return false
end

function _MISSILE:handleBulletBlock ( )
  self.exploded = true
end

function _MISSILE:takeDamage ( dmg, dir, knockbackX, knockbackY, attackType )
  self.isIgnoringTiles = false
  Audio:playSound ( SFX.gameplay_punch_hit_reflect )

  dir = dir or -self.velocity.horizontal.direction
  if math.abs(dir) < 1 then
    dir = RNG:rsign()
  end
  knockbackX = knockbackX or 2
  knockbackY = knockbackY or -3
  
  if self.vertical then
    self.sprite:change ( 1,  "virus-missile-spin-pink", 1, true )
  else
    self.sprite:change ( 1,  "virus-missile-spin", 1, true )
  end
  self.sprite:change ( 2, nil )

  local vy = math.abs(knockbackY)*1
  vy = vy - vy%0.25 
  self.velocity.vertical.direction  = 1
  self.velocity.vertical.current    = math.min ( -(vy), -2 )
  self.velocity.vertical.update     = true
  local vx = 2

  self.velocity.horizontal.current    = knockbackX > vx and knockbackX or vx
  self.velocity.horizontal.direction  = dir
  self.isReflected                    = true
  
  self.lateUpdate = self._lateUpdate

  self.colliders.collision.HAS_FINISHED_FIRST_TICK = false
  return true
end

function _MISSILE:gravityFreeze ( )
  self:takeDamage ( 1, RNG:rsign(), 2, -2, true )
end

function _MISSILE:manageGrab ( )
  self.isReflected = true
  self.sprite:flip( nil, 1 )
  if self.vertical then
    self.sprite:change ( 1,  "virus-missile-spin-pink", 7, false )
  else
    self.sprite:change ( 1,  "virus-missile-spin", 7, false )
  end
  self.sprite:change ( 2, nil )
end

function _MISSILE:manageReleaseFromGrab ( )
  self.lateUpdate          = self._lateUpdate
  self.velocity.horizontal.current = 2
  if self.vertical then
    self.sprite:change ( 1,  "virus-missile-spin-pink", 4, true )
  else
    self.sprite:change ( 1,  "virus-missile-spin", 4, true )
  end
  return false
end

function _MISSILE:manageThrowFromGrab ( dmg, dir, knockbackX, knockbackY )
  self.lateUpdate          = self._lateUpdate
  self.isIgnoringTiles = false
  self.isReflected = true
  self.isChainedByHookshot = false; 
  if self.vertical then
    self.sprite:change ( 1,  "virus-missile-spin-pink", 1, true )
  else
    self.sprite:change ( 1,  "virus-missile-spin", 1, true )
  end
  if dir < 0 then
    self.sprite:rewind ( 1, true )
  else
    self.sprite:resume ( 1 )
  end
  self:stopShake()

  local vy = math.abs(knockbackY)
  vy = vy - vy%0.25 
  self.velocity.vertical.direction  = 1
  self.velocity.vertical.current    = knockbackY
  self.velocity.vertical.update     = true

  self.velocity.horizontal.current   = math.abs(knockbackX)
  self.velocity.horizontal.direction = dir
  self.updatePhysics                 = true; 
  return true
end

function _MISSILE:_draw()
  if (not self.inserted or self.isDestroyed or self.exploded or self.deleted) then return end
  local l = self.layer()
  self.sprite:draw ( 
    2, 
    math.floor(
      self:getX()+self.spriteOffset.amount*self.spriteOffset.side+self.spriteOffset.x+self.spriteOffset.grabX
    ),
    math.floor(
      self:getY()+self.spriteOffset.y+self.spriteOffset.grabY+self.spriteOffset.verticalAmount*self.spriteOffset.verticalSide
    ), 
    l 
  )
  self.sprite:draw ( 
    1, 
    math.floor(
      self:getX()+self.spriteOffset.amount*self.spriteOffset.side+self.spriteOffset.x+self.spriteOffset.grabX
    ),
    math.floor(
      self:getY()+self.spriteOffset.y+self.spriteOffset.grabY+self.spriteOffset.verticalAmount*self.spriteOffset.verticalSide
    ), 
    l 
  )
end

return _MISSILE