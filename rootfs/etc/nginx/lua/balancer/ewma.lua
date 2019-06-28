-- Original Authors: Shiv Nagarajan & Scott Francis
-- Accessed: March 12, 2018
-- Inspiration drawn from:
-- https://github.com/twitter/finagle/blob/1bc837c4feafc0096e43c0e98516a8e1c50c4421
--   /finagle-core/src/main/scala/com/twitter/finagle/loadbalancer/PeakEwma.scala


local util = require("util")
local split = require("util.split")

local DECAY_TIME = 10 -- this value is in seconds
local PICK_SET_SIZE = 2

local _M = { name = "ewma" }

local function decay_ewma(ewma, last_touched_at, rtt, now)
  local td = now - last_touched_at
  td = (td > 0) and td or 0
  local weight = math.exp(-td/DECAY_TIME)

  ewma = ewma * weight + rtt * (1.0 - weight)
  return ewma
end

local function get_or_update_ewma(self, upstream, rtt, update)
  -- TODO(elvinefendi) should we wrap this with a lock around?
  -- otherwise it is theoretically possible that an another worker updates ewma
  -- value of upstream after we get ewma value but before we get last_touched_at.
  -- The worst case is we will decay ewma more.
  local ewma = ngx.shared.balancer_ewma:get(upstream) or 0
  local last_touched_at = ngx.shared.balancer_ewma_last_touched_at:get(upstream) or 0

  local now = ngx.now()
  ewma = decay_ewma(ewma, last_touched_at, rtt, now)

  if not update then
    return ewma, nil
  end

  local success, err, forcible = ngx.shared.balancer_ewma_last_touched_at:set(upstream, now)
  if not success then
    ngx.log(ngx.WARN, "balancer_ewma_last_touched_at:set failed " .. err)
  end
  if forcible then
    ngx.log(ngx.WARN, "balancer_ewma_last_touched_at:set valid items forcibly overwritten")
  end

  success, err, forcible = ngx.shared.balancer_ewma:set(upstream, ewma)
  if not success then
    ngx.log(ngx.WARN, "balancer_ewma:set failed " .. err)
  end
  if forcible then
    ngx.log(ngx.WARN, "balancer_ewma:set valid items forcibly overwritten")
  end

  return ewma, nil
end


local function score(self, upstream)
  -- Original implementation used names
  -- Endpoints don't have names, so passing in IP:Port as key instead
  local upstream_name = upstream.address .. ":" .. upstream.port
  return get_or_update_ewma(self, upstream_name, 0, false)
end

-- implementation similar to https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle
-- or https://en.wikipedia.org/wiki/Random_permutation
-- loop from 1 .. k
-- pick a random value r from the remaining set of unpicked values (i .. n)
-- swap the value at position i with the value at position r
local function shuffle_peers(peers, k)
  for i=1, k do
    local rand_index = math.random(i,#peers)
    peers[i], peers[rand_index] = peers[rand_index], peers[i]
  end
  -- peers[1 .. k] will now contain a randomly selected k from #peers
end

local function pick_and_score(self, peers, k)
  shuffle_peers(peers, k)
  local lowest_score_index = 1
  local lowest_score = score(self, peers[lowest_score_index])
  for i = 2, k do
    local new_score = score(self, peers[i])
    if new_score < lowest_score then
      lowest_score_index, lowest_score = i, new_score
    end
  end
  return peers[lowest_score_index]
end

function _M.balance(self)
  local peers = self.peers
  local endpoint = peers[1]

  if #peers > 1 then
    local k = (#peers < PICK_SET_SIZE) and #peers or PICK_SET_SIZE
    local peer_copy = util.deepcopy(peers)
    endpoint = pick_and_score(self, peer_copy, k)
  end

  -- TODO(elvinefendi) move this processing to _M.sync
  return endpoint.address .. ":" .. endpoint.port
end

function _M.after_balance(self)
  local response_time = tonumber(split.get_first_value(ngx.var.upstream_response_time)) or 0
  local connect_time = tonumber(split.get_first_value(ngx.var.upstream_connect_time)) or 0
  local rtt = connect_time + response_time
  local upstream = split.get_first_value(ngx.var.upstream_addr)

  if util.is_blank(upstream) then
    return
  end
  get_or_update_ewma(self, upstream, rtt, true)
end

function _M.sync(self, backend)
  self.traffic_shaping_policy = backend.trafficShapingPolicy
  self.alternative_backends = backend.alternativeBackends

  -- delete now old endpoints
  local indexed_new_endpoints = {}
  for _, endpoint in pairs(backend.endpoints) do
    local endpoint_string = endpoint.address .. ":" .. endpoint.port
    indexed_new_endpoints[endpoint_string] = true
  end
  for _, endpoint in pairs(self.peers) do
    local endpoint_string = endpoint.address .. ":" .. endpoint.port
    if not indexed_new_endpoints[endpoint_string] then
      ngx.shared.balancer_ewma:delete(endpoint_string)
      ngx.shared.balancer_ewma_last_touched_at:delete(endpoint_string)
    end
  end

  -- Calculate max ewma, and set the ewma of
  -- newly added endpoints to this value. This makes sure
  -- we start sending requests slowly to the new endpoints.
  local slow_start_ewma = 0
  for _, endpoint in pairs(self.peers) do
    local endpoint_string = endpoint.address .. ":" .. endpoint.port
    local ewma = ngx.shared.balancer_ewma:get(endpoint_string) or 0
    if slow_start_ewma < ewma then
      slow_start_ewma = ewma
    end
  end

  local indexed_current_endpoints = {}
  local now = ngx.now()
  for _, endpoint in pairs(self.peers) do
    local endpoint_string = endpoint.address .. ":" .. endpoint.port
    indexed_current_endpoints[endpoint_string] = true
  end
  for _, endpoint in pairs(backend.endpoints) do
    local endpoint_string = endpoint.address .. ":" .. endpoint.port
    if not indexed_current_endpoints[endpoint_string] then
      ngx.shared.balancer_ewma:set(endpoint_string, slow_start_ewma)
      ngx.shared.balancer_ewma_last_touched_at:set(endpoint_string, now)
    end
  end

  self.peers = backend.endpoints
end

function _M.new(self, backend)
  local o = {
    peers = backend.endpoints,
    traffic_shaping_policy = backend.trafficShapingPolicy,
    alternative_backends = backend.alternativeBackends,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

return _M
