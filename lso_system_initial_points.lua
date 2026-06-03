-- LSO runway grading system for DCS
-- Place Mission Editor trigger zones named like:
--   LSO:<cap>, for example LSO:245
--
-- Key options in the name:
--   LSO:<cap>     runway heading for this placed threshold point
--   cap=<cap>     also accepted for compatibility
--   airport=NAME  optional override; otherwise nearest airbase is detected
--   elev=12      threshold elevation in meters MSL; optional, terrain height is used if omitted
--   gs=3.5       glideslope angle in degrees
--   width=45     runway width in meters
--   corner=L/R   point is placed on left/right threshold corner, seen while landing
--   dx=0 dz=0    optional manual offset in meters, local runway axes: dx right, dz forward
--   range=5000   detection range before threshold in meters
--   lat=150      lateral detection half-width in meters at threshold
--   fan=0.18     extra lateral detection per meter of distance
--   minspd=105 maxspd=150 optional speed window in knots
--   onspeed=135 spdtol=8 optional target speed if no AoA data is available
--   waveoff=1    enable automatic wave-off calls near the runway
--   axis=auto    heading axis mode; auto tries dcs and legacy
--   fliplineup=1 invert left/right guidance if needed

LSO = LSO or {}

LSO.version = "2026-06-03-lso-guidance-lineup-fix"
LSO.prefix = "LSO:"
LSO.refreshSeconds = 0.5
LSO.messageSeconds = 3.0
LSO.crossingDistance = 35
LSO.maxRunwayHeadingError = 15
LSO.maxSamples = 480
LSO.default = {
  gs = 3.5,
  width = 45,
  range = 5000,
  lat = 150,
  fan = 0.18,
  scoreRange = 1850,
  waveoffDistance = 900,
  waveoff = true,
  elev = nil,
  minspd = nil,
  maxspd = nil,
  onspeed = nil,
  spdtol = 8,
  flipLineup = true,
}

LSO.sites = {}
LSO.tracks = {}
LSO.startupMessage = ""
LSO.startupShownTo = {}

local function log(text)
  env.info("[LSO] " .. tostring(text))
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(s)
  return string.lower(tostring(s or ""))
end

local function tonumberOrNil(v)
  if v == nil then return nil end
  local normalized = tostring(v):gsub(",", ".")
  return tonumber(normalized)
end

local function boolOption(v, default)
  if v == nil or v == "" then return default end
  local text = lower(v)
  if text == "0" or text == "false" or text == "off" or text == "no" or text == "non" then return false end
  if text == "1" or text == "true" or text == "on" or text == "yes" or text == "oui" then return true end
  return default
end

local function runwayNameFromCap(cap)
  local runway = math.floor(((cap % 360) + 5) / 10)
  if runway == 0 then runway = 36 end
  if runway > 36 then runway = runway - 36 end
  return string.format("RWY%02d", runway)
end

local function reciprocalCap(cap)
  return (cap + 180) % 360
end

local function formatCap(cap)
  return string.format("%03d", math.floor((cap % 360) + 0.5) % 360)
end

local function angleDiff(a, b)
  local d = math.abs((a - b + 180) % 360 - 180)
  return d
end

local function normalizeAirbaseName(name)
  local normalized = string.lower(tostring(name or "")):gsub("[^%w]", "")
  return normalized
end

