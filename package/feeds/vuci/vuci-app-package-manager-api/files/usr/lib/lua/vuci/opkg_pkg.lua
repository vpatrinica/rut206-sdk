local util = require "vuci.util"
local fs = require "nixio.fs"
local board = require("vuci.board")
local o_utils = require "vuci.opkg_utils"

local PKG_TYPES = o_utils.PKG_TYPES
local MSG_STR = o_utils.MSG_STR
local MSG_CODES = o_utils.MSG_CODES
local ERR_CODES = o_utils.ERR_CODES

--- Package class used for easier management of packages (opkg .cotrol files)
---@class OpkgPkg
---@field pkg_name string
---@field app_name string
---@field pkg_dir string
---@field pending boolean?
---@field pkg_text string?
---@field ipk_deps [string]?
---@field ipk_file string?
---@field private _opt_cache {[string]: string}
---@overload fun(pkg_text: string?, app_name: string?, pkg_name: string?, pkg_dir: string?): OpkgPkg
local OpkgPkg = util.class()
function OpkgPkg.__init__(self, pkg_text, app_name, pkg_name, pkg_dir)
	self.pkg_text = pkg_text
	self.app_name = app_name
	self.pkg_name = pkg_name
	self.pkg_dir = pkg_dir
	self._opt_cache = {}

	if not app_name and pkg_text then
		self.app_name = assert(self:get("AppName") or self:get("Package"), "package must have app_name and pkg_name")
	end
	if not pkg_name and pkg_text then
		self.pkg_name = assert(self:get("Package"), "package must have app_name and pkg_name")
	end

	if pkg_text then
		local ipk_deps = util.trim(self:get("ipk_deps") or "")
		self.ipk_deps = #ipk_deps > 0 and util.split(ipk_deps, "%s+", nil, true) or {}
		self.ipk_file = self:get("ipk_file")
	end
end

---Returns available pkg by app_name or pkg_name
---@param app_or_pkg_name string
---@param refresh boolean?
---@return OpkgPkg?
function OpkgPkg.get_available_pkg(app_or_pkg_name, refresh)
	local pkg_text = o_utils.get_pkg_list_by_app_name(refresh)[app_or_pkg_name] or o_utils.get_pkg_list(refresh)[app_or_pkg_name]
	if pkg_text then
		return OpkgPkg(pkg_text)
	end
end

---Returns installed pkg by app_name or pkg_name
---@param app_or_pkg_name string
---@param refresh boolean?
---@return OpkgPkg?
function OpkgPkg.get_installed_pkg(app_or_pkg_name, refresh)
	local pkg = o_utils.get_installed_pkg_list_by_app_name(refresh)[app_or_pkg_name]
	if not pkg then
		pkg = o_utils.get_installed_pkg_info_text(app_or_pkg_name)
	end
	if not pkg then return nil end

	return OpkgPkg(pkg)
end

---Calculates package's and all of it's dependencies size in bytes
---@return integer size
function OpkgPkg:get_size_online()
	return o_utils.get_size_online(self.pkg_name)
end

---Returns option from package text (.control file format)
---@param opt string option name e.g. "Installed-Size"
---@return string? opt_value
function OpkgPkg:get(opt)
	if self._opt_cache[opt] then return self._opt_cache[opt] end
	local opt_value = o_utils.get_opt(self.pkg_text, opt)
	self._opt_cache[opt] = opt_value
	return opt_value
end

---Returns is pkg pending. Also sets self.pending = true/false
---@return boolean
function OpkgPkg:is_pending()
	for _, f in ipairs({o_utils.PKG_RESTORE_PATH, o_utils.FAILED_PKG_PATH}) do
		local ok, lines = pcall(io.lines, f)
		if ok then
			for line in lines do
				local p = o_utils._escape_magic(self.app_name)
				if line:match("^" .. p .. " ") or line:match("^" .. p .. "$") then
					self.type = PKG_TYPES.PENDING
					self.pending = true
					return true
				end
			end
		end
	end
	self.pending = false
	return false
end

function OpkgPkg:is_installed()
	if fs.access((o_utils.DEST_ROOT.."/usr/lib/opkg/info/%s.control") % self.pkg_name) or fs.access("/usr/lib/opkg/info/%s.control" % self.pkg_name) then
		self.type = PKG_TYPES.INSTALLED
		return true
	end
	return false
end

function OpkgPkg:_validate_pkg_remove()
	if not self:is_pending() and not self:is_installed() then
		return false, ERR_CODES.INVALID_PACKAGE
	end
	return true
end

function OpkgPkg:_remove_pkg_from_pkg_restore()
	o_utils._remove_pkg_from_pkg_restore(self.app_name)
end

---@return number? ret_code
---@return number? err_code
function OpkgPkg:_remove_package()
	local code, res = o_utils.opkg_call("remove", self.pkg_name, o_utils.OPKG_DATA, "--remove_conf", "--autoremove")

	for _, line in ipairs(res.errors or {}) do
		local err_code = tonumber(line:match("status%s+(%d+)%."))
		if err_code then
			return code, err_code
		end
	end
	return code
