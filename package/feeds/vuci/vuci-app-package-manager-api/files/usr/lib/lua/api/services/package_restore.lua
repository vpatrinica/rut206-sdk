local ConfigService = require("api/ConfigService")

local PackageRestoreService = ConfigService:new({
	delete = false,
	create = false
})


local PackageRestore = PackageRestoreService:section("package_restore", "package_restore")

	local opt_enabled = PackageRestore:option("enabled")
		opt_enabled.cfg_require = true
		function opt_enabled:validate(value)
			return self.dt:is_bool(value)
		end

return PackageRestoreService