LSO.manualRunwaysByAirbase = {
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

  -- Marianas. Editable fallbacks if DCS getRunways is not usable.
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

local function parseName(name)
  if type(name) ~= "string" then return nil end
  if not string.upper(name):match("^LSO") then return nil end
  local rawLabel = trim(name:match("^[Ll][Ss][Oo][%s:_%-%(]*([^%s;%)]+)") or "")

  local cfg = {}
  for k, v in name:gmatch("([%w_]+)%s*=%s*([^%s;]+)") do
    cfg[lower(k)] = trim(v)
  end

  local capText = rawLabel:match("^(%d+%.?%d*)")
  local directCap = tonumberOrNil(capText)

  local label = rawLabel ~= "" and rawLabel or trim(name)
  cfg.name = directCap and ("cap " .. tostring(math.floor(directCap + 0.5))) or label
  cfg.airport = trim(cfg.airport or cfg.base or cfg.ad or cfg.airfield or "")
  cfg.cap = directCap or tonumberOrNil(cfg.cap or cfg.hdg or cfg.heading)
  if cfg.cap then
    cfg.cap = cfg.cap % 360
  end
  cfg.gs = tonumberOrNil(cfg.gs) or LSO.default.gs
  cfg.width = tonumberOrNil(cfg.width) or LSO.default.width
  cfg.range = tonumberOrNil(cfg.range) or LSO.default.range
  cfg.lat = tonumberOrNil(cfg.lat) or LSO.default.lat
  cfg.fan = tonumberOrNil(cfg.fan) or LSO.default.fan
  cfg.scoreRange = tonumberOrNil(cfg.score or cfg.scorerange or cfg.groove) or LSO.default.scoreRange
  cfg.waveoffDistance = tonumberOrNil(cfg.waveoffdist or cfg.waveoffrange) or LSO.default.waveoffDistance
  cfg.waveoff = boolOption(cfg.waveoff, LSO.default.waveoff)
  cfg.elev = tonumberOrNil(cfg.elev)
  cfg.dx = tonumberOrNil(cfg.dx) or 0
  cfg.dz = tonumberOrNil(cfg.dz) or 0
  cfg.minspd = tonumberOrNil(cfg.minspd)
  cfg.maxspd = tonumberOrNil(cfg.maxspd)
  cfg.onspeed = tonumberOrNil(cfg.onspeed or cfg.speed or cfg.spd)
  cfg.spdtol = tonumberOrNil(cfg.spdtol or cfg.speedtol) or LSO.default.spdtol
  cfg.axis = lower(cfg.axis or cfg.axes or "auto")
  cfg.flipLineup = boolOption(cfg.fliplineup or cfg.invertlineup or cfg.flipaxis, LSO.default.flipLineup)
  if cfg.scoreRange <= 1 then cfg.scoreRange = LSO.default.scoreRange end
  if cfg.waveoffDistance <= 1 then cfg.waveoffDistance = LSO.default.waveoffDistance end
  if cfg.spdtol < 0 then cfg.spdtol = LSO.default.spdtol end
  cfg.corner = lower(cfg.corner or cfg.edge or cfg.side or "")

  if not cfg.cap then
    log("Ignored " .. name .. ": missing heading. Use LSO:<cap>, for example LSO:245")
    return nil
  end

  return cfg
end

local function headingVectors(capDeg)
  local r = math.rad(capDeg)
  -- DCS Vec3 uses x for north/south and z for east/west.
  -- Heading 000 moves toward +x, heading 090 moves toward +z.
  local forward = { x = math.cos(r), z = math.sin(r) }
  local right = { x = -math.sin(r), z = math.cos(r) }
  return forward, right
end

local function legacyHeadingVectors(capDeg)
  local r = math.rad(capDeg)
  local forward = { x = math.sin(r), z = math.cos(r) }
  local right = { x = math.cos(r), z = -math.sin(r) }
  return forward, right
end

local function buildHeadingAxes(capDeg, preferredAxis)
  local dcsForward, dcsRight = headingVectors(capDeg)
  local legacyForward, legacyRight = legacyHeadingVectors(capDeg)
  local axes = {
    { name = "dcs", forward = dcsForward, right = dcsRight },
    { name = "legacy", forward = legacyForward, right = legacyRight },
  }

  if preferredAxis == "legacy" or preferredAxis == "old" then
    axes[1], axes[2] = axes[2], axes[1]
  end

  return axes
end

local function shiftedThreshold(point, cfg)
  local forward, right = headingVectors(cfg.cap)
  local x = point.x
  local z = point.z or point.y

  -- "corner" means the editor point sits on a threshold corner instead of
  -- the runway centerline. Left/right are seen from the pilot on landing.
  if cfg.corner == "l" or cfg.corner == "left" or cfg.corner == "gauche" then
    x = x + right.x * (cfg.width * 0.5)
    z = z + right.z * (cfg.width * 0.5)
  elseif cfg.corner == "r" or cfg.corner == "right" or cfg.corner == "droite" then
    x = x - right.x * (cfg.width * 0.5)
    z = z - right.z * (cfg.width * 0.5)
  end

  if cfg.dx ~= 0 then
    x = x + right.x * cfg.dx
    z = z + right.z * cfg.dx
  end
  if cfg.dz ~= 0 then
    x = x + forward.x * cfg.dz
    z = z + forward.z * cfg.dz
  end

  local terrainElev = land.getHeight({ x = x, y = z }) or 0
  local elev = cfg.elev or point.y or terrainElev
  return { x = x, y = elev, z = z, terrain = terrainElev }
end

local function makeSite(point, cfg, source)
  local axes = buildHeadingAxes(cfg.cap, cfg.axis)
  local forward, right = axes[1].forward, axes[1].right
  local threshold = shiftedThreshold(point, cfg)
  return {
    name = cfg.name,
    airport = cfg.airport,
    source = source,
    cap = cfg.cap,
    gs = cfg.gs,
    width = cfg.width,
    range = cfg.range,
    lat = cfg.lat,
    fan = cfg.fan,
    scoreRange = cfg.scoreRange,
    waveoffDistance = cfg.waveoffDistance,
    waveoff = cfg.waveoff,
    minspd = cfg.minspd,
    maxspd = cfg.maxspd,
    onspeed = cfg.onspeed,
    spdtol = cfg.spdtol,
    flipLineup = cfg.flipLineup,
    threshold = threshold,
    forward = forward,
    right = right,
    axes = axes,
    axisMode = cfg.axis,
  }
end

local function distance2D(a, b)
  local dx = (a.x or 0) - (b.x or 0)
  local az = a.z or a.y or 0
  local bz = b.z or b.y or 0
  local dz = az - bz
  return math.sqrt(dx * dx + dz * dz)
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
  local direct = LSO.manualRunwaysByAirbase[key]
  if direct then return direct end

  for knownKey, runways in pairs(LSO.manualRunwaysByAirbase) do
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
            name = runwayNameFromRunwayData(runway) or runwayNameFromCap(heading),
            diff = diff,
            method = source.method,
          }
        end
      end
    end

    if bestForSource and bestForSource.diff <= LSO.maxRunwayHeadingError then
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

