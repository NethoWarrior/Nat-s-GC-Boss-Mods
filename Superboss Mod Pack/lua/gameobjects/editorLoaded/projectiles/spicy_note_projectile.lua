-- [WaveNoteProjectile]
local _NOTE = BaseObject:subclass ( "WAVE_NOTE_PROJECTILE")
Mixins:attach ( _NOTE, "particleSpawning"  )
Mixins:attach ( _NOTE, "applyPhysics"      )
Mixins:attach ( _NOTE, "shake"             )
Mixins:attach ( _NOTE, "grabObject"        )
Mixins:attach ( _NOTE, "pullObject"        )

_NOTE.static.USES_POOLING          = true
_NOTE.static.HAS_DESPAWN_MECHANISM = true
_NOTE.static.NO_DATA_CHIP          = true
hits = 1

_NOTE.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles" )
end

_NOTE.static.DIMENSIONS = {
  x         =  3,
  y         =  3,
  w         = 10,
  h         = 10,
  vx        =  0,
  vy        =  0,
  grabPosX  = -1,
  grabPosY  =  9,
}

_NOTE.static.PROPERTIES = {
  isHittableProjectile  = true,
  isDamaging            = true,
  isBulletType          = true,
  isEnergyless          = true,
  isBouncingProjectile  = true,

  --isObjectWithSimpleMovement = true,
} 

_NOTE.static.FILTERS = {
  collision = Filters:get ( "bulletFilter"          ),
  explosion = Filters:get ( "queryExplosionFilter"  ),
}

_NOTE.static.LAYERS = {
  sprite = Layer:get( "ENEMIES", "PROJECTILES") ,
  particles = Layer:get ( "PARTICLES" )
}

_NOTE.static.RING_OFFSETS = {
  [1]   = { 8, 8 },
  [-1]  = { 7, 8 },
}

_NOTE.static.ANIMATIONS = {
  [1] = {
    spawn  = "wave-note-projectile-spawn",
    bounce = "wave-note-projectile",
    blow   = "wave-note-projectile-blow-up",
  },
  [2] = {
    spawn  = "wave-note-projectile-spawn-green",
    bounce = "wave-note-projectile-green",
    blow   = "wave-note-projectile-blow-up-green",
  },
}

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Initialize ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NOTE:finalize ( direction )
  self.contactType       = "cross"
  self.playerContactType = "cross"

  self.rings = {}
  for i = 1, 4 do
    self.rings[i] = {}
    self.rings[i].d       = 2.4
    self.rings[i].w       = 4
    self.rings[i].tween   = Tween.new ( 16, self.rings[i], { d = 25, w = 0.4 }, "outQuad" )
    self.rings[i].started = false
  end

  self.sprite = Sprite:new ( SPRITE_FOLDERS.projectiles, "projectiles", 1 )
  --self.sprite:change ( 1, "wave-note-projectile-spawn" )

  self:addCollider ( "collision", self.dimensions.x,     self.dimensions.y,   self.dimensions.w,    self.dimensions.h, self.properties )
  self:addCollider ( "grabbox",   self.dimensions.x-8,   self.dimensions.y-8, self.dimensions.w+16, self.dimensions.h+16, self.class.GRABBOX_PROPERTIES )
  self:addCollider ( "grabbed",   self.dimensions.x,     self.dimensions.y,   self.dimensions.w,    self.dimensions.h )

  self.explosionSensor         = Sensor:new ( self, self.filters.explosion, -18, -18, 15+self.dimensions.w, 15+self.dimensions.h )
  self.isNotBonkingSpeedBasher = true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Reset --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_NOTE.static.MAX_BOUNCE_HEIGHT = {-10.75, -9.5, -8.25, -9.5, -10.75, -8.25}
local last = 0

function _NOTE:reset ( direction, vertSpeed, horiSpeed, anim )
  self.anims = self.class.ANIMATIONS[anim or 1]

  local now = RNG:range(1,#self.class.MAX_BOUNCE_HEIGHT)
  if now == last then
    now = now + RNG:range(1,2)
    if now > #self.class.MAX_BOUNCE_HEIGHT then
      now = now - #self.class.MAX_BOUNCE_HEIGHT
    end
  end
  last = now
  self.bounceHeight = -8.0 --self.class.MAX_BOUNCE_HEIGHT[now]

  for i = 1, 4 do
    self.rings[i].timer    = (i-1) * 7
    self.rings[i].started  = false
    self.rings[i].finished = false
    self.rings[i].tween:reset()
  end
  self.sprite:change ( 1, self.anims.spawn, 1, true )

  self.inserted     = false
  self.deleted      = false
  self.exploded     = false
  self.setToExplode = false

  if not self.explosionHitTable then
    self.explosionHitTable = {}
  else
    cleanTable(self.explosionHitTable)
  end

  if Camera:inView ( self, 32 ) then
    Audio:playSound ( SFX.gameplay_medley_note_throw )
  end

  self.velocity.horizontal.current    = horiSpeed or 0
  self.velocity.horizontal.direction  = direction
  self.velocity.vertical.current      = vertSpeed or 0
  self.sprite:flip(direction < 0 and -1 or 1, 1 ) 

  self.updatePhysics = true
end

function _NOTE:setBounceHeight ( num )
  self.bounceHeight = -num
  return self
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Rest ---------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NOTE:lateUpdate(dt)
  local x, y = self:getPos()
  if not Camera:isWithinView ( x, y, 96 ) then
    self:delete()
    return
  end

  if not self.inserted then
    if self.sprite:getFrame() >= 6 then
      self.inserted = true
      self:insertCollider ( "collision" )
      self:insertCollider ( "grabbox"   )
      self:insertCollider ( "grabbed"   )
    else
      self.sprite:update()
      return
    end
  end

  self.sprite:update  ( )
  self:updateShake    ( )

  if self.setToExplode then

    if self.rings[1].tween:getTime() > 0.25 and self.rings[3].tween:getTime () < 0.85 then
      local hit, cols, len = self.explosionSensor:check()
      if hit then
        for i = 1, len do
          if cols[i].isPlayer then
            GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.MEDIUM_PROJECTILE, "weak" )
          elseif cols[i].isHookshot then
            if (cols[i].isPlayerHookshot and cols[i].parent.isAttached) then
              cols[i].parent.parent:breakHookshotSwing()
            end
          else
            -- ...
          end
        end
      end
    end

    for i = 1, 3 do
      if self.rings[i].started and not self.rings[i].finished then
        if self.rings[i].tween:update(1) then
          self.rings[i].finished = true
        end
      end

      if not self.rings[i].started then
        self.rings[i].timer = self.rings[i].timer - 1
        if self.rings[i].timer == 0 then
          self.rings[i].started = true
        end
      end
    end

    if self.rings[3].tween:isFinished() then
      self:delete()
    end
    return
  end
  
  self:applyPhysics()

  if self.exploded then
    if Camera:inView ( self, 32 ) then
      Audio:playSound ( SFX.gameplay_medley_note_bounce_2 )
    end
    self.sprite:change ( 1, self.anims.blow, 1, true )
    self.timer        = 30
    self.setToExplode = true
    self:removeCollidersFromPhysicalWorld ( )
  end
