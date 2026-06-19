local FunctionService = require("api/FunctionService")
local util = require("vuci.util")
local fs = require("nixio.fs")
local package_manager_options = FunctionService:new()

function package_manager_options:GET_TYPE_repository_link()
	local fw_version = util.trim(fs.readfile("/etc/version"))
	local res = util.ubus("mnfinfo", "get")
	local device_model = res and res.mnfinfo and string.sub(res.mnfinfo.name, 1, 6) or ""

	return self:ResponseOK { packages_url = string.format("https://wiki.teltonika-networks.com/view/%s_Package_Downloads#%s", device_model, fw_version) }
end

return package_manager_options