local function nearestAirbase(point, forcedAirport)
  if not world or not world.getAirbases then return nil end

  local best
  for _, airbase in ipairs(world.getAirbases() or {}) do
    if airbase and airbase.getName and airbase.getPoint then
      local airportName = airbase:getName()
      if airportName and (not forcedAirport or forcedAirport == "" or airportName == forcedAirport) then
        local airbasePoint = airbase:getPoint()
        if airbasePoint then
          local d = distance2D(point, airbasePoint)
          if not best or d < best.distance then
            best = {
              name = airportName,
              object = airbase,
              point = airbasePoint,
              distance = d,
            }
          end
        end
      end
    end
  end

  return best
end

local function resolveAirportAndRunway(point, cap, forcedAirport)
  local airbase = nearestAirbase(point, forcedAirport)
  if not airbase then
    return forcedAirport or "", nil, nil, nil, nil, "aucun aeroport trouve"
  end

  local runway, headingError, method = bestRunwayForHeading(airbase.object, cap)
  return airbase.name, airbase.distance, runway, nil, headingError, method
end

local function siteDisplayName(site)
  if site.airport and site.airport ~= "" then
    return site.airport .. " / " .. site.name
  end
  return site.name
end

local function startupReport()
  if #LSO.sites == 0 then
    return "LSO: script lance, mais aucune piste trouvee.\nNom attendu: LSO:<cap>, exemple LSO:245"
  end

  local lines = {
    "LSO: script lance OK",
    tostring(#LSO.sites) .. " piste(s) detectee(s):",
  }

  for _, site in ipairs(LSO.sites) do
    local matchInfo = ""
    if site.airportDistance then
      matchInfo = matchInfo .. string.format(" | AD %.1f km", site.airportDistance / 1000)
    end
    if site.runwayDistance then
      matchInfo = matchInfo .. string.format(" | RW %.0fm", site.runwayDistance)
    end
    if site.headingError then
      matchInfo = matchInfo .. string.format(" | ecart cap %.0f", site.headingError)
    end
    if site.resolveMethod then
      matchInfo = matchInfo .. " | " .. site.resolveMethod
    end
    if site.axisMode and site.axisMode ~= "auto" then
      matchInfo = matchInfo .. " | axis " .. site.axisMode
    else
      matchInfo = matchInfo .. " | axis auto"
    end
    if site.flipLineup then
      matchInfo = matchInfo .. " | lineup inverse"
    else
      matchInfo = matchInfo .. " | lineup normal"
    end
    matchInfo = matchInfo .. string.format(" | zone %.0fm +/-%.0f->%.0fm", site.range, site.lat, site.lat + site.range * site.fan)
    if site.onspeed then
      matchInfo = matchInfo .. string.format(" | on-speed %.0f+/-%.0f kt", site.onspeed, site.spdtol)
    elseif site.minspd or site.maxspd then
      matchInfo = matchInfo .. string.format(" | vitesse %.0f-%.0f kt", site.minspd or 0, site.maxspd or 999)
    end
    if not site.waveoff then
      matchInfo = matchInfo .. " | waveoff off"
    end
    table.insert(lines, string.format(
      "- %s | detection cote %s -> guidage cap %s | seuil X %.0f Z %.0f | elev %.0fm%s",
      siteDisplayName(site), formatCap(reciprocalCap(site.cap)), formatCap(site.cap),
      site.threshold.x, site.threshold.z, site.threshold.y, matchInfo
    ))
  end

  return table.concat(lines, "\n")
end

local function addSite(point, name, source)
  local cfg = parseName(name)
  if not cfg or not point then return end
  local site = makeSite(point, cfg, source)
  local airportName, airportDistance, runwayName, runwayDistance, headingError, resolveMethod =
    resolveAirportAndRunway(site.threshold, site.cap, site.airport)
  site.airport = airportName or site.airport or ""
  site.name = runwayName or site.name
  site.airportDistance = airportDistance
  site.runwayDistance = runwayDistance
  site.headingError = headingError
  site.resolveMethod = resolveMethod
  table.insert(LSO.sites, site)
  log(string.format(
    "Loaded %s/%s from %s: cap %.1f, threshold x %.1f z %.1f elev %.1f",
    site.airport, site.name, source, site.cap, site.threshold.x, site.threshold.z, site.threshold.y
  ))
end

local function scanTriggerZones()
  if not env or not env.mission or not env.mission.triggers or not env.mission.triggers.zones then
    return
  end
  for _, zone in pairs(env.mission.triggers.zones) do
    if zone and zone.name and zone.x and zone.y then
      addSite({ x = zone.x, y = zone.alt or land.getHeight({ x = zone.x, y = zone.y }), z = zone.y }, zone.name, "trigger zone center")
    end
  end
end

local function scanNavPoints()
  if not env or not env.mission or not env.mission.coalition then return end
  for coalitionName, coalitionData in pairs(env.mission.coalition) do
    if type(coalitionData) == "table" and type(coalitionData.nav_points) == "table" then
      for _, point in pairs(coalitionData.nav_points) do
        if point and point.name and point.x and point.y then
          addSite({ x = point.x, y = point.alt, z = point.y }, point.name, coalitionName .. " nav point")
        end
      end
    end
  end
end

local function unitId(unit)
  if not unit or not Unit.isExist(unit) then return nil end
  return unit:getID()
end

local function unitName(unit)
  if not unit or not Unit.isExist(unit) then return "unknown" end
  return unit:getPlayerName() or unit:getName() or "unknown"
end

local function speedKnots(unit, velocity)
  local v = velocity or unit:getVelocity()
  local ms = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
  return ms * 1.94384449
end

local function clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function sample(unit, site, axis)
  axis = axis or { name = "dcs", forward = site.forward, right = site.right }
  local p = unit:getPoint()
  local v = unit:getVelocity()
  local rx = p.x - site.threshold.x
  local rz = p.z - site.threshold.z
  local forwardMeters = rx * axis.forward.x + rz * axis.forward.z
  local dist = -forwardMeters
  local lineup = rx * axis.right.x + rz * axis.right.z
  local alt = p.y - site.threshold.y
  local idealAlt = math.tan(math.rad(site.gs)) * math.max(dist, 0)
  local gsError = alt - idealAlt
  local spd = speedKnots(unit, v)
  local closure = (v.x * axis.forward.x + v.z * axis.forward.z) * 1.94384449
  local lateralRate = (v.x * axis.right.x + v.z * axis.right.z) * 1.94384449
  if site.flipLineup then
    lineup = -lineup
    lateralRate = -lateralRate
  end
  local sinkFpm = -(v.y or 0) * 196.850394
  local gsAngle = 0
  local lineupAngle = 0
  if dist > 1 then
    gsAngle = math.deg(math.atan(alt / dist))
    lineupAngle = math.deg(math.atan(lineup / dist))
  end
  return {
    dist = dist,
    lineup = lineup,
    alt = alt,
    idealAlt = idealAlt,
    gsError = gsError,
    gsAngle = gsAngle,
    gsAngleError = gsAngle - site.gs,
    lineupAngle = lineupAngle,
    spd = spd,
    closure = closure,
    lateralRate = lateralRate,
    sinkFpm = sinkFpm,
    time = timer.getTime(),
    axisName = axis.name,
  }
end

local function isInsideEnvelope(s, site)
  if s.dist < -80 or s.dist > site.range then return false end
  local lateralLimit = site.lat + math.max(s.dist, 0) * site.fan
  if math.abs(s.lineup) > lateralLimit then return false end
  if s.alt < -20 or s.alt > 900 then return false end
  return true
end

local function axisByName(site, axisName)
  if not axisName then return nil end
  for _, axis in ipairs(site.axes or {}) do
    if axis.name == axisName then return axis end
  end
  return nil
end

local function bestSampleForSite(unit, site, preferredAxisName)
  local best
  local preferredAxis = axisByName(site, preferredAxisName)

  if preferredAxis then
    local s = sample(unit, site, preferredAxis)
    if isInsideEnvelope(s, site) then return s end
  end

  for _, axis in ipairs(site.axes or {}) do
    if not preferredAxis or axis.name ~= preferredAxis.name then
      local s = sample(unit, site, axis)
      if isInsideEnvelope(s, site) and (not best or math.abs(s.lineup) < math.abs(best.lineup)) then
        best = s
      end
    end
  end

  return best
end

local function passPhase(s, site)
  local d = math.max(s.dist, 0)
  if d > site.scoreRange then return "initiale" end
  if d > site.scoreRange * 0.55 then return "depart groove" end
  if d > site.scoreRange * 0.25 then return "milieu" end
  if d > LSO.crossingDistance then return "proche" end
  return "seuil"
end

local function lineTolerance(s, site)
  local d = math.max(s.dist, 0)
  return math.max(site.width * 0.22, 8 + d * 0.008)
end

local function gsTolerance(s)
  local d = math.max(s.dist, 0)
  return math.max(5, d * 0.010)
end

local function speedError(s, site)
  if site.onspeed then
    return math.max(0, math.abs(s.spd - site.onspeed) - site.spdtol)
  end
  if site.minspd and s.spd < site.minspd then
    return site.minspd - s.spd
  end
  if site.maxspd and s.spd > site.maxspd then
    return s.spd - site.maxspd
  end
  return 0
end

local function speedCallout(s, site)
  if site.onspeed then
    local delta = s.spd - site.onspeed
    if delta < -site.spdtol then return "lent" end
    if delta > site.spdtol then return "rapide" end
    return "on-speed"
  end
  if site.minspd and s.spd < site.minspd then return "lent" end
  if site.maxspd and s.spd > site.maxspd then return "rapide" end
  if site.minspd or site.maxspd then return "vitesse OK" end
  return nil
end

local function callout(s, site)
  local bits = { passPhase(s, site) }
  local lineLimit = lineTolerance(s, site)
  local gsLimit = gsTolerance(s)
  local stable = true

  if s.lineup > lineLimit then
    stable = false
    if s.lineup > lineLimit * 2 then
      table.insert(bits, "trop a droite, corrige gauche")
    else
      table.insert(bits, "droite, corrige gauche")
    end
  elseif s.lineup < -lineLimit then
    stable = false
    if s.lineup < -lineLimit * 2 then
      table.insert(bits, "trop a gauche, corrige droite")
    else
      table.insert(bits, "gauche, corrige droite")
    end
  else
    table.insert(bits, "axe")
  end

  if s.gsError > gsLimit then
    stable = false
    if s.gsError > gsLimit * 2 then
      table.insert(bits, "tres haut")
    else
      table.insert(bits, "haut")
    end
  elseif s.gsError < -gsLimit then
    stable = false
    if s.gsError < -gsLimit * 2 then
      table.insert(bits, "tres bas")
    else
      table.insert(bits, "bas")
    end
  else
    table.insert(bits, "plan")
  end

  local speedText = speedCallout(s, site)
  if speedText then
    if speedText ~= "on-speed" and speedText ~= "vitesse OK" then stable = false end
    table.insert(bits, speedText)
  end

  if stable then
    table.insert(bits, "continue")
  end

  return table.concat(bits, " / ")
end

local function unsafeDecision(s, site)
  if not site.waveoff or s.dist > site.waveoffDistance or s.dist < -20 then return nil end

  local d = math.max(s.dist, 0)
  local lineWave = math.max(site.width * 0.9, 20 + d * 0.04)
  local lowWave = math.max(16, d * 0.035)
  local highWave = lowWave * 1.7

  if math.abs(s.lineup) > lineWave then
    return "WAVE OFF: axe dangereux"
  end
  if s.gsError < -lowWave then
    return "WAVE OFF: trop bas"
  end
  if d < 400 and s.gsError > highWave then
    return "WAVE OFF: trop haut proche seuil"
  end
  if site.onspeed and s.spd < site.onspeed - site.spdtol - 18 then
    return "WAVE OFF: trop lent"
  end
  if site.minspd and s.spd < site.minspd - 12 then
    return "WAVE OFF: trop lent"
  end
  if d < 550 and s.sinkFpm > 1800 then
    return "WAVE OFF: vario trop fort"
  end

  return nil
end

local function sampleWeight(s, site)
  local d = clamp(math.max(s.dist, 0), 0, site.scoreRange)
  return 1 + (1 - d / site.scoreRange) * 2.5
end

local function scoreTrack(track)
  if not track or not track.samples or #track.samples < 3 then
    return "NO GRADE", 0, "pas assez de donnees"
  end

  local site = track.site
  local totalWeight = 0
  local totalLine, totalGs, totalSpeed = 0, 0, 0
  local maxLine, maxGs, maxSpeed = 0, 0, 0
  local faultCount = 0
  local closest

  for _, s in ipairs(track.samples) do
    local al = math.abs(s.lineup)
    local ag = math.abs(s.gsError)
    local se = speedError(s, site)
    local w = sampleWeight(s, site)

    totalWeight = totalWeight + w
    totalLine = totalLine + al * w
    totalGs = totalGs + ag * w
    totalSpeed = totalSpeed + se * w

    if al > maxLine then maxLine = al end
    if ag > maxGs then maxGs = ag end
    if se > maxSpeed then maxSpeed = se end
    if al > lineTolerance(s, site) * 1.8 then faultCount = faultCount + 1 end
    if ag > gsTolerance(s) * 1.8 then faultCount = faultCount + 1 end
    if se > 12 then faultCount = faultCount + 1 end

    if not closest or math.abs(s.dist) < math.abs(closest.dist) then
      closest = s
    end
  end

  if totalWeight <= 0 then
    return "NO GRADE", 0, "pas assez de donnees"
  end

  local avgLine = totalLine / totalWeight
  local avgGs = totalGs / totalWeight
  local avgSpeed = totalSpeed / totalWeight
  local score = 100
  score = score - avgLine * 0.45 - maxLine * 0.13
  score = score - avgGs * 0.80 - maxGs * 0.22
  score = score - avgSpeed * 0.60 - maxSpeed * 0.20
  score = score - faultCount * 1.5
  if track.waveoffReason then score = math.min(score, 45) end
  if not track.crossed and not track.waveoffReason then score = math.min(score, 50) end
  if score < 0 then score = 0 end

  local grade
  if track.waveoffReason then
    grade = "WAVE OFF"
  elseif not track.crossed then
    grade = "NO GRADE"
  elseif score >= 90 and maxLine < 18 and maxGs < 12 and maxSpeed < 8 then
    grade = "OK 3"
  elseif score >= 82 then
    grade = "OK"
  elseif score >= 70 then
    grade = "FAIR"
  elseif score >= 55 then
    grade = "NO GRADE"
  else
    grade = "CUT PASS"
  end

  local thresholdDetails = ""
  if closest then
    thresholdDetails = string.format(
      "\nSeuil: axe %+.0fm | plan %+.0fm | %.0f kt | vario %.0f ft/min",
      closest.lineup, closest.gsError, closest.spd, closest.sinkFpm
    )
  end

  local details = string.format(
    "Score %.0f | Axe moy %.0fm max %.0fm\nPlan moy %.0fm max %.0fm | Vitesse err moy %.0f kt max %.0f kt%s",
    score, avgLine, maxLine, avgGs, maxGs, avgSpeed, maxSpeed, thresholdDetails
  )
  return grade, score, details
end

local function finishTrack(id, reason)
  local track = LSO.tracks[id]
  if not track then return end
  LSO.tracks[id] = nil

  local unit = track.unit
  if unit and Unit.isExist(unit) then
    local grade, _, details = scoreTrack(track)
    local endReason = track.waveoffReason or reason or ""
    trigger.action.outTextForUnit(unit:getID(), string.format(
      "LSO %s: %s\n%s\nFin: %s",
      track.site.name, grade, details, endReason
    ), 12)
  end
end

local function updateUnit(unit)
  if not unit or not Unit.isExist(unit) then return end
  local id = unitId(unit)
  if not id then return end

  local track = LSO.tracks[id]
  local bestSite, bestSample
  for _, site in ipairs(LSO.sites) do
    local preferredAxisName = track and track.site == site and track.axisName or nil
    local s = bestSampleForSite(unit, site, preferredAxisName)
    if s and (not bestSample or s.dist < bestSample.dist) then
      bestSite, bestSample = site, s
    end
  end

  if bestSite and bestSample then
    if track and track.site ~= bestSite then
      finishTrack(id, "changement piste")
      track = nil
    end

    if not track then
      track = {
        unit = unit,
        site = bestSite,
        samples = {},
        lastMessage = 0,
        lastPhase = "",
        axisName = bestSample.axisName,
        waveoffReason = nil,
        crossed = false,
      }
      LSO.tracks[id] = track
      if not LSO.startupShownTo[id] and LSO.startupMessage ~= "" then
        LSO.startupShownTo[id] = true
        trigger.action.outTextForUnit(id, LSO.startupMessage, 12)
      end
      trigger.action.outTextForUnit(id, string.format(
        "LSO %s: entree zone de detection\nDetection cote %s | Guidage cap %s | Axe %s | Dist %.0fm | Lineup %+.0fm | Plan %+.0fm | %.0f kt",
        siteDisplayName(bestSite), formatCap(reciprocalCap(bestSite.cap)), formatCap(bestSite.cap),
        tostring(bestSample.axisName or "auto"), bestSample.dist, bestSample.lineup,
        bestSample.gsError, bestSample.spd
      ), 8)
      log("Tracking " .. unitName(unit) .. " on " .. bestSite.name .. " axis " .. tostring(bestSample.axisName))
    end

    track.axisName = track.axisName or bestSample.axisName

    table.insert(track.samples, bestSample)
    if #track.samples > LSO.maxSamples then table.remove(track.samples, 1) end

    local now = timer.getTime()
    local unsafe = unsafeDecision(bestSample, bestSite)
    if unsafe and not track.waveoffReason then
      track.waveoffReason = unsafe
      track.lastMessage = now
      trigger.action.outTextForUnit(id, string.format(
        "LSO %s: %s\nDist %.0fm | Axe %+.0fm | Plan %+.0fm | %.0f kt | Vario %.0f",
        bestSite.name, unsafe, bestSample.dist, bestSample.lineup,
        bestSample.gsError, bestSample.spd, bestSample.sinkFpm
      ), 8)
      log(unitName(unit) .. " waveoff on " .. bestSite.name .. ": " .. unsafe)
    end

    local phase = passPhase(bestSample, bestSite)
    local shouldTalk = now - track.lastMessage >= LSO.messageSeconds or phase ~= track.lastPhase
    if shouldTalk and bestSample.dist > LSO.crossingDistance and not track.waveoffReason then
      track.lastMessage = now
      track.lastPhase = phase
      trigger.action.outTextForUnit(id, string.format(
        "LSO %s: %s\nDist %.0fm | Axe %+.0fm | Plan %+.0fm | %.0f kt | Vario %.0f",
        bestSite.name, callout(bestSample, bestSite), bestSample.dist,
        bestSample.lineup, bestSample.gsError, bestSample.spd, bestSample.sinkFpm
      ), 3)
    end

    if bestSample.dist <= LSO.crossingDistance and not track.crossed then
      track.crossed = true
      finishTrack(id, "passage seuil")
    end
  elseif track then
    finishTrack(id, "sortie zone")
  end
end

local function updatePlayers()
  for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
    local players = coalition.getPlayers(side) or {}
    for _, unit in ipairs(players) do
      local id = unitId(unit)
      if id and not LSO.startupShownTo[id] and LSO.startupMessage ~= "" then
        LSO.startupShownTo[id] = true
        trigger.action.outTextForUnit(id, LSO.startupMessage, 12)
      end
      if #LSO.sites > 0 then
        updateUnit(unit)
      end
    end
  end

  return timer.getTime() + LSO.refreshSeconds
end

function LSO.init()
  LSO.sites = {}
  LSO.tracks = {}
  LSO.startupShownTo = {}
  scanTriggerZones()
  LSO.startupMessage = startupReport()

  if #LSO.sites == 0 then
    log("No LSO sites found. Name a trigger zone with prefix LSO:")
    trigger.action.outText(LSO.startupMessage, 12)
  else
    trigger.action.outText(LSO.startupMessage, 12)
  end

  timer.scheduleFunction(updatePlayers, nil, timer.getTime() + 2)
end

LSO.init()
