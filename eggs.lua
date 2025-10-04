do
 local function oadd(arr,x)
  local l,r,m=1,#arr,nil
  while l<=r do
   m=(l+r)\2
   if arr[m]<x then l=m+1 else r=m-1 end
  end
  add(arr,x,l)
 end

 local function mkmsk(tags)
  local msk,ts={},tags=="" and {} or split(tags)
  for i=1,#ts do msk[ts[i]]=true end
  return msk
 end

 local function mkid(msk)
  local a={}
  for t in pairs(msk) do oadd(a,t) end
  local id=a[1] or ""
  for i=2,#a do id..=","..a[i] end
  return id
 end

 local function link(filt,col)
  local em=col.msk
  for k in pairs(filt.msk) do
   if not em[k] then return end
  end
  filt.cols[col]=true
 end

_ENV.eggs=function()
 local tids,cols,filts,e2col={},{},{},{}

 local function mkcol(id)
  local col={id=id,msk=mkmsk(id),n=0}
  for _,filt in pairs(filts) do link(filt,col) end
  return col
 end

 local function mkfilt(id)
  local filt={cols={},msk=mkmsk(id)}
  for _,col in pairs(cols) do link(filt,col) end
  return filt
 end

 local function ent(tags,e)
  assert(not e2col[e], "entity already exists")
  tids[tags]=tids[tags] or mkid(mkmsk(tags))
  local id=tids[tags]
  cols[id]=cols[id] or mkcol(id)
  local col=cols[id]
  col.n+=1
  local n=col.n
  col[e],col[n]=n,e
  e2col[e]=col
  return e
 end

 local function edel(e)
  local col=e2col[e]
  if not col then return end
  local i,n=col[e],col.n
  if i<n then
   local last=col[n]
   col[last],col[i]=i,last
  end
  col[e],col[n],col.n=nil,nil,n-1
  e2col[e]=nil
 end

 return {
  ent = ent,
  del = edel,
  sys = function(tags,fn)
   tids[tags]=tids[tags] or mkid(mkmsk(tags))
   local id=tids[tags]
   filts[id]=filts[id] or mkfilt(id)
   local fcols=filts[id].cols
   return function()
    for col in pairs(fcols) do
     for i=col.n,1,-1 do
      fn(col[i])
     end
    end
   end
  end,
  msk = function(e)
   local col=e2col[e]
   return col and col.msk
  end,
  tag = function(e,tags)
   local col=e2col[e]
   if not col or tags =="" then return end
   if col.id~="" then
    tags..=","..col.id
   end
   edel(e)
   ent(tags,e)
  end,
  unt = function(e,tags)
   local col=e2col[e]
   if not col or tags=="" then return end
   local msk,ts={},split(tags)
   for t in pairs(col.msk) do msk[t]=true end
   for i=1,#ts do msk[ts[i]]=nil end
   tags=""
   for t in pairs(msk) do
    tags=tags=="" and t or tags..","..t
   end
   edel(e)
   ent(tags,e)
  end,
 }
end
end
