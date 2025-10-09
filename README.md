# eggs.p8

A pseudo-[ECS](https://en.wikipedia.org/wiki/Entity_component_system) library for [PICO-8](https://www.lexaloffle.com/pico-8.php).


## Core concepts

This library has 3 main concepts: entities, tags and systems.

* Entities are Lua tables with zero or more tags associated to them. They represent your game objects. They contain data (like coordinates, health, etc) but no behavior (no functions)
* Tags are just strings.
* Systems are lua functions that operate on entities with specific tags.

That's the gist of it. On a pure ECS system you would have entities built of "Components", with the systems acting on the components themselves instead of on the entities. I found that approach didn't "go well" with Lua so I tried to do 2/3rds of it instead, cutting components almost completely until only the tags survived.

## Quick "Eggsample"

``` lua
#include eggs.lua

local world,redmovesright,bluemovesleft,draw

function _init()
  local world = eggs()

  -- system to move entities tagged "red" and "mov" to the right
  redmovesright= world.sys("red,mov",function(e)
    e.x = (e.x + 1)%128
  end)

  -- system to move entities tagged "blue" and "mov" to the left
  bluemovesleft= world.sys("blue,mov",function(e)
    e.x = (e.x - 1)%128
  end)

  -- system to draw all entities 
  draw= world.sys("",function(e)
    circ(e.x,e.y,5,e.color)
  end)

  world.ent("blue,mov",{x=64,y=60,color=12}) -- will move left
  world.ent("red,mov",{x=64,y=90,color=8}) -- will move right
  world.ent("blue", {x=64,y=30,color=12}) -- will not move (no mov tag)
  world.ent("yellow", {x=64,y=20,color=10}) -- also will not move (no mov, no red or blue)
end

function _update()
  -- call move systems
  redmovesright()
  bluemovesleft()
end

function _draw()
  cls()
  -- call draw system
  draw()
end
```

Please see the following cardridge ([source code](https://github.com/kikito/eggs.p8/blob/main/test_eggs.lua)) for a more advance example: 

[![eggs](https://raw.githubusercontent.com/kikito/eggs.p8/refs/heads/main/test_eggs.p8.png)](https://www.lexaloffle.com/bbs/cart_info.php?cid=test_eggs-0)


## API

### Creating a world

``` lua
local world = eggs()
```

The `eggs` function takes no arguments and returns a new world object. You can create multiple worlds if you need to, but usually one is enough.


### Adding entities to the world

``` lua
local entity = world.ent(tags, obj)
```

Adds an entity to the world. Entities will be filtered by systems based on their tags.

#### Parameters

* `tags`: A string with zero or more comma-separated tags.
* `obj`: A table. There is no restriction on the contents of the table, it can be an empty table. It is however recommended that the contents have some relationship with the tags.

#### Returns

* `entity`: It is literally a reference to `obj`, added for convenience.

#### Example

``` lua
local player = world.ent("player,movable,solid", {x=0,y=0})
```

#### Notes

* Note that instead of using `:`, we use `.` for world methods. This is a token-saving decision.
* `world.ent()` will throw an error if `obj` is an entity that has already been inserted in the world.
* It is very important that `obj` is a table. The library will not check for this. However it will not work properly if you add non-table elements. In particular, numbers and string might behave unexpectedly.


### Adding systems to the world

``` lua
local system = world.sys(tags, fn)
```

Adds a system to the world. The system needs to be invoked (usually from `_update` or `_draw`) to operate on the entities. It will only operate on entities with the specified tags.

#### Parameters

* `tags`: A string with zero or more comma-separated tags. A system with an empty (`""`) `tags` parameter will operate on all entities in the world.
* `fn`: A function that will be called on each entity that matches the tags. The function takes a single parameter, which is the entity table.

#### Returns

* `system`: A function that will invoke `fn` in all the entities that match the specified tags.

#### Example

``` lua
-- definition (usually in _init):
grow_old = world.sys("living", function(e)
  e.age = e.age + 1
end)

-- invocation (usually in _update):
grow_old()
```

#### Notes

It is not possible to remove systems from the world once they have been added. If you need to deactivate a system, use an `if` to not call it:

``` lua
if some_condition then
  grow_old()
end
```

If you need to do some work before or after the system runs, you can wrap it in another function:

``` lua
-- definition
local grow_old_sys = world.sys("living", function(e)
  e.age = e.age + 1
end)

local grow_old = function()
  initialize_some_age_related_things()
  grow_old_sys()
  finalize_some_age_related_things()
end)

-- usage:
grow_old() -- will do initialization and finalization
```

The order in which systems process entities is undefined. If you need to process entities in a specific order, you have two options: collect them in a sorted array and then process them in order, or do several systems that process the entities in groups.

Here's how it looks like to collect entities in a sorted array and then process them in order:

``` lua
-- definitions

-- given two entities, determine which one goes first by looking at their y coordinate
local draw_order = function(a,b) return a.y < b.y end
local draw_buf={}
local collect_drawables = world.sys("drawable", function(e)
  -- insert the entity on the right place using oadd.
  -- See https://www.lexaloffle.com/bbs/?pid=oadddemo-0
  oadd(draw_buf, e, draw_order)
end)

local draw_entities = function()
  draw_buf={} -- intialization
  collect_drawables()
  for i=1,#draw_buf do
    local e = draw_buf[i]
    -- draw entity e
    spr(e.spr,e.x,e.y)
  end
end

-- usage (in _draw):
draw_entities()
```

A simpler, probably faster but less flexible way is to have the entities tagged in a way that makes it possible to process them in groups. The following example will draw everything that is tagged "background" first, then everything tagged "middleground", and finally everything tagged "foreground":

``` lua
--- definitions
local function draw_entity(e)
  spr(e.spr,e.x,e.y)
end

local draw_background = world.sys("drawable,background", draw_entity)
local draw_middleground = world.sys("drawable,middleground", draw_entity)
local draw_foreground = world.sys("drawable,foreground", draw_entity)

local draw_all = function()
  draw_background()
  draw_middleground()
  draw_foreground()
end

-- usage (in _draw):
draw_all()
```

### Removing entities from the world

``` lua
world.del(entity)
```

Removes the given entity from the world. It will no longer be processed by systems.

#### Parameters

* `entity`: the table to be removed. If the entity does not exist in the world, the function will silently exit, doing nothing.

#### Example

``` lua
world.del(killed_enemy)
```

#### Notes

The most usual place when one will want to remove an entity is from inside a system. This is is ok:

``` lua
-- Definitions
grow_older = world.sys("living", function(e)
  e.age = e.age + 1
end)

remove_old = world.sys("living", function(e)
  if e.age > 100 then
    world.del(e)
  end
end)

-- usage
grow_older()
remove_old()
```

Removing entities from the world is done in a safe and efficient way, but it involves changing the order in which entities are processed by systems (every time an entity is removed, the lists will be slightly shuffled). This is why there's no guarantees about order of processing in systems.

### Adding additional tags to an entity

``` lua
world.tag(entity, tags)
```

Adds new tags to an entity.

#### Parameters

* `entity`: the entity being given new tags.
* `tags`: a string with one or more comma-separated tags to be added to the entity.

#### Returns

Nothing

#### Example

``` lua
world.tag(player, "invincible")
```

#### Notes

If an entity already has a tag that is being added, it will be ignored (there will be no duplicate tags). However, calling world.tag is expensive since at the very least it involves splitting the `tags` string into an array of strings, and then parsing them, potentially creating a new internal collection of entities to which the entity needs to be moved to.

You can use the `world.msk` method to check if an entity already has a tag before calling `world.tags` (see the notes section in `world.msk` below).

Given that `world.tag` is expensive, you should avoid using it on systems that will parse a big number of entities.

Example of bad usage:

``` lua
local retag_all_entities = world.sys("", function(e)
  if some_condition then
    world.tag(e, "some_new_tag")
  else
    world.tag(e, "some_other_new_tag")
  end
end)
```

This is a system that will parse all entities and will *always* change their tags (both sides of the `if` call `world.tag`. It will be very slow and inefficient.

Example of a good usage:

``` lua
local kill_close_enemies = world.sys("enemy,close", function(enemy)
  if enemy.hp <= 0 then
    world.tag(enemy, "dead")
  end
end)
```

This is better because it will only parse over entities that are tagged both "enemy" and "close", which should be a smaller set than all entities. Also, it will only call `world.tag` on some of them (those that are close and have no hp left).

This can be further optimized by using  `world.msk` to check if an entity has a tag before calling `world.tag` (see the notes section in `world.msk` below)

``` lua
local kill_close_enemies = world.sys("enemy,close", function(enemy)
  if enemy.hp <= 0 then
    local msk = world.msk(enemy)
    if not msk.dead then
      world.tag(enemy, "dead")
    end
  end
end)
```

### Removing tags from an entity

``` lua
world.unt(entity, tags)
```

This is the opposite of `world.tag` - it removes tags from an entity

#### Parameters

* `entity`: The entity from which tags will be removed.
* `tags`: A string with one or more comma-separated tags to be removed from the entity.

#### Returns

Nothing

#### Example

``` lua
world.unt(player, "invincible")
```

#### Notes

Attempting to remove a tag that the entity does not have will be ignored (no error will be thrown). However, similarly to `world.tag`, calling `world.unt` is expensive and should be avoided if possible. The same precautions that apply to `world.tag` apply also to `world.unt`:
* Try to modify few entities at a time by using it on systems that filter entities by tags and ten only remove tags from some of them
* Use `world.msk` to check if an entity has a tag before attempting to remove it.

``` lua
local reanimate_close_dead_enemies = world.sys("enemy,close,dead", function(enemy)
  local msk = world.msk(enemy)
  if not msk.undead then
    world.unt(enemy, "undead")
  end
end)
```

### Get all the tags of an entity

``` lua
local msk = world.msk(entity)
```

Returns a table with all the tags of an entity as keys.

#### Parameters

* `entity`: The entity whose tags will be returned.

#### Returns

* `msk`: A table with the tags of the entity as keys, and `true` as value.

#### Example

``` lua
local msk = world.msk(player)
```

#### Notes

** Do not modify the returned table! **. For efficiency reasons, `msk` is a table that is used for internal calculations inside the library. If you need to modify it, please make a copy before and modify that instead.

In general you should not need to use `world.msk` except for the case where checking that the entity already has (or does not have) a tag before calling `world.tag` or `world.unt`, as explained in the notes sections of those methods. In any other case, if you need to do something like this:

``` lua
local msk = world.msk(player)
if msk.invincible then
  .. do something special
end
```

That is probably a system hiding inside your code. There is probably a way to rewrite it like this:

``` lua
local invincible_system = world.sys("invincible", function(e)
  .. do something with e, which now can be any entity tagged invincible, not just `player`
end)
```

## Preemtive FAQ

> How many tokens does eggs use?

The library weights around 569 tokens. It has no comments and very few blank lines, but it could be minimized. If you are already using `oadd` in your project you could also remove the internal `oadd` implementation and replace it on the `mkid` function in order to save some tokens.

> How does it work?

Internally, the library groups entities into "collections" (also known as "archetypes") according to their tags. There is also a collection of "filters", each of which has a "collection of collections", that it knows it needs to parse every time their system is invoked.

Collections and filters are indexed by their "identifier", which is the set of tags that define them, sorted alphabetically. Two systems using the same set of tags will share the same filter. Two entities with the same set of tags will use the same collection.

Each time a new archetype is added, it checks all of the existing filters and adds himself to their "collection of collections" if the tags match. Similarly, when a system is added, its filter will check all of the existing archetypes and add to its "collection of collections" those that match.

Each time an entity's tags are modified, it will be removed from its current collection and added to the appropriate one (which is created on the spot if it doesn't exist).

> Why not use binary masks for tags instead of strings?

That was my first idea. Tags used to look like this:

``` lua
local pos,vel,spr=1,1<<1,1<<2

...

move = world.system(pos|vel, function(e)
  ...
end)
```

But unfortunately PICO-8 has [a 32 bit number format](https://pico-8.fandom.com/wiki/Math). So if I went that route my library would be limited to 32 tags at maximum. On my test_eggs example, which is very simple, I already used 10. I realized very quickly that any videogame that was even only slightly complex would need more than 32. So the advantages of using binary started being less interesting - I would have to implement "bitmask" objects, grouping several numbers together, and using tables with metatables for the bitwise operations and ... well I stopped there.

PICO-8 already has a built-in `split` function, so strings are more economical in terms of tokens. The price is performance. Strings need to be split and sorted in order to be used as ids; hence all of the warnings about not using `world.tag` and `world.unt` in excess.

Tags have an advante over bitmasks, in that they are much more human-readable. `eggs`'s internal collections are indexed by things like `"age,health,pos"` instead of `0x0007`, which makes debugging easier.

On Picotron, there's this feature called [userdata](https://www.lexaloffle.com/dl/docs/picotron_userdata.html) that could be used to implement bitmasks in a better way, but that is not available in PICO-8.

> Why is it called eggs? Shouldn't it be ETS (Entity Tag System)?

Because I find the name "eggs" funny. It sounds similar to trying to pronounce "ECS" as if it was a word. I considered calling it "Filters, Actors and Tags", but that didn't go well with the cuteness of PICO-8.

At least I didn't call tags "ggomponents".
