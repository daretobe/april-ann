autodiff    = autodiff or {}
autodiff.op = autodiff.op or {}

------------------------------------------------------------------------------

local CONSTANT = 'constant'
local SCALAR   = 'scalar'
local MATRIX   = 'matrix'

------------------------------------------------------------------------------

local SYMBOLS = {}

local infer_table = {
  [CONSTANT] = { [CONSTANT]=CONSTANT, [SCALAR]=SCALAR, [MATRIX]=MATRIX },
  [SCALAR]   = { [CONSTANT]=SCALAR,   [SCALAR]=SCALAR, [MATRIX]=MATRIX },
  [MATRIX]   = { [CONSTANT]=MATRIX,   [SCALAR]=MATRIX, [MATRIX]=MATRIX },
}

local function infer(...)
  local arg = table.pack(...)
  local dtype
  if type(arg[1]) == "number" then
    dtype = CONSTANT
  else
    dtype = arg[1].dtype
  end
  for i=2,#arg do
    local argi_dtype
    if type(arg[i]) == "number" then argi_dtype = CONSTANT
    else argi_dtype = arg[i].dtype
    end
    dtype = infer_table[dtype][argi_dtype]
  end
  return dtype
end

local symbol_mt = {
  __call = function(s,...) return s:eval(...) end,
  __add  = function(a,b) return autodiff.op[ infer(a,b) ].add(a,b) end,
  __sub  = function(a,b) return autodiff.op[ infer(a,b) ].sub(a,b) end,
  __mul  = function(a,b) return autodiff.op[ infer(a,b) ].mul(a,b) end,
  __div  = function(a,b) return autodiff.op[ infer(a,b) ].div(a,b) end,
  __unm  = function(a)   return autodiff.op[ infer(a) ].unm(a)     end,
  __pow  = function(a,b) return autodiff.op[ infer(a,b) ].pow(a,b) end,
  __tostring = function(s) return s.name end,
}

local function symbol(name,dtype)
  local t
  if SYMBOLS[name] then t = SYMBOLS[name]
  else
    t = {
      name  = name,
      dtype = dtype,
      issymbol = true,
      eval = function(self,values)
	return assert(values[self.name], "Undefined value " .. self.name)
      end,
      last = nil,
      to_dot_string = function(self,id,parent,edges)
	local aux = { string.format("%s [shape=box];", name) }
	if parent then
	  local edge_str = string.format("%s -> %s;", name, parent)
	  if not edges[edge_str] then
	    table.insert(aux, edge_str)
	    edges[edge_str] = true
	  end
	end
	return table.concat(aux, "\n")
      end,
    }
    SYMBOLS[name] = t
    setmetatable(t, symbol_mt)
  end
  return t
end

local function op(name, dtype, args, eval, diff)
  local s = symbol(string.format("(%s %s)", name,
				 iterator(ipairs(args)):select(2):
				 map(tostring):concat(" ")),
		   dtype)
  s.isop = name
  s.args = args
  s.eval = function(self, values, prev_cache)
    local cache = prev_cache or {}
    local v = values[self.name] or cache[self.name] or eval(self, values, cache)
    cache[self.name] = v
    self.last = v
    return v
  end
  s.diff = function(self, target)
    return diff(self, (type(target)=="string" and target) or target.name)
  end
  s.to_dot_string = function(self,id,parent,names,edges)
    local edges = edges or {}
    local names = names or {}
    local id  = id or { 0 }
    local aux = {}
    local name_str
    if names[self.name] then
      name_str = names[self.name]
    else
      name_str = "op" .. id[1]
      id[1] = id[1] + 1
      names[self.name] = name_str
      table.insert(aux, string.format('%s [label="%s"];', name_str, self.isop))
    end
    if parent then
      local edge_str = string.format("%s -> %s;", name_str, parent)
      if not edges[edge_str] then
	table.insert(aux, edge_str)
	edges[edge_str] = true
      end
    end
    for _,v in ipairs(self.args) do
      local str = v:to_dot_string(id,name_str,names,edges)
      table.insert(aux, str)
    end
    return table.concat(aux, "\n")
  end
  return s
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

function autodiff.clear()
  SYMBOLS = {}
end

function autodiff.symbol(names,dtype)
  local result = iterator(names:gmatch("[^%s]+")):
  map(function(name) return symbol(name,dtype) end):table()
  return table.unpack(result)
end

