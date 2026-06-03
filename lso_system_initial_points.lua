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

LSO = LSO or {}

LSO.version = "2026-06-03-trigger-zones"
LSO.prefix = "LSO:"
LSO.refreshSeconds = 1.0
LSO.messageSeconds = 4.0
LSO.crossingDistance = 35
LSO.maxRunwayHeadingError = 15
LSO.default = {
  gs = 3.5,
  width = 45,
  range = 5000,
  lat = 150,
  fan = 0.18,
  elev = nil,
  minspd = nil,
  maxspd = nil,
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

local function runwayNameFromCap(cap)
  local runway = math.floor(((cap % 360) + 5) / 10)
  if runway == 0 then runway = 36 end
  if runway > 36 then runway = runway - 36 end
  return string.format("RWY%02d", runway)
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
  cfg.elev = tonumberOrNil(cfg.elev)
  cfg.dx = tonumberOrNil(cfg.dx) or 0
  cfg.dz = tonumberOrNil(cfg.dz) or 0
  cfg.minspd = tonumberOrNil(cfg.minspd)
  cfg.maxspd = tonumberOrNil(cfg.maxspd)
  cfg.corner = lower(cfg.corner or cfg.edge or cfg.side or "")

  if not cfg.cap then
    log("Ignored " .. name .. ": missing heading. Use LSO:<cap>, for example LSO:245")
    return nil
  end

  return cfg
end

local function headingVectors(capDeg)
  local r = math.rad(capDeg)
  local forward = { x = math.sin(r), z = math.cos(r) }
  local right = { x = math.cos(r), z = -math.sin(r) }
  return forward, right
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
  local forward, right = headingVectors(cfg.cap)
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
    minspd = cfg.minspd,
    maxspd = cfg.maxspd,
    threshold = threshold,
    forward = forward,
    right = right,
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
    table.insert(lines, string.format(
      "- %s | cap %.0f | seuil X %.0f Z %.0f | elev %.0fm%s",
      siteDisplayName(site), site.cap, site.threshold.x, site.threshold.z, site.threshold.y, matchInfo
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

local function speedKnots(unit)
  local v = unit:getVelocity()
  local ms = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
  return ms * 1.94384449
end

local function sample(unit, site)
  local p = unit:getPoint()
  local rx = p.x - site.threshold.x
  local rz = p.z - site.threshold.z
  local forwardMeters = rx * site.forward.x + rz * site.forward.z
  local dist = -forwardMeters
  local lineup = rx * site.right.x + rz * site.right.z
  local alt = p.y - site.threshold.y
  local idealAlt = math.tan(math.rad(site.gs)) * math.max(dist, 0)
  local gsError = alt - idealAlt
  local spd = speedKnots(unit)
  return {
    dist = dist,
    lineup = lineup,
    alt = alt,
    idealAlt = idealAlt,
    gsError = gsError,
    spd = spd,
  }
end

local function isInsideEnvelope(s, site)
  if s.dist < -80 or s.dist > site.range then return false end
  local lateralLimit = site.lat + math.max(s.dist, 0) * site.fan
  if math.abs(s.lineup) > lateralLimit then return false end
  if s.alt < -20 or s.alt > 900 then return false end
  return true
end

local function callout(s, site)
  local bits = {}
  local lineLimit = math.max(8, site.width * 0.25)
  local gsLimit = math.max(4, s.dist * 0.012)

  if s.lineup > lineLimit then
    table.insert(bits, "droite")
  elseif s.lineup < -lineLimit then
    table.insert(bits, "gauche")
  else
    table.insert(bits, "axe")
  end

  if s.gsError > gsLimit then
    table.insert(bits, "haut")
  elseif s.gsError < -gsLimit then
    table.insert(bits, "bas")
  else
    table.insert(bits, "plan")
  end

  if site.minspd and s.spd < site.minspd then
    table.insert(bits, "lent")
  elseif site.maxspd and s.spd > site.maxspd then
    table.insert(bits, "rapide")
  end

  return table.concat(bits, " / ")
end

local function scoreTrack(track)
  if not track or not track.samples or #track.samples < 3 then
    return "NO GRADE", 0, "pas assez de donnees"
  end

  local totalLine, totalGs, maxLine, maxGs, speedFaults = 0, 0, 0, 0, 0
  for _, s in ipairs(track.samples) do
    local al = math.abs(s.lineup)
    local ag = math.abs(s.gsError)
    totalLine = totalLine + al
    totalGs = totalGs + ag
    if al > maxLine then maxLine = al end
    if ag > maxGs then maxGs = ag end
    if track.site.minspd and s.spd < track.site.minspd then speedFaults = speedFaults + 1 end
    if track.site.maxspd and s.spd > track.site.maxspd then speedFaults = speedFaults + 1 end
  end

  local n = #track.samples
  local avgLine = totalLine / n
  local avgGs = totalGs / n
  local score = 100
  score = score - avgLine * 0.9 - maxLine * 0.25
  score = score - avgGs * 1.4 - maxGs * 0.35
  score = score - speedFaults * 2
  if score < 0 then score = 0 end

  local grade = "OK"
  if score >= 88 and maxLine < 15 and maxGs < 10 then
    grade = "OK 3"
  elseif score >= 75 then
    grade = "FAIR"
  elseif score >= 55 then
    grade = "NO GRADE"
  else
    grade = "WAVE OFF"
  end

  local details = string.format("score %.0f | moy axe %.0fm | moy plan %.0fm", score, avgLine, avgGs)
  return grade, score, details
end

local function finishTrack(id, reason)
  local track = LSO.tracks[id]
  if not track then return end
  LSO.tracks[id] = nil

  local unit = track.unit
  if unit and Unit.isExist(unit) then
    local grade, _, details = scoreTrack(track)
    trigger.action.outTextForUnit(unit:getID(), string.format(
      "LSO %s: %s\n%s\n%s",
      track.site.name, grade, details, reason or ""
    ), 12)
  end
end

local function updateUnit(unit)
  if not unit or not Unit.isExist(unit) then return end
  local id = unitId(unit)
  if not id then return end

  local bestSite, bestSample
  for _, site in ipairs(LSO.sites) do
    local s = sample(unit, site)
    if isInsideEnvelope(s, site) and (not bestSample or s.dist < bestSample.dist) then
      bestSite, bestSample = site, s
    end
  end

  local track = LSO.tracks[id]
  if bestSite and bestSample then
    if not track or track.site ~= bestSite then
      track = {
        unit = unit,
        site = bestSite,
        samples = {},
        lastMessage = 0,
        crossed = false,
      }
      LSO.tracks[id] = track
      if not LSO.startupShownTo[id] and LSO.startupMessage ~= "" then
        LSO.startupShownTo[id] = true
        trigger.action.outTextForUnit(id, LSO.startupMessage, 12)
      end
      trigger.action.outTextForUnit(id, "LSO " .. bestSite.name .. ": contact", 5)
      log("Tracking " .. unitName(unit) .. " on " .. bestSite.name)
    end

    table.insert(track.samples, bestSample)
    if #track.samples > 240 then table.remove(track.samples, 1) end

    local now = timer.getTime()
    if now - track.lastMessage >= LSO.messageSeconds and bestSample.dist > LSO.crossingDistance then
      track.lastMessage = now
      trigger.action.outTextForUnit(id, string.format(
        "LSO %s: %s\nDist %.0fm | Axe %.0fm | Plan %+0.fm | %.0f kt",
        bestSite.name, callout(bestSample, bestSite), bestSample.dist,
        bestSample.lineup, bestSample.gsError, bestSample.spd
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
