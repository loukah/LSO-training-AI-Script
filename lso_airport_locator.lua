-- DCS airport locator from Mission Editor trigger zones.
--
-- Usage:
--   1. Place the center of a trigger zone on the runway threshold you want.
--   2. Name it with the prefix:
--        LSO
--      or:
--        LSO:245
--   3. Load this file with DO SCRIPT FILE.
--
-- The zone center is used as the threshold coordinate. The zone radius is ignored.
-- The script prints the nearest DCS airbase and, when a heading is given,
-- the runway name for each LSO trigger zone found.

LSO_AIRPORT_LOCATOR = LSO_AIRPORT_LOCATOR or {}

local Locator = LSO_AIRPORT_LOCATOR
Locator.prefix = "LSO"
Locator.maxRunwayHeadingError = 15
Locator.points = {}
Locator.results = {}

local function log(text)
  env.info("[LSO Airport Locator] " .. tostring(text))
end

local function startsWith(text, prefix)
  return type(text) == "string" and text:sub(1, #prefix) == prefix
end

local function normalizeAirbaseName(name)
  local normalized = string.lower(tostring(name or "")):gsub("[^%w]", "")
  return normalized
end

Locator.manualRunwaysByAirbase = {
  -- Caucasus. Magnetic runway headings from common DCS Caucasus airfield data.
  [normalizeAirbaseName("Anapa-Vityazevo")] = { { name = "RWY04", heading = 35 }, { name = "RWY22", heading = 215 } },
  [normalizeAirbaseName("Batumi")] = { { name = "RWY12", heading = 119 }, { name = "RWY30", heading = 299 } },
  [normalizeAirbaseName("Beslan")] = { { name = "RWY09", heading = 87 }, { name = "RWY27", heading = 277 } },
  [normalizeAirbaseName("Gelendzhik")] = { { name = "RWY04", heading = 34 }, { name = "RWY22", heading = 214 } },
  [normalizeAirbaseName("Gudauta")] = { { name = "RWY15", heading = 145 }, { name = "RWY33", heading = 325 } },
  [normalizeAirbaseName("Kobuleti")] = { { name = "RWY07", heading = 64 }, { name = "RWY25", heading = 244 } },
  [normalizeAirbaseName("Krasnodar-Center")] = { { name = "RWY09", heading = 81 }, { name = "RWY27", heading = 261 } },
  [normalizeAirbaseName("Krasnodar Center")] = { { name = "RWY09", heading = 81 }, { name = "RWY27", heading = 261 } },
  [normalizeAirbaseName("Krasnodar-Pashkovsky")] = {
    { name = "RWY05L", heading = 40 }, { name = "RWY23R", heading = 220 },
    { name = "RWY05R", heading = 40 }, { name = "RWY23L", heading = 220 },
  },
  [normalizeAirbaseName("Krymsk")] = { { name = "RWY04", heading = 33 }, { name = "RWY22", heading = 213 } },
  [normalizeAirbaseName("Kutaisi")] = { { name = "RWY08", heading = 68 }, { name = "RWY26", heading = 248 } },
  [normalizeAirbaseName("Kutaisi-Kopitnari")] = { { name = "RWY08", heading = 68 }, { name = "RWY26", heading = 248 } },
  [normalizeAirbaseName("Maykop-Khanskaya")] = { { name = "RWY04", heading = 32 }, { name = "RWY22", heading = 212 } },
  [normalizeAirbaseName("Mineralnye Vody")] = { { name = "RWY12", heading = 109 }, { name = "RWY30", heading = 289 } },
  [normalizeAirbaseName("Mozdok")] = { { name = "RWY08", heading = 77 }, { name = "RWY26", heading = 257 } },
  [normalizeAirbaseName("Nalchik")] = { { name = "RWY06", heading = 50 }, { name = "RWY24", heading = 230 } },
  [normalizeAirbaseName("Novorossiysk")] = { { name = "RWY04", heading = 35 }, { name = "RWY22", heading = 215 } },
  [normalizeAirbaseName("Senaki-Kolkhi")] = { { name = "RWY09", heading = 89 }, { name = "RWY27", heading = 269 } },
  [normalizeAirbaseName("Sochi-Adler")] = {
    { name = "RWY02", heading = 19 }, { name = "RWY20", heading = 199 },
    { name = "RWY06", heading = 56 }, { name = "RWY24", heading = 236 },
  },
  [normalizeAirbaseName("Sukhumi-Babushara")] = { { name = "RWY12", heading = 110 }, { name = "RWY30", heading = 290 } },
  [normalizeAirbaseName("Tbilisi-Lochini")] = {
    { name = "RWY13L", heading = 118 }, { name = "RWY31R", heading = 298 },
    { name = "RWY13R", heading = 122 }, { name = "RWY31L", heading = 302 },
  },
  [normalizeAirbaseName("Tbilisi-Soganlug")] = { { name = "RWY13", heading = 126 }, { name = "RWY31", heading = 306 } },
  [normalizeAirbaseName("Vaziani")] = { { name = "RWY13", heading = 130 }, { name = "RWY31", heading = 310 } },

  -- Marianas. These entries are editable fallbacks if DCS getRunways is not usable.
  [normalizeAirbaseName("Andersen AFB")] = {
    { name = "RWY06L", heading = 60 }, { name = "RWY24R", heading = 240 },
    { name = "RWY06R", heading = 60 }, { name = "RWY24L", heading = 240 },
  },
  [normalizeAirbaseName("Antonio B. Won Pat Intl")] = {
    { name = "RWY06L", heading = 60 }, { name = "RWY24R", heading = 240 },
    { name = "RWY06R", heading = 60 }, { name = "RWY24L", heading = 240 },
  },
  [normalizeAirbaseName("North West Field")] = { { name = "RWY06", heading = 60 }, { name = "RWY24", heading = 240 } },
  [normalizeAirbaseName("Olf Orote")] = { { name = "RWY04", heading = 40 }, { name = "RWY22", heading = 220 } },
  [normalizeAirbaseName("Pagan Airstrip")] = { { name = "RWY11", heading = 110 }, { name = "RWY29", heading = 290 } },
  [normalizeAirbaseName("Rota Intl")] = { { name = "RWY09", heading = 90 }, { name = "RWY27", heading = 270 } },
  [normalizeAirbaseName("Saipan Intl")] = {
    { name = "RWY07", heading = 70 }, { name = "RWY25", heading = 250 },
    { name = "RWY06", heading = 60 }, { name = "RWY24", heading = 240 },
  },
  [normalizeAirbaseName("Tinian Intl")] = { { name = "RWY08", heading = 80 }, { name = "RWY26", heading = 260 } },
}

local function isLsoZoneName(name)
  if type(name) ~= "string" then return false end
  return string.upper(name):match("^LSO") ~= nil
end

local function pointZ(point)
  if not point then return 0 end
  return point.z or point.y or 0
end

local function distance2D(a, b)
  local dx = (a.x or 0) - (b.x or 0)
  local dz = pointZ(a) - pointZ(b)
  return math.sqrt(dx * dx + dz * dz)
end

local function tonumberOrNil(value)
  if value == nil then return nil end
  local normalized = tostring(value):gsub(",", ".")
  return tonumber(normalized)
end

local function parseHeading(name)
  if type(name) ~= "string" then return nil end
  local headingText = string.upper(name):match("^LSO[%s:_%-%(]*([0-9]+%.?[0-9]*)")
  local heading = tonumberOrNil(headingText)
  if not heading then return nil end
  return heading % 360
end

local function runwayNameFromHeading(heading)
  if not heading then return nil end
  local runway = math.floor(((heading % 360) + 5) / 10)
  if runway == 0 then runway = 36 end
  if runway > 36 then runway = runway - 36 end
  return string.format("RWY%02d", runway)
end

local function formatRunwayName(value)
  if value == nil then return nil end
  if type(value) == "number" then
    return string.format("RWY%02d", value)
  end

  local text = tostring(value)
  local upper = string.upper(text)
  if upper:match("^RWY") then return upper end

  local number, suffix = upper:match("^(%d+)([LRC]?)$")
  if number then
    return string.format("RWY%02d%s", tonumber(number), suffix or "")
  end

  return text
end

local function angleDiff(a, b)
  return math.abs((a - b + 180) % 360 - 180)
end

local function headingFromRunwayData(runway)
  if type(runway) ~= "table" then return nil end
  local heading = tonumberOrNil(runway.heading or runway.hdg or runway.azimuth or runway.bearing)
  if heading then return heading % 360 end

  local course = tonumberOrNil(runway.course)
  if course then
    if math.abs(course) <= math.pi * 2 then
      return math.deg(-course) % 360
    end
    return course % 360
  end

  return nil
end

local function runwayNameFromRunwayData(runway)
  if type(runway) ~= "table" then return nil end
  local name = runway.name or runway.Name or runway.id or runway.number
  if name then return formatRunwayName(name) end
  return nil
end

local function safeAirbaseName(airbase)
  if not airbase or not airbase.getName then return "" end
  local ok, name = pcall(function() return airbase:getName() end)
  if ok then return name or "" end
  return ""
end

local function manualRunwaysForAirbase(airbaseName)
  local key = normalizeAirbaseName(airbaseName)
  if key == "" then return nil end
  local direct = Locator.manualRunwaysByAirbase[key]
  if direct then return direct end

  for knownKey, runways in pairs(Locator.manualRunwaysByAirbase) do
    if key:find(knownKey, 1, true) or knownKey:find(key, 1, true) then
      return runways
    end
  end

  return nil
end

local function addRunwaySource(sources, runways, method)
  if type(runways) == "table" and next(runways) ~= nil then
    table.insert(sources, { runways = runways, method = method })
  end
end

local function runwaySourcesFromAirbase(airbase)
  local sources = {}

  if airbase and airbase.getRunways then
    local ok, runways = pcall(function() return airbase:getRunways() end)
    if ok then addRunwaySource(sources, runways, "DCS getRunways") end
  end

  if airbase and airbase.getDesc then
    local ok, desc = pcall(function() return airbase:getDesc() end)
    if ok and type(desc) == "table" then
      addRunwaySource(sources, desc.runways or desc.Runways or desc.runway or desc.Runway, "DCS getDesc")
    end
  end

  addRunwaySource(sources, manualRunwaysForAirbase(safeAirbaseName(airbase)), "table Lua")

  return sources
end

local function bestRunwayForHeading(airbase, heading)
  if not heading then return nil, nil, "aucun cap donne" end

  local bestOverall
  local sources = runwaySourcesFromAirbase(airbase)
  for _, source in ipairs(sources) do
    local bestForSource
    for _, runway in pairs(source.runways) do
      local runwayHeading = headingFromRunwayData(runway)
      if runwayHeading then
        local diff = angleDiff(heading, runwayHeading)
        if not bestForSource or diff < bestForSource.diff then
          bestForSource = {
            name = runwayNameFromRunwayData(runway) or runwayNameFromHeading(heading),
            diff = diff,
            method = source.method,
          }
        end
      end
    end

    if bestForSource and bestForSource.diff <= Locator.maxRunwayHeadingError then
      return bestForSource.name, bestForSource.diff, bestForSource.method
    end

    if bestForSource and (not bestOverall or bestForSource.diff < bestOverall.diff) then
      bestOverall = bestForSource
    end
  end

  if bestOverall then
    return nil, bestOverall.diff, "impossible de trouver cette piste dans " .. bestOverall.method
  end

  return nil, nil, "aucune liste de pistes disponible"
end

local function addPoint(name, point, source)
  if not isLsoZoneName(name) then return end
  if not point or not point.x then return end

  local z = point.z or point.y
  if not z then return end

  local threshold = {
    x = point.x,
    y = point.y or land.getHeight({ x = point.x, y = z }) or 0,
    z = z,
  }

  table.insert(Locator.points, {
    name = name,
    source = source,
    heading = parseHeading(name),
    radius = point.radius,
    point = threshold,
    threshold = threshold,
  })
end

local function scanTriggerZones()
  local zones = env
    and env.mission
    and env.mission.triggers
    and env.mission.triggers.zones

  if type(zones) ~= "table" then return end

  for _, zone in pairs(zones) do
    if zone and zone.name and zone.x and zone.y then
      addPoint(zone.name, { x = zone.x, y = zone.alt, z = zone.y, radius = zone.radius }, "trigger zone center")
    end
  end
end

local function nearestAirbase(point)
  if not world or not world.getAirbases then return nil end

  local best = nil
  for _, airbase in ipairs(world.getAirbases() or {}) do
    if airbase and airbase.getName and airbase.getPoint then
      local airbasePoint = airbase:getPoint()
      if airbasePoint then
        local d = distance2D(point, airbasePoint)
        if not best or d < best.distance then
          best = {
            name = airbase:getName(),
            object = airbase,
            point = airbasePoint,
            distance = d,
          }
        end
      end
    end
  end

  return best
end

local function buildReport()
  if #Locator.points == 0 then
    return "LSO Airport Locator: aucune zone trouvee.\nNom attendu: LSO ou LSO:245"
  end

  local lines = {
    "LSO Airport Locator: " .. tostring(#Locator.points) .. " point(s) trouve(s)",
  }

  for _, item in ipairs(Locator.results) do
    if item.airbase then
      local runwayText = ""
      if item.runway then
        runwayText = " | piste " .. item.runway
        if item.heading then
          runwayText = runwayText .. string.format(" | cap %.0f", item.heading)
        end
        if item.runwayHeadingError then
          runwayText = runwayText .. string.format(" | ecart cap %.0f", item.runwayHeadingError)
        end
        if item.runwayMethod then
          runwayText = runwayText .. " | " .. item.runwayMethod
        end
      elseif item.heading then
        runwayText = string.format(" | cap %.0f | impossible de trouver la piste", item.heading)
        if item.runwayHeadingError then
          runwayText = runwayText .. string.format(" | meilleur ecart cap %.0f", item.runwayHeadingError)
        end
        if item.runwayMethod then
          runwayText = runwayText .. " | " .. item.runwayMethod
        end
      else
        runwayText = " | cap non lu | nom attendu LSO:245"
      end
      table.insert(lines, string.format(
        "- %s (%s) -> %s%s | distance %.1f km | seuil X %.0f Z %.0f",
        item.name,
        item.source,
        item.airbase.name,
        runwayText,
        item.airbase.distance / 1000,
        item.point.x,
        item.point.z
      ))
    else
      table.insert(lines, string.format(
        "- %s (%s) -> aucun aeroport trouve | seuil X %.0f Z %.0f",
        item.name,
        item.source,
        item.point.x,
        item.point.z
      ))
    end
  end

  return table.concat(lines, "\n")
end

function Locator.run()
  Locator.points = {}
  Locator.results = {}

  scanTriggerZones()

  for _, item in ipairs(Locator.points) do
    local airbase = nearestAirbase(item.point)
    local runway, runwayHeadingError, runwayMethod = nil, nil, nil
    if airbase and airbase.object and item.heading then
      runway, runwayHeadingError, runwayMethod = bestRunwayForHeading(airbase.object, item.heading)
    elseif item.heading then
      runway, runwayHeadingError, runwayMethod = nil, nil, "aucune liste de pistes disponible"
    end

    table.insert(Locator.results, {
      name = item.name,
      source = item.source,
      point = item.point,
      heading = item.heading,
      airbase = airbase,
      runway = runway,
      runwayHeadingError = runwayHeadingError,
      runwayMethod = runwayMethod,
    })

    if airbase then
      log(string.format(
        "%s from %s -> %s%s, %.1f km",
        item.name,
        item.source,
        airbase.name,
        runway and (" / " .. runway) or "",
        airbase.distance / 1000
      ))
    else
      log(item.name .. " from " .. item.source .. " -> no airbase found")
    end
  end

  trigger.action.outText(buildReport(), 20)
end

Locator.run()
