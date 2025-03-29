--!strict
-- Services
-- Packages
local Result = require("@wally/Result")
local Option = require("@wally/Option")
local Error = require("@wally/Error")
local Vec = require("@wally/Vec")
-- Modules
-- Types
type Error<T, Body> = Error.Error<T, Body>
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Vec<V> = Vec.Vec<V>
type MutVec<V> = Vec.MutVec<V>
type Entry<K, V> = {
	key: K,
	value: V,
}
type HashMapImpl<K, V> = {
	__index: HashMapImpl<K, V>,
	__tostring: (self: HashMap<K, V>) -> string,
	__len: (self: HashMap<K, V>) -> number,
	__iter: (self: HashMap<K, V>) -> (typeof(pairs), { [K]: V }),
	drain: (self: HashMap<K, V>) -> { [K]: V },
	containsKey: (self: HashMap<K, V>, key: K) -> boolean,
	get: (self: HashMap<K, V>, key: K) -> Option<V>,
	getKeyValue: (self: HashMap<K, V>, key: K) -> Option<Entry<K, V>>,
	intoKeys: (self: HashMap<K, V>) -> Vec<K>,
	intoValues: (self: HashMap<K, V>) -> Vec<V>,
	isEmpty: (self: HashMap<K, V>) -> boolean,
	isMut: (self: HashMap<K, V>) -> false,
	asMut: (self: HashMap<K, V>) -> MutHashMap<K, V>,
}

type MutHashMapImpl<K, V> = {
	__index: MutHashMapImpl<K, V>,
	clear: (self: MutHashMap<K, V>) -> (),
	insert: (self: MutHashMap<K, V>, key: K, value: V) -> Option<V>,
	drain: (self: MutHashMap<K, V>) -> { [K]: V },
	tryInsert: (
		self: MutHashMap<K, V>,
		key: K,
		value: V
	) -> Result<V, Error<"OccupiedError", {
		entry: Entry<K, V>,
		value: V,
	}>>,
	remove: (self: MutHashMap<K, V>, key: K) -> Option<V>,
	removeEntry: (self: MutHashMap<K, V>, key: K) -> Option<Entry<K, V>>,
	retain: (self: MutHashMap<K, V>, predicate: (entry: Entry<K, V>) -> boolean) -> (),
	freeze: (self: MutHashMap<K, V>) -> HashMap<K, V>,
}

export type HashMap<K, V> = typeof(setmetatable(
	{} :: {
		_map: { [K]: V },
	},
	{} :: HashMapImpl<K, V>
))

export type MutHashMap<K, V> = typeof(setmetatable({} :: {}, {} :: MutHashMapImpl<K, V>)) & HashMap<K, V>
-- Constants
-- Variables
-- References
-- Private Functions
function newEntry<K, V>(key: K, value: V): Entry<K, V>
	local entry = {
		key = key,
		value = value,
	}
	table.freeze(entry)
	return entry
end
-- Class
local HashMap = {} :: HashMapImpl<any, any>
HashMap.__index = HashMap

function HashMap:__tostring(): string
	return `HashMap({Error.displayAsJson(self:drain())})`
end

function HashMap:__len(): number
	local count = 0
	for _ in self do
		count += 1
	end
	return count
end

function HashMap.__iter(self: HashMap<any, any>)
	return pairs :: any, self._map
end

function HashMap:drain(): { [any]: any }
	return self._map
end

function HashMap:containsKey(key: any): boolean
	return self._map[key] ~= nil
end

function HashMap:get(key: any): Option<any>
	local value = self._map[key]
	if value == nil then
		return Option.none()
	end
	return Option.some(value)
end

function HashMap:getKeyValue(key: any): Option<Entry<any, any>>
	local value = self._map[key]
	if value == nil then
		return Option.none()
	end
	return Option.some(newEntry(key, value))
end

function HashMap:intoKeys(): Vec<any>
	local keys = {}
	for key, v in self do
		table.insert(keys, key)
	end
	return Vec.from(keys)
end

function HashMap:intoValues(): Vec<any>
	local values = {}
	for _, value in self do
		table.insert(values, value)
	end
	return Vec.from(values)
end

function HashMap:isEmpty(): boolean
	return next(self._map) == nil
end

function HashMap:isMut(): false
	return (not table.isfrozen(self._map)) :: false
end

local MutHashMap = {} :: MutHashMapImpl<any, any>
MutHashMap.__index = MutHashMap
setmetatable(MutHashMap, HashMap)

function HashMap:asMut(): MutHashMap<any, any>
	local out = setmetatable({
		_map = table.clone(self._map),
	}, MutHashMap) :: any

	table.freeze(out)
	return out
end

function MutHashMap:clear()
	table.clear(self._map)
end

function MutHashMap:insert(key: any, value: any): Option<any>
	local oldValue = self._map[key]
	self._map[key] = value
	if oldValue == nil then
		return Option.none()
	end
	return Option.some(oldValue)
end

function MutHashMap:tryInsert(key: any, value: any): Result<any, Error<any, any>>
	if self._map[key] ~= nil then
		return Result.err(Error.new("OccupiedError" :: any)
			:title("Occupied Key")
			:description(`Key "{tostring(key)}" already exists in the HashMap`)
			:body({
				entry = newEntry(key, self._map[key]),
				value = value,
			})
			:build())
	end
	self._map[key] = value
	return Result.ok(value)
end

function MutHashMap:remove(key: any): Option<any>
	local value = self._map[key]
	if value == nil then
		return Option.none()
	end
	self._map[key] = nil
	return Option.some(value)
end

function MutHashMap:removeEntry(key: any): Option<Entry<any, any>>
	local value = self._map[key]
	if value == nil then
		return Option.none()
	end
	self._map[key] = nil
	return Option.some(newEntry(key, value))
end

function MutHashMap:retain(predicate: (entry: Entry<any, any>) -> boolean)
	for key, value in self._map do
		if not predicate(newEntry(key, value)) then
			self._map[key] = nil
		end
	end
end

function MutHashMap:freeze(): HashMap<any, any>
	local map = table.clone(self._map)
	table.freeze(map)
	local out = setmetatable({
		_map = map,
	}, HashMap)
	table.freeze(out)
	return out
end

return {
	from = function<K, V>(initial: { [K]: V }): HashMap<K, V>
		local map: { [K]: V } = if table.isfrozen(initial) then initial else table.clone(initial)
		if not table.isfrozen(map) then
			table.freeze(map)
		end
		local self = setmetatable({
			_map = map,
		}, HashMap)
		table.freeze(self)
		return self
	end :: (<K, V>(initial: { [K]: V }?) -> HashMap<K, V>) & (<K, V>() -> HashMap<K, V>),
}
