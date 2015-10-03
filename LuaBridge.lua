--
-- Objective-C Classes
--

-- Send Objective-C Messages 
function sendMesg (target, selector, ...)
   local to_send = {}
   local n = select("#", ...)
   for i = 1, n do
      local arg = select(-i, ...)

      -- If this is a wrapped object, then send what is in the wrapper
      arg = unwrap(arg)
      table.insert(to_send, arg)
   end
   
   table.insert(to_send, target)
   table.insert(to_send, selector)
   
   return objc.call(to_send)
end

local method_mt = {
  __tostring = function(o)
      return "<"..(o.name).." on "..tostring(o.target)..">"
  end,
  __call = function (o, target, ...)
    -- Having an explicit target here (even though we know the target)
    -- allows us to use Lua-like "foo:bar()" syntax
    local ret = sendMesg(unwrap(target), o.name, ...)
    if type(ret) == "userdata" then
      return wrap(ret)
    else
      return ret
    end
  end,

}

local object_mt ={
  __tostring = function (o)
    return "<"..(o.Class)..">"
  end,
  __index = function(inObject, inKey)
    local p = objc.getproperty(unwrap(inObject), inKey)
    if p then return p end
    inKey = inKey:gsub("_",":")
    p = objc.hasmethod(unwrap(inObject), inKey)
    if p then
      p = { name = inKey, target = inObject }
      setmetatable(p, method_mt)
      return p
    end
  end,
  __newindex =  function(inObject, inKey, inValue)
    if (objc.getproperty(unwrap(inObject), inKey)) then
        return sendMesg(inObject["WrappedObject"], 'setValue:forKeyPath:', inValue, inKey)
    end
    rawset(inObject, inKey, inValue)
  end
}

-- Wrap Objective-C Pointers
function wrap(obj)
    local o = {}
    o["WrappedObject"] = obj;
    o["Class"] = objc.classof(obj);
    setmetatable(o, object_mt)
    return o
end

-- Unwrap Objective-C Pointers
function unwrap(obj)
  if type(obj) == "table" then
      if obj["WrappedObject"] ~= nil then
        return obj["WrappedObject"]
      end
  end

  return obj
end

-- Looks for Objective-C class if variable is not found in global space
function getUnknownVariable(tbl, key)
    local cls = objc.getclass(key)
    if cls then
        cls = wrap(cls)
        tbl[key] = cls
        return cls
    end
end


setmetatable(_G, {__index=getUnknownVariable})
