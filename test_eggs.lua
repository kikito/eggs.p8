-- world
local world

--entity constructors
local chick, beast

--systems
local tick, grow, scan, wander, flee, move, hunt, lay, vanish, census, draw

--aux vars & functions
local stats, cpu, pop, maxpop
local thebeast
local phases = { -- how many seconds:
  5,  -- egg,
  7,  -- child,
  6,  -- teen,
  12, -- adult,
  1,  -- corpse
}

local phaseages = {}
local maxage = 0
local corpseage = 0
for i = 1, #phases do
  for _ = 1, phases[i] * 30 do
    add(phaseages, i)
  end
  if i == 5 then
    corpseage = maxage + 1
  end
  maxage += phases[i] * 30
end

local function kill(e)
  e.s = e.s + 16
  e.age = corpseage
  world.unt(e,"alive,vel,laying,prey")
  world.tag(e,"dead")
end

function _init()
  world = eggs()
  stats = true
  cpu = 0
  pop = 0
  maxpop = 0

  chick = function(g, x, y)
    if cpu>=.95 then return end
    g = g or rnd({ "m", "f" })
    local age = age or 1+flr(rnd(120))
    local p = phaseages[age]
    local s = p + (g == "m" and 4 or 0)
    return world.ent("pos,sprite,age,phase,genre,alive", {
      g = g,
      x = x or rnd(120),
      y = y or rnd(120),
      vx = 0,
      vy = 0,
      age = age,
      p = p,
      s = s,
    })
  end

  beast = function()
    return world.ent("pos,vel,sprite", {
      x = rnd(120),
      y = rnd(120),
      vx = 0.5 + rnd(0.5),
      vy = 0.5 + rnd(0.5),
      s = 255,
    })
  end

  tick = world.sys("age", function(e)
    e.age += 1
  end)

  -- change phase according to age, add/remove tags in some phase changes
  grow = world.sys("age,alive,phase,genre,sprite", function(e)
    local np = assert(phaseages[e.age], e.age)
    if np == e.p then return end
    e.p = np
    if np==5 then
      kill(e)
    else
      e.s = np + (e.g == "m" and 4 or 0)
      if np==2 then -- child - start moving
        world.tag(e,"vel")
      elseif np==4 and e.g=="f" then -- female adult - start laying eggs
        world.tag(e,"laying")
      end
    end
  end)

  -- any chickens that are alive and close to the beast are marked as prey
  scan = world.sys("alive,pos", function(e)
    local x0,y0=thebeast.x+4,thebeast.y+4
    local x1,y1=e.x+4,e.y+4
    local dx,dy=x0-x1,y0-y1
    -- calling tag and unt is expensive, the msk variable allows skipping it when not necessary
    local msk=world.msk(e)
    if dx*dx+dy*dy<256 then
      if not msk.prey then
       world.tag(e,"prey")
      end
    elseif msk.prey then
      world.unt(e,"prey")
    end
  end)

  local adhd = { -- velocity variance per phase
    0,   -- egg,
    0.1, -- child,
    0.4, -- teen,
    0.2, -- adult,
    0,   -- corpse
  }
  -- move around randomly
  wander = world.sys("vel,genre,phase", function(e)
    local v = adhd[e.p] + (e.g == "m" and 1 or 0) -- males are more hyperactive
    e.vx = e.vx+rnd(2*v)-v
    e.vy = e.vy+rnd(2*v)-v
  end)

  -- flee from the beast when it is preyby
  flee = world.sys("prey,pos,vel", function(e)
    local x0,y0=thebeast.x+4,thebeast.y+4
    local x1,y1=e.x+4,e.y+4
    local dx,dy=x0-x1,y0-y1
    e.vx=abs(e.vx)*(dx>0 and -1.5 or 1.5)
    e.vy=abs(e.vy)*(dy>0 and -1.5 or 1.5)
  end)

  -- update position according to velocity, bouncing on walls and limiting max speed
  move = world.sys("pos,vel", function(e)
    local x, vx = e.x, e.vx
    vx = x < 0 and abs(vx) or x > 120 and -abs(vx) or vx
    e.vx = mid(-2,vx,2)
    e.x = x + e.vx

    local y, vy = e.y, e.vy
    vy = y < 0 and abs(vy) or y > 120 and -abs(vy) or vy
    e.vy = mid(-2,vy,2)
    e.y = y + e.vy
  end)

  -- kill prey by colliding with them
  hunt = world.sys("prey,pos", function(e)
    local x0,y0=thebeast.x+4,thebeast.y+4
    local x1,y1=e.x+4,e.y+6
    local dx,dy=x0-x1,y0-y1
    if dx*dx+dy*dy<36 then -- centers are closer than 6 px
      kill(e)
    end
  end)

  lay = world.sys("laying,pos", function(e)
    if rnd() > .99 then
      chick(nil, e.x, e.y)
    end
  end)

  vanish = world.sys("dead", function(e)
    if e.age >= maxage then
      world.del(e) -- remove entity from the world
    end
  end)

  -- a system that has no tags ("") will run for every entity in eggs
  local census_sys = world.sys("", function()
    pop += 1
  end)
  -- Wrap systems into container functions in order to do "pre" and "post" actions
  census = function()
    pop = 0
    census_sys()
    if pop > 100 and not thebeast then
      thebeast = beast()
    end
    maxpop = max(maxpop, pop)
  end

  local draw_e = function(e)
    spr(e.s, e.x, e.y, 1, 1, e.vx and e.vx < 0)
    --local msk=world.msk(e)
    --if msk.prey then
    --  circ(e.x+4,e.y+4,6,14)
    --end
  end

  local draw_dead = world.sys("pos,sprite,dead", draw_e)
  local draw_alive = world.sys("pos,sprite,alive", draw_e)

  draw = function()
    draw_dead()
    draw_alive()
    if thebeast then draw_e(thebeast) end
  end

  for x=0,15 do
    for y=0,15 do
      local t=mget(x,y)
      if t==1 then
        chick("f",24+x*5,20+y*5)
      elseif t==5 then
        chick("m",24+x*5,20+y*5)
      end
    end
  end
end

function _update()
  tick()
  grow()
  wander()
  if thebeast then
    scan()
    flee()
  end
  move()
  if thebeast then hunt() end
  lay()
  vanish()
  census()

  if btnp(4) then
    stats = not stats
  end

  if btnp(5) then
    chick()
  end
end

function _draw()
  cls(3)

  draw()

  cpu = stat(1)
  if stats then
    color(12)
    local f="\^o140"
    print(f .. "pop:" .. pop .. "/" .. maxpop, 1, 110)
    print(f .. "cpu:" .. flr(cpu * 10000)/100 .. "%", 1, 116)
    print(f .. "mem:" .. flr(stat(0)*100)/100 .. "kib", 1, 122)
    print(f .. "❎:lay", 90,116)
    print(f .. "🅾️:toggle", 90,122)
  end
end
