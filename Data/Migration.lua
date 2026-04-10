local _, ns = ...

local Migration = {}
ns.Migration = Migration

function Migration:Run(db)
  db.version = db.version or 0
  db.auras = db.auras or {}
  db.ui = db.ui or {}
  if type(db.ui.selectedTriggerIndex) ~= "number" or db.ui.selectedTriggerIndex < 1 then
    db.ui.selectedTriggerIndex = 1
  end

  for auraId, aura in pairs(db.auras) do
    if type(aura) == "table" then
      aura.id = aura.id or auraId
      if db.version < 3 and type(aura.load) == "table" then
        local legacyEncounterId = tonumber(aura.load.encounterId or 0) or 0
        local hasInstanceId = (tonumber(aura.load.instanceId or 0) or 0) > 0
        if legacyEncounterId > 0 and not hasInstanceId then
          aura.load.instanceId = legacyEncounterId
          aura.load.encounterId = 0
        end
      end
      ns.Defaults:ApplyAuraDefaults(aura)
    end
  end

  if db.version < ns.Constants.DB_VERSION then
    db.version = ns.Constants.DB_VERSION
  end
  return db
end
