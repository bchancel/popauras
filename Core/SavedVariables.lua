local _, ns = ...

local Tables = ns.util.Tables

local SavedVariables = {}
ns.SavedVariables = SavedVariables

local function TrimSavedVariables(db)
  if type(db) ~= "table" then
    return
  end

  if type(db.exports) == "table" then
    db.exports.history = nil
    if next(db.exports) == nil then
      db.exports = nil
    end
  end

  if type(db.runtime) == "table" then
    db.runtime.learnedTargetDurations = nil
    db.runtime.talentCatalog = nil
    if next(db.runtime) == nil then
      db.runtime = nil
    end
  end
end

function SavedVariables:Initialize()
  PopAurasDB = PopAurasDB or {}
  Tables.MergeDefaults(PopAurasDB, ns.Defaults.database)
  ns.Migration:Run(PopAurasDB)
  TrimSavedVariables(PopAurasDB)
  ns.session = ns.session or {}
  ns.db = PopAurasDB
end
