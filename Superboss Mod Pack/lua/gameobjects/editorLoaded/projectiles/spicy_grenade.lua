-- [VIRUS ENGINEER GRENADE]
local _GRENADE = BaseObject:subclass ( "VIRUS_ENGINEER_GRENADE")
Mixins:attach ( _GRENADE, "particleSpawning"  )
Mixins:attach ( _GRENADE, "applyPhysics"      )
Mixins:attach ( _GRENADE, "shake"             )
Mixins:attach ( _GRENADE, "grabObject"        )
Mixins:attach ( _GRENADE, "pullObject"        )

_GRENADE.static.USES_POOLING          = true
_GRENADE.static.HAS_DESPAWN_MECHANISM = true
_GRENADE.static.NO_DATA_CHIP          = true

_GRENADE.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles" )
end

_GRENADE.static.DIMENSIONS = {
  x = 3,
  y = 3,
  w = 10,
  h = 10,
  vx  =   0,
  vy  =   0,

  grabPosX = -1,
  grabPosY =  9,
}

_GRENADE.static.PROPERTIES = {
  isHittableProjectile  = false,
  isDamaging            = true,
  isBulletType          = true,
  isEnergyless          = true,
} 

_GRENADE.static.FILTERS = {
  collision = Filters:get ( "bulletFilter"          ),
  explosion = Filters:get ( "queryExplosionFilter"  ),
}

_GRENADE.static.LAYERS = {
  sprite    = Layer:get ( "ENEMIES", "PROJECTILES") ,
  particles = Layer:get ( "PARTICLES" )
}

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Initialize ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _GRENADE:finalize ( direction )

  self.sprite = Sprite:new ( SPRITE_FOLDERS.projectiles, "projectiles", 1 )
  

  self:addCollider ( "collision", self.dimensions.x,     self.dimensions.y,   self.dimensions.w,    self.dimensions.h, self.properties )
  self:addCollider ( "grabbox",   self.dimensions.x-8,   self.dimensions.y-8, self.dimensions.w+16, self.dimensions.h+16, self.class.GRABBOX_PROPERTIES )
  self:addCollider ( "grabbed",   self.dimensions.x,     self.dimensions.y,   self.dimensions.w,    self.dimensions.h )

  self.explosionSensor = Sensor:new ( self, self.filters.explosion, -18, -18, 15+self.dimensions.w, 15+self.dimensions.h )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Reset --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _GRENADE:reset ( direction, biggerArc  )
  self.sprite:change ( 1, "virus-engineer-grenade", 1, true )
  self:insertCollider ( "collision" )
  self:insertCollider ( "grabbox"   )
  self:insertCollider ( "grabbed"   )

  self.deleted      = false
  self.exploded     = false
  self.isReflected  = false

  if not self.explosionHitTable then
    self.explosionHitTable = {}
  else
    cleanTable(self.explosionHitTable)
  end

  local px = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
  local vx = 0

  if biggerArc then
    vx = 6
    if px then
      vx = math.abs(self:getX() - px)/43
      vx = math.min(vx - vx%0.25,6)
      if vx < 1 then
        vx = 1
      end
    end
  else
    vx = 3
    if px then
      vx = math.abs(self:getX() - px)/38
      vx = math.min(vx - vx%0.25,3.75)
      if vx < 1 then
        vx = 1
      end
    end
  end

  self.velocity.horizontal.current    = vx
  self.velocity.horizontal.direction  = direction
  self.velocity.vertical.current      = biggerArc and -6 or -4

  self.sprite:flip(direction < 0 and -1 or 1, 1 ) 

  self.updatePhysics = true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Rest ---------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _GRENADE:lateUpdate(dt)
  local x, y = self:getPos()
  if not Camera:isWithinView ( x, y, 96 ) then
    self:delete()
    return
  end

  if self.exploded then

    local hit, cols, len = self.explosionSensor:check()
    if hit then
      local other
      for i = 1, len do
        other = cols[i]
        if other and (other.isPlayer or other.isEnemy) and not self.explosionHitTable[other.ID] then
          if self:callObserver(other) then
            self.explosionHitTable[other.ID] = true
            self.timer = 0
          end
        end
      end
    end

    if self.timer > 0 then
      self.timer = self.timer - 1
    else
      self:delete()
    end
    return
  end

  self.sprite:update  ()
  self:updateShake    ()
  
  self:applyPhysics()

  if self.exploded then
    Audio:playSound ( SFX.gameplay_enemy_projectile_explosion )
    self:removeCollidersFromPhysicalWorld ( )
    self.timer = 5
    --self:addExplosion ( "small_orange_explosion" )
    local mx, my = self:getMiddlePoint("collision")
    mx, my = mx+2, my-2
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.7, 0.8 )
  end