end

---@param err_code number?
function OpkgPkg:_validate_pkg_remove_depends(err_code)
	local depends = self:_pkg_whatdepends()
	if depends then
		return false, ERR_CODES.FAILED_PKG_DELETE_DEPENDS, depends
	elseif err_code == 255 then -- code returned by hs_theme.mk prerm script
		return false, ERR_CODES.HS_THEME_USED
	end
	return true
end

---Returns list of packages which depend on this package
---@return table?
function OpkgPkg:_pkg_whatdepends()
	local depends = {}
	if not o_utils._opkg_lock_check() then return nil end
	local code, res = o_utils.opkg_call("whatdepends", self.pkg_name, o_utils.OPKG_DATA)
	local pkg_dep_start_reached = false
	for _, line in ipairs(res.log) do
		if pkg_dep_start_reached then
			if line ~= "" then
				local depends_info = util.split(line, "%s+", nil, true)
				local length = #depends_info
				if depends_info[length] and depends_info[length] ~= self.pkg_name then
					return {}
				elseif depends_info[length] and depends_info[length] == self.pkg_name and depends_info[2] then
					local info_text = fs.readfile((o_utils.DEST_ROOT.."/usr/lib/opkg/info/%s.control") % depends_info[2]) or fs.readfile("/usr/lib/opkg/info/%s.control" % depends_info[2]) or ""
					local p = o_utils.get_opt(info_text, "AppName") or o_utils.get_opt(info_text, "Package")
					if p then
						table.insert(depends, p)
					end
				end
			end
		elseif line:find("What depends on root set", nil, true) then
			pkg_dep_start_reached = true
		end
	end
	return #depends > 0 and depends or nil
end

---@param msgs {code:OPKG_MSG_CODES, message:string}[]
function OpkgPkg:add_messages(msgs)
	self.messages = self.messages or {}
	util.append(self.messages, msgs)
end

---Adds error to the pkg and sets it's type as errored
---@param err {code:OPKG_ERR_CODES, error:string, source:string?, value:any}
function OpkgPkg:add_error(err)
	self.errors = self.errors or {}
	table.insert(self.errors, err)
	self.type = PKG_TYPES.ERRORED
end

---@return table?
function OpkgPkg:get_pkg_msgs()
	local msgs = {}
	if self:get("pkg_reboot") == "1" or self:get("pkg_reboot") == true then
		table.insert(msgs, { code = MSG_CODES.REBOOT_REQUIRED, message = MSG_STR.REBOOT_REQUIRED })
	end
	if self:get("pkg_network_restart") == "1" or self:get("pkg_network_restart") == true then
		table.insert(msgs, { code = MSG_CODES.NET_RESTART_REQUIRED, message = MSG_STR.NET_RESTART_REQUIRED })
	end
	return msgs[1] and msgs or nil
end

---Parses and return package from dir. Returns errors if failed
---@param pkg_dir string?
---@return OpkgPkg? pkg
---@return OPKG_ERR_CODES? err_code
function OpkgPkg.get_pkg_from_dir(pkg_dir)
	if not pkg_dir then return nil, ERR_CODES.INVALID_PACKAGE end
	local pkg_info_text = fs.readfile(pkg_dir .. "/main")

	if not pkg_info_text then return nil, ERR_CODES.MISSING_PKG_DATA end

	local pkg_name = o_utils.get_opt(pkg_info_text, "Package")
	if not pkg_name then return nil, ERR_CODES.INVALID_PACKAGE end

	local pkg = OpkgPkg(pkg_info_text, nil, pkg_name, pkg_dir)

	if not pkg:_check_package_arch_and_hw() then return nil, ERR_CODES.WRONG_ARCH end
	if not pkg:_check_package_fw() then return nil, ERR_CODES.WRONG_FW end
	if not pkg:_check_size_offline() then return nil, ERR_CODES.NO_SPACE end
	return pkg
end

function OpkgPkg:_validate_pkg_online_install_size_and_arch()
	if not self:_check_package_arch_and_hw() then
		return false, ERR_CODES.WRONG_ARCH
	end

	local pkg_size = self:get_size_online() / 1024
	local free_space = require("vuci.util_tlt").check_reserved_space(pkg_size, o_utils.DEST_ROOT .. "/")
	if not free_space then return false, ERR_CODES.NO_SPACE end
	return true
end

function OpkgPkg:_validate_pkg_online_install()
	if self:is_installed() then
		return false, ERR_CODES.ALREADY_INSTALLED
	end
	return self:_validate_pkg_online_install_size_and_arch()
end