end

function _NOTE:callObserver (obj,x)
  if not (obj.isPlayer or obj.isEnemy or obj.isBreakable) then 
    if obj.isRotatingSpikeBlockObject and obj.parent and obj.parent.forceSpikesOut then
      obj.parent:forceSpikesOut ( x, self.velocity.horizontal.direction, self.velocity.vertical.current )
    elseif obj.isMovingPlatform and obj.parent.triggerWalkOver then
      obj.parent:triggerWalkOver()
    end
    return 
  end
  if obj.isPlayer then
    if not self.isReflected then
      self.exploded = true
      return GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.MEDIUM_PROJECTILE, "weak", self.velocity.horizontal.direction )
    end
  elseif obj then
    if (obj.parent and obj.parent.takeDamage and not self.explosionHitTable[obj.parent.ID] ) then
      if obj.parent:takeDamage (GAMEDATA.damageTypes.MEDIUM_PROJECTILE, self.velocity.horizontal.direction, 2, 0, "grenade") then
        self.explosionHitTable[obj.parent.ID] = true
        return true
      end
    end
  end
end

function _NOTE:handleCollisions ( colsX, lenX, colsY, lenY )
  for i = 1, lenX do
    if self:callObserver(colsX[i].other,true) then
      self.exploded = true
    end
  end

  for i = 1, lenY do
    if self:callObserver(colsY[i].other,false) then
      self.exploded = true
    end
  end
end

function _NOTE:applyLaunch ( speedX, speedY )
  if (speedX ~= 0) or speedY >= 0 then
    self.exploded = true
    return
  end

  if Camera:inView ( self, 32 ) then
    Audio:playSound ( SFX.gameplay_medley_note_bounce )
  end
  self.velocity.vertical.current      = -6.75
  self.bounceHeight                   = -6.75 
  self.velocity.horizontal.current    = 1.5
  self.velocity.horizontal.direction  = -self.sprite:getScaleX()
end

function _NOTE:handleYBlock ()
  if self.velocity.vertical.current > 0 then
    if Camera:isObjectInView ( self, 16 ) then
      Audio:playSound ( SFX.gameplay_medley_note_bounce )
    end

    self.sprite:change ( 1, self.anims.bounce, 1, true )
    self.velocity.vertical.current     = self.bounceHeight---4.5
    self.velocity.horizontal.current   = 1.5
    self.velocity.horizontal.direction = -self.sprite:getScaleX()
  else
    self.exploded = true
  end
end

function _NOTE:handleXBlock ()
  self.exploded = true
end

function _NOTE:draw()
  if self.deleted then return end

  local x,y     = self:getPos()
  local l       = self.layers.particles()
  local ox, oy  = self.class.RING_OFFSETS[-self.sprite:getScaleX()][1], self.class.RING_OFFSETS[-self.sprite:getScaleX()][2]
  for i = 1, 3 do
    if self.rings[i].started and self.rings[i].w > 0.75 then
      GFX:push ( l, love.graphics.setLineWidth, self.rings[i].w )
      GFX:push ( l, love.graphics.circle, "line", x+ox, y+oy, self.rings[i].d )
      GFX:push ( l, love.graphics.setLineWidth, 1 )
    end
  end

  self.sprite:draw ( 1, math.floor(self:getX()+self.spriteOffset.amount*self.spriteOffset.side+self.spriteOffset.x+self.spriteOffset.grabX), math.floor(self:getY()+self.spriteOffset.y+self.spriteOffset.grabY), self.layers.sprite() )
end

function _NOTE:takeDamage ( dmg, dir, knockbackX, knockbackY, attackType )
  if self.exploded then
    return false
  end
  hits = hits + 1

  Audio:playSound ( SFX.gameplay_punch_hit_reflect )
  if hits == 3 then
    self.velocity.vertical.current   = 0
    self.velocity.horizontal.current = 0

    self.updatePhysics = false
    self.exploded      = true
    return true
  end
end 

function _NOTE:chain ( )
  self:takeDamage ( )
  return false
end

function _NOTE:isSuplexable ( )
  return false
end

function _NOTE:drawSpecialCollisions () 
  self.explosionSensor:draw ( )
end

function _NOTE:isGrabbable ()
  return false
end

function _NOTE:pull ()
  return false
end

return _NOTE