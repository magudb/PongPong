-- tests/fixtures/lua/registry_bad_reserved.lua
-- BAD on purpose (finding registry_header): `functions` is the parser's own result key (the parsed functions of the file),
-- never a table of the file, so a registry cannot be named like it. Nothing from this file is registered.

kind = "registry"
registry = "functions"

function fixture_helper(context)
  return nil
end