function OpkgPkg:_validate_pkg_upgrade()
	if not next(o_utils.get_pkg_list()) then return false, ERR_CODES.NO_CONNECTION end

	if not o_utils.opkg_server_reachable() then return false, ERR_CODES.NO_CONNECTION end

	local installed_pkg = OpkgPkg.get_installed_pkg(self.app_name)
	if not installed_pkg then return false, ERR_CODES.INVALID_PACKAGE end

	local new_package_v = self:get("Version")
	if not new_package_v then return false, ERR_CODES.PKG_UPGRADE_FAILED end

	local pkg_is_newer = installed_pkg:version_lesser_than(self)
	if not pkg_is_newer then
		return false, ERR_CODES.LOWER_VERSION
	end
	return true
end

function OpkgPkg:_install_package_online()
	if not o_utils._opkg_lock_check() then return false, ERR_CODES.OPKG_BUSY end

	fs.mkdir(o_utils.PKG_CUSTOM_FOLDER_PATH)
	local code = o_utils.opkg_call("install", self.pkg_name, o_utils.OPKG_DATA, "--tmp-dir", o_utils.PKG_CUSTOM_FOLDER_PATH)

	if code ~= 0 then
		fs.rmdir(o_utils.PKG_CUSTOM_FOLDER_PATH)
		return false, ERR_CODES.INSTALL_FAIL
	end
	return true
end

function OpkgPkg:_install_packages_offline()
	local new_package_v = self:get("Version")
	if not new_package_v then return false, ERR_CODES.INVALID_PACKAGE end

	if not self.ipk_file then
		util.perror("Package '%s' is missing ipk_file" % self.pkg_name)
		return false, ERR_CODES.INVALID_PACKAGE
	end

	local old_pkg = OpkgPkg.get_installed_pkg(self.app_name)

	if old_pkg and not old_pkg:version_lesser_than(self) then
		util.log_warn("Package '%s' with higher version '%s' already installed" % {self.pkg_name, old_pkg:get("Version")})
		return false, ERR_CODES.LOWER_VERSION
	end

	if not o_utils._opkg_lock_check() then return false, ERR_CODES.OPKG_BUSY end

	-- feeds need to be cleaned before install to avoid conflicting pkgs
	o_utils.clean_feeds()

	local code = o_utils._install_packages(self.pkg_name, self.ipk_file, self.pkg_dir, self.ipk_deps)
	if code ~= 0 then
		return false, ERR_CODES.INSTALL_FAIL
	end
	return true
end

---Returns true if package's "Firmware" key matches device's firmware version
---@return boolean
function OpkgPkg:_check_package_fw()
	local package_fw = self:get("Firmware") or ""
	local device_fw = util.trim(fs.readfile("/etc/version")) or ""
	package_fw = package_fw:match("_([^_]+)$")
	device_fw = device_fw:match("_([^_]+)$")

	if not package_fw or not device_fw then
		util.perror("Missing firmware version in package or device")
		return false
	end

	local ok = package_fw == device_fw
	if not ok then
		util.perror("Different firmware versions: '%s' != '%s'" % {device_fw, package_fw})
	end
	return ok
end

---Returns true if package's "Router" key matches device's name (e.g. RUTX, RUTX11) and HWInfo key matches device's hardware features
---@return boolean
function OpkgPkg:_check_package_arch_and_hw()
	local ok, hw_arch = o_utils.check_package_arch(self:get("Architecture"), self:get("Router"))
	if not ok then
		util.perror("Different architectures: [%s]" % {util.serialize_data(hw_arch)})
		return false
	end

	local hw_info_string = self:get("HWInfo")
	ok = o_utils.check_pkg_hw_info(hw_info_string)
	if not ok then
		util.perror("HWInfo condition not met: %s" % hw_info_string)
		return false
	end

	return true
end

---Calculates uploaded package installed size. Returns true if package will fit, false otherwise
---@return boolean
function OpkgPkg:_check_size_offline()
	local sum = 0
	fs.mkdir(self.pkg_dir .. "/control_dir")
	for pkg_file_name in fs.dir(self.pkg_dir) do
		local pkg_info_text = o_utils._get_info(self.pkg_dir, pkg_file_name)
		if pkg_info_text then
			local pkg = OpkgPkg(pkg_info_text)
			if not pkg:is_installed() then
				local installed_size = pkg:get("Installed-Size") or 0
				sum = sum + installed_size
			end
		end
	end

	sum = sum / 1024
	local free_space, space = require("vuci.util_tlt").check_reserved_space(sum, o_utils.DEST_ROOT .. "/")
	if not free_space then
		util.perror("Not enough space to install package, package size: %s, free device space: %s" % {sum, space})
	end
	return free_space
end

---Returns this_package_version < other_pkg_version
---@param other_pkg OpkgPkg
---@return boolean
function OpkgPkg:version_lesser_than(other_pkg)
	local self_v = self:get("Version")
	if not self_v then return true end

	local other_v = other_pkg:get("Version")
	assert(other_v)

	return o_utils._compare_versions(other_v, self_v)
end

return OpkgPkg
