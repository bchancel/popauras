local _, ns = ...

local Migration = {}
ns.Migration = Migration

function Migration:Run(db)
  db.version = db.version or 0
  if db.version < ns.Constants.DB_VERSION then
    db.version = ns.Constants.DB_VERSION
  end
  return db
end
