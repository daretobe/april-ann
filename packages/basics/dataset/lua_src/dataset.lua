-----------------------------------------------------------------------------

class.extend(dataset.token, "bunches", function(ds, bunch_size)
               return coroutine.wrap(function()
                   local idxs = matrixInt32(bunch_size):linspace()
                   local nump = ds:numPatterns()
                   local j=1
                   for i=1,nump-bunch_size+1,bunch_size do
                     if j%1000 == 0 then j=1 collectgarbage("collect") end j=j+1
                     local tbl = idxs:toTable()
                     coroutine.yield(ds:getPatternBunch(tbl), tbl)
                     idxs:scalar_add(bunch_size)
                   end
                   local sz = nump % bunch_size
                   if sz > 0 then
                     local tbl = idxs[{ {1,sz} }]:toTable()
                     coroutine.yield(ds:getPatternBunch(tbl), tbl)
                   end
                   collectgarbage("collect")
               end)
end)

class.extend(dataset, "bunches",
             function(ds, bunch_size)
               return dataset.token.wrapper(ds):bunches(bunch_size)
end)

-----------------------------------------------------------------------------

function dataset.to_fann_file_format(input_dataset, output_dataset)
  local numpat = input_dataset:numPatterns()
  if (output_dataset:numPatterns() ~= numpat) then
    error("dataset.to_fann_file_format input and output dataset has different number of patterns")
  end
  local resul = {}
  table.insert(resul,string.format("%d %d %d",numpat,
			       input_dataset:patternSize(),
			       output_dataset:patternSize()))
  for i=1,numpat do
    table.insert(resul,table.concat(input_dataset:getPattern(i)," "))
    table.insert(resul,table.concat(output_dataset:getPattern(i)," "))
  end
  return table.concat(resul,"\n")
end

function dataset.create_fann_file(filename, input_dataset, output_dataset)
  local str  = dataset.to_fann_file_format(input_dataset,output_dataset)
  local fich = io.open(filename,"w")
  fich:write(str)
  fich:close()
end

-----------------------------------------------------------------------------

local lua_filter,lua_filter_methods = class("dataset.token.lua_filter")
get_table_from_dotted_string("dataset.token", true) -- global environment
dataset.token.lua_filter = lua_filter -- global environment

function lua_filter:constructor(t)
  local params = get_table_fields({
				    dataset = { mandatory=true },
				    filter  = { mandatory=true,
						type_match="function" },
                                    pattern_size = { type_match="number" },
				  }, t)
  self.ds=params.dataset
  self.filter=params.filter
  self.pattern_size=params.pattern_size or self.ds:patternSize()
  if class.is_a(ds,dataset) then self.ds = dataset.token_wrapper(self.ds) end
end

function lua_filter_methods:numPatterns() return self.ds:numPatterns() end

function lua_filter_methods:patternSize() return self.pattern_size end

function lua_filter_methods:getPattern(idx)
  return self.filter( self.ds:getPattern(idx) )
end

function lua_filter_methods:getPatternBunch(idxs)
  return self.filter( self.ds:getPatternBunch(idxs) )
end
