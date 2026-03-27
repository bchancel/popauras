local _, ns = ...

local unpack = unpack or table.unpack

local Profiler = {}
ns.Profiler = Profiler

Profiler.enabled = false
Profiler.buckets = {}
Profiler.startedAt = 0

local function ClockMilliseconds()
  if type(debugprofilestop) == "function" then
    return debugprofilestop()
  end
  if GetTimePreciseSec then
    return GetTimePreciseSec() * 1000
  end
  return GetTime() * 1000
end

local function Pack(...)
  return {
    n = select("#", ...),
    ...
  }
end

local function SanitizeLabel(value)
  value = tostring(value or "")
  value = value:gsub("[%c\r\n]+", " ")
  if #value > 40 then
    value = value:sub(1, 37) .. "..."
  end
  return value
end

local function CountEntries(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

function Profiler:IsEnabled()
  return self.enabled == true
end

function Profiler:Reset()
  self.buckets = {}
  self.startedAt = GetTime and GetTime() or 0
end

function Profiler:Start()
  self:Reset()
  self.enabled = true
end

function Profiler:Stop()
  self.enabled = false
end

function Profiler:Begin(bucket)
  if not self.enabled or not bucket or bucket == "" then
    return nil
  end
  return ClockMilliseconds()
end

function Profiler:Record(bucket, elapsedMs, calls)
  if not bucket or bucket == "" then
    return
  end

  local entry = self.buckets[bucket]
  if not entry then
    entry = {
      totalMs = 0,
      calls = 0,
      maxMs = 0,
    }
    self.buckets[bucket] = entry
  end

  elapsedMs = tonumber(elapsedMs or 0) or 0
  calls = tonumber(calls or 1) or 1
  entry.totalMs = entry.totalMs + elapsedMs
  entry.calls = entry.calls + calls
  if elapsedMs > entry.maxMs then
    entry.maxMs = elapsedMs
  end
end

function Profiler:Finish(bucket, startedAt, calls)
  if not self.enabled or not startedAt then
    return
  end
  self:Record(bucket, ClockMilliseconds() - startedAt, calls)
end

function Profiler:Measure(bucket, callback, ...)
  if not self.enabled then
    return callback(...)
  end

  local startedAt = self:Begin(bucket)
  local results = Pack(callback(...))
  self:Finish(bucket, startedAt)
  return unpack(results, 1, results.n)
end

function Profiler:GetAuraBucket(prefix, aura)
  return string.format("%s:%s#%s", prefix or "aura", SanitizeLabel(aura and aura.name or "Unknown"), tostring(aura and aura.id or "?"))
end

function Profiler:GetSummaryLines(limit)
  limit = math.max(1, tonumber(limit or 12) or 12)

  local lines = {}
  local runtimeSeconds = math.max(0, (GetTime and (GetTime() - (self.startedAt or 0)) or 0))
  lines[#lines + 1] = string.format(
    "PopAuras perf: %s | %.1fs captured | buckets=%d",
    self.enabled and "ON" or "OFF",
    runtimeSeconds,
    CountEntries(self.buckets)
  )

  local scriptProfileEnabled = GetCVarBool and GetCVarBool("scriptProfile")
  if scriptProfileEnabled ~= nil then
    lines[#lines + 1] = string.format("scriptProfile=%s", scriptProfileEnabled and "on" or "off")
  end

  if scriptProfileEnabled and UpdateAddOnCPUUsage and GetAddOnCPUUsage then
    UpdateAddOnCPUUsage()
    local addonCPU = tonumber(GetAddOnCPUUsage(ns.name) or 0) or 0
    lines[#lines + 1] = string.format("addonCPU=%.1fms", addonCPU)
  end

  local buckets = {}
  for name, entry in pairs(self.buckets or {}) do
    buckets[#buckets + 1] = {
      name = name,
      totalMs = tonumber(entry.totalMs or 0) or 0,
      calls = tonumber(entry.calls or 0) or 0,
      maxMs = tonumber(entry.maxMs or 0) or 0,
    }
  end

  table.sort(buckets, function(left, right)
    if left.totalMs == right.totalMs then
      return left.name < right.name
    end
    return left.totalMs > right.totalMs
  end)

  if #buckets == 0 then
    lines[#lines + 1] = "No samples collected yet."
    return lines
  end

  for index = 1, math.min(limit, #buckets) do
    local entry = buckets[index]
    local avgMs = entry.calls > 0 and (entry.totalMs / entry.calls) or 0
    lines[#lines + 1] = string.format(
      "%d. %s total=%.2fms calls=%d avg=%.3f max=%.3f",
      index,
      entry.name,
      entry.totalMs,
      entry.calls,
      avgMs,
      entry.maxMs
    )
  end

  return lines
end