end

function _GRENADE:callObserver (obj)
  if not (obj.isPlayer or obj.isEnemy or obj.isBreakable) then return end
  if obj.isPlayer then
    if not self.isReflected then
      return GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", self.velocity.horizontal.direction )
    end
  elseif (self.isReflected or obj.isTile) and obj  then
    if (obj.parent and obj.parent.takeDamage and not self.explosionHitTable[obj.parent.ID] ) then
      --local dmg = obj.parent.IS_FINAL_BOSS and GAMEDATA.damageTypes.COLLISION_REDUCED_MINIMAL or GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE
      local dmg = obj.parent.IS_FINAL_BOSS and GAMEDATA.damageTypes.COLLISION_REDUCED or GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE
      if obj.parent.IS_FINAL_BOSS then
        Challenges.unlock ( Achievements.RETURN_TO_BOSS )
      end
      if obj.parent:takeDamage (dmg, self.velocity.horizontal.direction, 2, 0, "grenade") then
        self.explosionHitTable[obj.parent.ID] = true
        return true
      end
    end
  end
end

function _GRENADE:handleCollisions ( colsX, lenX, colsY, lenY )
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

function _GRENADE:handleBulletBlock ()
  self.exploded = true
end

function _GRENADE:draw()
  if self.deleted or self.exploded then return end

  local l = self.layers.sprite()
  self.sprite:draw ( 1, math.floor(self:getX()+self.spriteOffset.amount*self.spriteOffset.side+self.spriteOffset.x+self.spriteOffset.grabX), math.floor(self:getY()+self.spriteOffset.y+self.spriteOffset.grabY), l )
end

function _GRENADE:takeDamage ( dmg, dir, knockbackX, knockbackY, attackType )
  Audio:playSound ( SFX.gameplay_punch_hit_reflect )

  dir = dir or -self.velocity.horizontal.direction
  if math.abs(dir) < 1 then
    dir = RNG:rsign()
  end
  knockbackX = knockbackX or 2
  knockbackY = knockbackY or -3

  local vy = math.abs(knockbackY)*1
  vy = vy - vy%0.25 
  self.velocity.vertical.current = -(vy)
  local vx = math.max( self.velocity.horizontal.current - 0.25, 1 )

  self.velocity.horizontal.current   = knockbackX > vx and knockbackX or vx
  self.velocity.horizontal.direction = dir
  self.sprite:flip(dir)
  self.isReflected = true
  return true
end 

function _GRENADE:chain ( )
  self.updatePhysics       = false
  self.isChainedByHookshot = true
  self.sprite:stop(1)
  self:applyShake(3)
  return true
end

function _GRENADE:isSuplexable ( )
  return false
end

function _GRENADE:drawSpecialCollisions () 
  self.explosionSensor:draw ( )
end

function _GRENADE:isGrabbable ()
  return false
end

function _GRENADE:manageThrowFromGrab ( dmg, dir, knockbackX, knockbackY )
  self.isReflected = true
  self.isChainedByHookshot = false; 
  self.sprite:resume(1)
  self:stopShake()

  local vy = math.abs(knockbackY)
  vy = vy - vy%0.25 
  self.velocity.vertical.current = knockbackY

  self.velocity.horizontal.current   = math.abs(knockbackX)
  self.velocity.horizontal.direction = dir
  self.sprite:flip(dir)
  self.updatePhysics = true; 
  return true
end


return _GRENADE