
local board = require("vuci.board")
local o_utils = require "vuci.opkg_utils_common"
local util = require "vuci.util"

local OPKG_CONF_FILE = "/etc/opkg.conf"

o_utils.OPKG_CMD = "opkg --force_feeds /etc/opkg/teltonikafeeds.conf -f %s --force-removal-of-essential-packages " % OPKG_CONF_FILE
o_utils.OPKG_DATA = { "--force_feeds", "/etc/opkg/teltonikafeeds.conf", "--conf", OPKG_CONF_FILE, "--force-removal-of-essential-packages"}
o_utils.legacy = true

function o_utils._get_info(pkg_dir, pkg_file_name)
	if pkg_file_name ~= "control_dir" and pkg_file_name ~= "main" and pkg_file_name ~= "main.sig" then
		util.exec("/bin/tar -xzC%s/control_dir -f %s/%s" % {pkg_dir, pkg_dir, pkg_file_name})
		return util.exec("zcat %s/control_dir/control.tar.gz" % pkg_dir)
	end


	return nil
end

function o_utils._install_packages(pkg_name, ipk_file, pkg_dir, ipk_deps)
	-- main pkg must be first, otherwise depends break when removing packages
	local ipk_files = {pkg_dir .. "/" .. ipk_file:match("([^:]+):")}
	for _, dep in ipairs(ipk_deps) do
		ipk_files[#ipk_files + 1] = pkg_dir .. "/" .. dep:match("([^:]+):")
	end

	return o_utils.opkg_call("install", ipk_files, o_utils.OPKG_DATA, "--tmp-dir", pkg_dir)
end

---Returns true if package's "Router" key matches device's family (e.g. RUTX)
---@param arch string?
---@param family string?
---@return boolean
---@return string hw_arch device's family name
function o_utils.check_package_arch(arch, family)
	local hw_arch = board:get_family_name()
	if hw_arch ~= family then
		return false, hw_arch
	end

	return true, hw_arch
end

return o_utils