function autodiff.func(s,args,shared_values,cache)
  local args,shared_values = args or {},shared_values or {}
  for i,s in ipairs(args) do
    assert(type(s)=="table" and s.issymbol,
	   "Argument " .. i .. " is not a symbol")
  end
  for name,_ in pairs(shared_values) do
    assert(SYMBOLS[name], "Undefined symbol " .. name)
  end
  return function(...)
    local args2 = table.pack(...)
    assert(#args == #args2,
	   string.format("Incorrect number of arguments, expected %d, found %d\n",
			 #args, #args2))
    local values = iterator(ipairs(args)):
    map(function(k,v) return v.name,args2[k] end):table()
    for k,v in pairs(shared_values) do values[k] = v end
    return s:eval(values,cache)
  end
end

setmetatable(autodiff.op,
	     {
	       __index = function(s,key)
		 return rawget(s,key) or
		   function(...)
		     assert(select('#',...) > 0,
			    "Incorrect number of arguments")
		     local dtype = infer(...)
		     local t = assert(autodiff.op[dtype],
				      "Incorrect type " .. dtype)
		     local t = assert(t[key],
				      "Operation: " .. key .. " not implemented for type: " .. dtype)
		     return t(...)
		   end
	       end,
	     })

function autodiff.dot_graph(s, filename)
  local f = io.open(filename, "w")
  f:write("digraph g {\n rankdir=BT;\n")
  f:write( s:to_dot_string() )
  f:write("}\n")
  f:close()
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

-- CONSTANTS

autodiff.constant = function(...)
  local arg = table.pack(...)
  local result = {}
  for _,value in ipairs(arg) do
    local s = autodiff.symbol(tostring(value), CONSTANT)
    s.value = value
    s.eval  = function(self) return self.value end
    s.diff  = function(self) return autodiff.constant( 0 ) end
    s.to_dot_string = function(self,id,parent,names,edges)
      local id  = id or { 0 }
      local aux = {}
      local name_str
      if names[self.name] then name_str = names[self.name]
      else
	name_str = "K" .. id[1]
	id[1] = id[1] + 1
	names[self.name] = name_str
	table.insert(aux, string.format('%s [shape=box,label="%s"];',
					name_str, self.name))
      end
      if parent then
	local edge_str = string.format("%s -> %s;", name_str, parent)
	if not edges[edge_str] then
	  table.insert(aux, edge_str)
	  edges[edge_str] = true
	end
      end
      return table.concat(aux, "\n")
    end
    table.insert(result, s)
  end
  return table.unpack(result)
end

-- CONSTANT OPERATIONS

local function coercion(a)
  if type(a) == "number" then return autodiff.constant(a)
  else return a
  end
end

autodiff.op[CONSTANT] = {
  
  add = function(a,b) local a,b=coercion(a),coercion(b) return autodiff.constant( a() + b() ) end,
  sub = function(a,b) local a,b=coercion(a),coercion(b) return autodiff.constant( a() - b() ) end,
  pow = function(a,b) local a,b=coercion(a),coercion(b) return autodiff.constant( a() ^ b() ) end,
  unm = function(a)   local a=coercion(a) return autodiff.constant( - a() )     end,
  mul = function(a,b) local a,b=coercion(a),coercion(b) return autodiff.constant( a() * b() ) end,
  div = function(a,b) local a,b=coercion(a),coercion(b) return autodiff.constant( a() / b() ) end,

  log = function(a) local a=coercion(a) return autodiff.constant( math.log( a() ) ) end,
  exp = function(a) local a=coercion(a) return autodiff.constant( math.exp( a() ) ) end,
  sin = function(a) local a=coercion(a) return autodiff.constant( math.sin( a() ) ) end,
  cos = function(a) local a=coercion(a) return autodiff.constant( math.cos( a() ) ) end,

}

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

-- SCALARS

autodiff[SCALAR] = function(names)
  local t = table.pack(autodiff.symbol(names, SCALAR))
  for i=1,#t do
    t[i].diff = function(self, target)
      local tname = (type(target)=="string" and target) or target.name
      if tname == self.name then
	return autodiff.constant(1)
      else 
	return autodiff.constant(0)
      end
    end
  end
  return table.unpack(t)
end

-- CONSTANT OPERATIONS

autodiff.op[SCALAR] = {
  
  add = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('+', SCALAR, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   return a + b
		 end,
		 function(self, target)
		   local da = self.args[1]:diff(target)
		   local db = self.args[2]:diff(target)
		   return da + db
		 end)
    return s
  end,
  
  sub = function(a,b)
    local a,b = coercion(a),coercion(b)
    return a + (-1 * b)
  end,

  mul = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('*', SCALAR, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   return a * b
		 end,
		 function(self, target)
		   local a,b = self.args[1],self.args[2]
		   local da,db = a:diff(target),b:diff(target)
		   return da*b + a*db
		 end)
    return s
  end,
  
  div = function(a,b)
    local a,b = coercion(a),coercion(b)
    return a * (b^(-1))
  end,

  pow = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('^', SCALAR, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   return a^b
		 end,
		 function(self, target)
		   local a,b = self.args[1],self.args[2]
		   local da  = a:diff(target)
		   return b * (a^(b-1)) * da
		 end)
    return s
  end,
  
  unm = function(a)
    local a = coercion(a)
    return (-1) * a
  end,

  log = function(a)
    local a = coercion(a)
    local s = op('log', SCALAR, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return math.log(a)
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return 1/a * da
		 end)
    return s
  end,

  exp = function(a)
    local a = coercion(a)
    local s = op('exp', SCALAR, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return math.exp(a)
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return autodiff.op.exp(a) * da
		 end)
    return s
  end,

  cos = function(a)
    local a = coercion(a)
    local s = op('cos', SCALAR, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return math.cos(a)
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return autodiff.op.sin(a) * da
		 end)
    return s
  end,

  sin = function(a)
    local a = coercion(a)
    local s = op('sin', SCALAR, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return math.sin(a)
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return autodiff.op.cos(a) * da
		 end)
    return s
  end,

}

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

-- MATRIXS

autodiff[MATRIX] = function(names)
  local t = table.pack(autodiff.symbol(names, MATRIX))
  for i=1,#t do
    t[i].diff = function(self, target)
      local tname = (type(target)=="string" and target) or target.name
      if tname == self.name then
	return autodiff.constant(1) --autodiff.op.fill(self,1)
      else 
	return autodiff.constant(0) --autodiff.op.fill(self,0)
      end
    end
  end
  return table.unpack(t)
end

-- CONSTANT OPERATIONS

autodiff.op[MATRIX] = {
  
  add = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('+', MATRIX, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   -- simplifications
		   -- if     a == -b then return 0
		   if a == 0 then return b
		   elseif b == 0 then return a
		   end
		   --
		   return a + b
		 end,
		 function(self, target)
		   local da = self.args[1]:diff(target)
		   local db = self.args[2]:diff(target)
		   return da + db
		 end)
    return s
  end,
  
  sub = function(a,b)
    local a,b = coercion(a),coercion(b)
    return a + (-1 * b)
  end,

  mul = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('*', MATRIX, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   -- simplifications
		   if a == 0 or b == 0 then return 0
		   elseif a == 1 then return b
		   elseif b == 1 then return a
		   end
		   --
		   return a * b
		 end,
		 function(self, target)
		   local a,b = self.args[1],self.args[2]
		   local da,db = a:diff(target),b:diff(target)
		   return a*db + da*b
		 end)
    return s
  end,
  
  div = function(a,b)
    local a,b = coercion(a),coercion(b)
    return a * (b^(-1))
  end,

  pow = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('^', MATRIX, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   -- sanity check
		   assert(type(a) == "matrix")
		   assert(type(b) ~= "matrix",
			  "Impossible to compute pow with a 2nd matrix argument")
		   -- simplifications
		   if     b == 0 then return a:clone():ones()
		   elseif b == 1 then return a
		   end
		   --
		   return a:clone():pow(b)
		 end,
		 function(self, target)
		   local a,b = self.args[1],self.args[2]
		   local da  = a:diff(target)
		   return b * (a^(b-1)) * da
		 end)
    return s
  end,
  
  unm = function(a)
    local a = coercion(a)
    return (-1) * a
  end,

  log = function(a)
    local a = coercion(a)
    local s = op('log', MATRIX, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return a:clone():log()
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return autodiff.op.cmul(autodiff.op.pow(a, -1), da)
		 end)
    return s
  end,

  exp = function(a)
    local a = coercion(a)
    local s = op('exp', MATRIX, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return a:clone():exp()
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return autodiff.op.cmul(autodiff.op.exp(a), da)
		 end)
    return s
  end,

  cos = function(a)
    local a = coercion(a)
    local s = op('cos', MATRIX, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return a:clone():cos()
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return autodiff.op.sin(a) * da
		 end)
    return s
  end,

  sin = function(a)
    local a = coercion(a)
    local s = op('sin', MATRIX, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return a:clone():sin()
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   return autodiff.op.cos(a) * da
		 end)
    return s
  end,

  transpose = function(a)
    local a = coercion(a)
    local s = op('T', MATRIX, {a},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   return a:transpose()
		 end,
		 function(self, target)
		   local a  = self.args[1]
		   local da = a:diff(target)
		   if da.dtype == MATRIX then
		     return autodiff.op.transpose(da)
		   else
		     return da
		   end
		 end)
    return s
  end,

  cmul = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('.*', MATRIX, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   if a == 0 or b == 0 then return 0 end
		   if type(a) == "number" or type(b) == "number" then
		     return a*b
		   end
		   return a:cmul(b)
		 end,
		 function(self, target)
		   error("NOT IMPLEMENTED")
		 end)
    return s
  end,
  
  fill = function(a,b)
    local a,b = coercion(a),coercion(b)
    local s = op('fill', MATRIX, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2]:eval(...)
		   assert(type(a) == "matrix")
		   assert(type(b) == "number")
		   return a:clone():fill(b)
		 end,
		 function(self, target)
		   if self.name == target then
		     return autodiff.op.fill(self.args[1],1) * self.args[2]
		   else
		     return autodiff.op.fill(self.args[1],0) * self.args[2]
		   end
		 end)
    return s
  end,
  
  sum = function(a,b)
    local a,b = coercion(a),b and coercion(b)
    local s = op('sum', MATRIX, {a,b},
		 function(self, ...)
		   local a = self.args[1]:eval(...)
		   local b = self.args[2] and self.args[2]:eval(...)
		   assert(type(a) == "matrix")
		   assert(not b or type(b)=="number")
		   return a:sum(b)
		 end,
		 function(self, target)
		   local a,b = self.args[1],self.args[2]
		   local da  = a:diff(target)
		   return autodiff.op.sum(da, b)
		 end)
    return s
  end,
}

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
