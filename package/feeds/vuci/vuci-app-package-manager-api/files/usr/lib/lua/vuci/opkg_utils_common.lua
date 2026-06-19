local util = require "vuci.util"
local board = require("vuci.board")
local nixio = require "nixio"
local json = require "luci.jsonc"
local fs = require "nixio.fs"
fs.mkdir("/tmp/pkgman")

---@class pkg_info pkg keys converted to API friendly names (snake_case)
---@field description string
---@field package string
---@field app_name string
---@field depends string
---@field size string
---@field sha256 string
---@field installed_size string
---@field version string
---@field hw_info string
---@field router string
---@field tlt_name string
---@field firmware string
---@field license string
---@field url string?
---@field installed_version string
---@field hidden boolean
---@field network_restart boolean
---@field reboot boolean
---@field type OPKG_PKG_TYPES
---@field upgrade boolean
---@field ipk_deps string
---@field ipk_file string

---@class pkg_keys pkg keys returned from ubus call opkg feeds_info
---@field Description string
---@field Package string
---@field AppName string
---@field Depends string[]
---@field Size number
---@field SHA256sum string
---@field Installed-Size number
---@field Version string
---@field Router string
---@field HWInfo string
---@field tlt_name string
---@field Firmware string
---@field License string
---@field installedVersion string
---@field Hidden string
---@field pkg_network_restart string
---@field pkg_reboot string
---@field ipk_deps string
---@field ipk_file string

---@enum OPKG_ERR_CODES
local ERR_CODES = {
	NO_ERROR = 0,
	INVALID_PACKAGE = 1,
	LOWER_VERSION = 2,
	WRONG_ARCH = 3,
	WRONG_FW = 4,
	NO_SPACE = 5,
	INSTALL_FAIL = 6,
	OPKG_BUSY = 7,
	MISSING_PKG_DATA = 8,
	NO_CONNECTION = 9,
	PKG_UPGRADE_FAILED = 12,
	FAILED_PKG_DELETE_DEPENDS = 13,
	HS_THEME_USED = 14,
	FAILED_PKG_DELETE = 15,
	ALREADY_INSTALLED = 17,
	UPGRADE_NOT_AVAILABLE = 18,
	UNEXPECTED_ERROR = 19,
}
local ERR_STR = {
	NO_ERROR = "No error",
	INVALID_PACKAGE = "Invalid package.",
	LOWER_VERSION = "Package is already installed with same or newer version.",
	WRONG_ARCH = "Not compatible with Device.",
	WRONG_FW = "Not compatible with Firmware.",
	NO_SPACE = "Not enough space to install package.",
	INSTALL_FAIL = "Package installation failed.",
	OPKG_BUSY = "Package service is busy, try again later.",
	MISSING_PKG_DATA = "Missing uploaded package data.",
	NO_CONNECTION = "No connection to the package server.",
	PKG_UPGRADE_FAILED = "Package upgrade failed.",
	FAILED_PKG_DELETE_DEPENDS = "Failed to delete package, because this package is dependent on other packages.",
	HS_THEME_USED = "Theme is being used in landing page as current theme and cannot be removed.",
	FAILED_PKG_DELETE = "Failed to delete the package.",
	ALREADY_INSTALLED = "Package already installed.",
	UPGRADE_NOT_AVAILABLE = "This package update is not available.",
	UNEXPECTED_ERROR = "Unexpected error.",
}
---@enum OPKG_MSG_CODES
local MSG_CODES = {
	REBOOT_REQUIRED = 10,
	NET_RESTART_REQUIRED = 11,
}
local MSG_STR = {
	REBOOT_REQUIRED = "For service to function correctly it is required to reboot device.",
	NET_RESTART_REQUIRED = "For service to function correctly it is required to restart network.",
}

---@enum OPKG_PKG_TYPES
local PKG_TYPES = {
	UNKNOWN = 0,
	PENDING = 1,
	AVAILABLE = 2,
	INSTALLED = 3,
	PENDING_ERRORED = 4,
	INSTALLING = 5,
	UPDATING = 6,
	REMOVING = 7,
	ERRORED = 8,
	REMOVED = 9, -- used in package_event, when package is removed and is not available in pkg list
}

---@enum OPKG_MULTI_ACTIONS
local MULTI_ACTIONS = {
	INSTALL = 1,
	REMOVE = 2,
	UPGRADE = 3
}
local ACTION_TO_PKG_TYPE = {
	[MULTI_ACTIONS.INSTALL] = PKG_TYPES.INSTALLING,
	[MULTI_ACTIONS.REMOVE] = PKG_TYPES.REMOVING,
	[MULTI_ACTIONS.UPGRADE] = PKG_TYPES.UPDATING,
}

local PKG_QUEUE_FILE = "/tmp/pkgman/package_queue"
local PKG_TAR_PATH = "/tmp/package.tar.gz"
local PKG_CUSTOM_FOLDER_PATH = "/tmp/run/opkg/custom_package"
local PKG_CACHE_FILE = "/tmp/pkgman/packages_cache.json"
local PKG_RESTORE_PATH = "/etc/package_restore.txt"
local FAILED_PKG_PATH = "/etc/package_restore/failed_packages"
local PKG_MULTI_LOCK_PATH = "/var/lock/pkg_man_multi.lock"
local PKG_OPKG_LOCK_PATH = "/var/lock/pkg_man_opkg.lock"
local OPKG_TLT_URL = "opkg.teltonika-networks.com"
local OPKG_CONF_FILE = "/etc/opkg.conf"
local TLT_PACKAGES_NAME = "tlt_packages"
local TLT_PACKAGES_FILE_PATH = "/var/opkg-lists/" .. TLT_PACKAGES_NAME
local DEST_ROOT = (fs.readfile(OPKG_CONF_FILE):match("dest%s+root%s+(%S+)") or ""):gsub("/$", "") -- remove trailing slash

local o_utils = {
	ERR_CODES = ERR_CODES,
	ERR_STR = ERR_STR,
	MSG_CODES = MSG_CODES,
	MSG_STR = MSG_STR,
	PKG_TYPES = PKG_TYPES,
	_pkg_list_text = nil,
	_pkg_list = nil,
	PKG_QUEUE_FILE = PKG_QUEUE_FILE,
	PKG_TAR_PATH = PKG_TAR_PATH,
	PKG_CUSTOM_FOLDER_PATH = PKG_CUSTOM_FOLDER_PATH,
	PKG_CACHE_FILE = PKG_CACHE_FILE,
	PKG_RESTORE_PATH = PKG_RESTORE_PATH,
	FAILED_PKG_PATH = FAILED_PKG_PATH,
	PKG_MULTI_LOCK_PATH = PKG_MULTI_LOCK_PATH,
	OPKG_TLT_URL = OPKG_TLT_URL,
	MULTI_ACTIONS = MULTI_ACTIONS,
	ACTION_TO_PKG_TYPE = ACTION_TO_PKG_TYPE,
	DEST_ROOT = DEST_ROOT,
}

---@param tbl table
---@param val any
---@return string?
local function find_key(tbl, val)
	for key, value in pairs(tbl) do
		if value == val then return key end
	end
end

---@param code OPKG_PKG_TYPES
---@return string?
function o_utils.pkg_type_str(code)
	return find_key(PKG_TYPES, code)
end

---@param err_code OPKG_ERR_CODES
---@return string
function o_utils.err_str(err_code)
	return ERR_STR[find_key(ERR_CODES, err_code)]
end

---Escapes special symbols for matching
---@param pattern string
---@return string
function o_utils._escape_magic(pattern)
	return (pattern:gsub("%W", "%%%1"))
end

---Returns available package list (keys are package pkg_name, values are tables with pkg info keys = values)
---@param refresh boolean? if true, pkg list is refreshed, otherwise cache is used
---@return { [string]: pkg_keys }
function o_utils.get_pkg_list(refresh)
	local code, data
	if not refresh and o_utils._pkg_list and next(o_utils._pkg_list) then
		return o_utils._pkg_list
	end
	code, data = o_utils.opkg_call("list_feeds", nil, o_utils.OPKG_DATA)
	o_utils._pkg_list = data.packages or {}


	return o_utils._pkg_list
end

---Returns available package list (keys are package app_name, values are pkg text formatted as .control file)
---@param refresh boolean? if true, pkg list is refreshed, otherwise cache is used
---@return { [string]: pkg_keys }
function o_utils.get_pkg_list_by_app_name(refresh)
	local pkg_list = o_utils.get_pkg_list(refresh)

	local pkg_list_by_app_names = {}
	for pkg_name, pkg_text in pairs(pkg_list) do
		local app_name = o_utils.get_opt(pkg_text, "AppName")
		if app_name then
			pkg_list_by_app_names[app_name] = pkg_text
		end
	end
	return pkg_list_by_app_names
end

---Returns option from package text (.control file format)
---@param pkg_info_text string|pkg_keys package text (.control file format or table with pkg info values)
---@param opt string option name e.g. "Installed-Size"
---@return string? opt_value
function o_utils.get_opt(pkg_info_text, opt)
	if type(pkg_info_text) == "table" then
		return pkg_info_text[opt]
	end
	if opt == "Description" then -- Description is last and can span multiple lines
		local v = pkg_info_text:match(o_utils._escape_magic(opt) .. ": ?(.*)")
		return v and util.trim(v) or nil
	end
	return pkg_info_text:match(o_utils._escape_magic(opt) .. ": ?(.-)\r?\n")
end

--- perform lock operation on a file and returns it for reading/writing
---@param lock_type "lock"|"tlock"|"ulock"|"test" lock operation, "lock" is blocking, "tlock" ir non blocking, "ulock" unlocks, "test" only tests
---@return boolean success true if file locked/unlocked successfully
---@return table fd nixio file descriptor
function o_utils._lock(file_path, lock_type)
	local f = nixio.open(file_path, nixio.open_flags("rdwr", "creat"))
	fs.chmod(file_path, "rw-rw-r--")
	if not f then error("lock file open error: " .. file_path) end
	local ok, errno, errmsg = f:lock(lock_type)
	return ok, f
end

---Locks pkg service file. Used to prevent multiple API instances running of pkg actions (install/remove/update).
---File needs to be unlocked and closed after using it - fd:lock("ulock") ; fd:close().
---Lock is released automatically when process ends.
---@param blocking boolean? default = true, if false lock is not blocking
---@return boolean success true if file locked successfully. false if file already locked
---@return table fd lock file descriptor. **Warning:** You have to keep a reference to this file, otherwise it gets gc'd by nixio and unlocked when it goes out of scope
---@nodiscard
function o_utils.acquire_lock(blocking)
	if blocking == nil then blocking = true end
	return o_utils._lock(PKG_MULTI_LOCK_PATH, blocking and "lock" or "tlock")
end

---Tests pkg service file lock.
---@return boolean locked true if file is unlocked
---@return table fd
function o_utils.test_lock()
	return o_utils._lock(PKG_MULTI_LOCK_PATH, "test")
end

function o_utils.opkg_call(cmd, packages, ...)
	local ok, fd
	if cmd ~= "list_feeds" then -- list_feeds does not need locking
		ok, fd = o_utils._lock(PKG_OPKG_LOCK_PATH, "lock")
		assert(ok, "lock error")
	else
		nixio.setenv("OPKG_NO_LOCK", "1") -- used by /bin/opkg
	end
	local output = {}

	local args = {"-j"}
	util.append(args, ...)
	util.append(args, cmd)
	util.append(args, packages)
	local res = util.file_exec("/bin/opkg", args)
	if cmd ~= "list_feeds" then
		fd:lock("ulock")
		fd:close()
	else
		nixio.setenv("OPKG_NO_LOCK") -- unset env variable
	end

	if res.stdout then
		output = json.parse(res.stdout)
	end

	-- log potential opkg errors for easier debugging
	local log_str = (output and output.log) and table.concat(output.log, "\n") or ""
	if log_str ~= "" then util.perror(log_str) end
	log_str = (output and output.errors) and table.concat(output.errors, "\n") or ""
	if log_str ~= "" then util.perror(log_str) end
	log_str = res.stderr or ""
	if log_str ~= "" then util.perror(log_str) end

	return res.code, output
end

function o_utils._remove_pkg_from_pkg_restore(app_name)
	for _, f in ipairs({o_utils.PKG_RESTORE_PATH, o_utils.FAILED_PKG_PATH}) do
		local ok, lines = pcall(io.lines, f)
		if ok then
			local new_file = {}
			for line in lines do
				local p = o_utils._escape_magic(app_name)
				if not (line:match("^" .. p .. " ") or line:match("^" .. p .. "$")) then
					table.insert(new_file, line)
				end
			end
			fs.writefile(f, table.concat(new_file, "\n"))
		end
	end
end

---@param enable ""|"0"|"1"
function o_utils._set_language(enable)
	local uci = require("vuci.uci").cursor()
	uci:set("vuci", "main", "set_main_language", enable)
	uci:commit("vuci")
end

---@param list_file string
---@return string?
function o_utils.get_pkg_url(list_file)
	local menu_file_path = (fs.readfile(list_file) or ""):match(o_utils.DEST_ROOT.."/usr/share/vuci/menu%.d/.-%.json") or ""
	local menu_json = json.parse((fs.readfile(menu_file_path) or "{}")) or {}
	local fallback_url
	for url, menu_entry in pairs(menu_json) do
		if menu_entry.main_page then  -- use url from entry which has main_page=true
			return "/" .. url
		elseif menu_entry.view then -- fallback to random entry which has .view key
			fallback_url = "/" .. url
		end
	end
	return fallback_url
end

---Called after pkg action (install/remove/upgrade)
---@param pkg_info table?
function o_utils._trigger_pkg_event(pkg_info)
	local st = require "vuci.status"

	-- event server ubus does not support floating point numbers, need to convert to strings
	local mem = st.memory_usage()
	for key, value in pairs(mem) do
		if type(value) == "number" then
			mem[key] = tostring(value)
		end
	end

	if pkg_info then
		if pkg_info.type == PKG_TYPES.INSTALLED then
			pkg_info.url = o_utils.get_pkg_url(o_utils.DEST_ROOT.."/usr/lib/opkg/info/%s.list" % pkg_info.pkg_name)
		end
		local pkg_action
		local skipped
		for _, line in ipairs(util.split(fs.readfile(PKG_QUEUE_FILE) or "")) do
			local action, package = line:match("(%d)%s+(%S+)")
			if package == pkg_info.package then
				-- skip first found action because it is the one currently being executed
				if not skipped then
					skipped = true
				else
					pkg_action = action
					break
				end
			end
		end
		if pkg_action then
			pkg_info.type = ACTION_TO_PKG_TYPE[pkg_action]
		end
		pkg_info.app_name = nil
		pkg_info.pkg_name = nil
	end

	-- using /tmp/vuci/package_event causes race conditions and some events are not sent
	local ubus = require("ubus")
	local con = ubus.connect()
	con:send("vuci.notify", {
		event = "package_event",
		data = pkg_info and { package = pkg_info, memory = mem } or ""
	})
	con:close()
end

function o_utils._restart_services()
    -- Intentionally left empty for future callback use
end

function o_utils._trigger_backup()
	local system_ubus = util.ubus("system") or {}
	if system_ubus["backup"] then
		util.fork_ubus("system", "backup", { env = { "CONF_BACKUP_PKG_APPLY=1" } })
	else
		-- TODO: remove when root is removed from TSWOS
		local util_tlt = require("vuci.util_tlt")
		util_tlt.fork_exec("/sbin/backup pkg_install")
	end
end

---Cleans package list fetched from the server
function o_utils.clean_feeds(...)
	local ok, fd = o_utils._lock(PKG_OPKG_LOCK_PATH, "lock")
	assert(ok, "lock error")
	o_utils.opkg_call("cleanup_feeds", nil, o_utils.OPKG_DATA, ...)
	fs.remove(PKG_CACHE_FILE)
	fd:lock("ulock")
	fd:close()
end

function o_utils.opkg_server_reachable()
	local tlt_feeds = fs.readfile("/etc/opkg/teltonikafeeds.conf")
	local server_address = tlt_feeds and util.trim(util.split(tlt_feeds, "%s+", nil, true)[3]) or OPKG_TLT_URL
	return (util.file_exec("/usr/bin/curl", {server_address, "-m", "10"}) or {}).code == 0
end


---Checks if there is package list already fetched from server, if it is not - fetches package list from server
function o_utils.fetch_pkg_list(force_refresh)
	if not force_refresh and fs.access(TLT_PACKAGES_FILE_PATH) then return end

	local code
	if o_utils.opkg_server_reachable() then
		o_utils.clean_feeds()
		code = o_utils.opkg_call("update", nil, OPKG_DATA)
	end
	if code ~= 0 then
		o_utils.clean_feeds()
	end
end

local function rmdir(path)
	util.file_exec("/bin/rm", {"-rf", path})
end


---Waits for opkg lock and deletes temporary package files
---@param blocking boolean? if false, function returns false immediately if opkg is busy
---@param timeout integer? max time to wait in seconds, default = 9 minutes
---@return boolean success true if lock acquired and files deleted
function o_utils.delete_custom_pkg_files(blocking, timeout)
	-- need to wait for lock because pkg install can be running and it's files would be removed
	if o_utils._opkg_lock_check(blocking, timeout) then
		rmdir(PKG_TAR_PATH)
		rmdir(PKG_CUSTOM_FOLDER_PATH)
		return true
	end
	return false
end

function o_utils.pkg_pending(app_name)
	for _, f in ipairs({PKG_RESTORE_PATH, FAILED_PKG_PATH}) do
		local ok, lines = pcall(io.lines, f)
		if ok then
			for line in lines do
				local p = o_utils._escape_magic(app_name)
				if line:match("^" .. p .. " ") or line:match("^" .. p .. "$") then
					return true
				end
			end
		end
	end
	return false
end

---@param pkg_name string
---@return boolean
function o_utils.pkg_installed(pkg_name)
	return fs.access("/usr/lib/opkg/info/%s.control" % pkg_name) or fs.access((o_utils.DEST_ROOT.."/usr/lib/opkg/info/%s.control") % pkg_name)
end

---@param pkg_name string
---@return string?
function o_utils.get_installed_pkg_info_text(pkg_name)
	local pkg_text = fs.readfile("/usr/lib/opkg/info/%s.control" % pkg_name) or fs.readfile((o_utils.DEST_ROOT.."/usr/lib/opkg/info/%s.control") % pkg_name)
	if not (pkg_text or ""):find("\ntlt_name: ", nil, true) then return nil end
	return pkg_text
end

---@param refresh boolean?
---@return {[string]:string}
function o_utils.get_installed_pkg_list_by_app_name(refresh)
	if refresh then o_utils._installed_pkg_info_text_list = nil end
	if o_utils._installed_pkg_info_text_list then return o_utils._installed_pkg_info_text_list end

	local pac = require("vuci.package_checker")
	o_utils._installed_pkg_info_text_list = {}
	for _, value in ipairs(pac.list_control_files_ext(o_utils.DEST_ROOT .. "/usr/lib/opkg/info/")) do
		local pkg_text = fs.readfile(value) or "" -- info can be nil if pkg is being removed
		if pkg_text:find("\ntlt_name: ", nil, true) then
			local app_name = o_utils.get_opt(pkg_text, "AppName")
			if app_name then
				o_utils._installed_pkg_info_text_list[app_name] = pkg_text
			end
		end
	end

	return o_utils._installed_pkg_info_text_list
end

---Waits 9 minutes for opkg process to finish
---@param blocking boolean? if false, function returns false immediately if opkg is busy
---@param timeout integer? max time to wait in seconds, default = 9 minutes
---@return boolean finished true if process finished, false if waiting timed out
function o_utils._opkg_lock_check(blocking, timeout)
	blocking = blocking == nil and true or blocking
	local delay = 1
	timeout = timeout or 60 * 9
	local max_retries = timeout / delay
	local retries = 0

	while fs.access("/var/lock/opkg.lock") and os.execute("pgrep opkg &> /dev/null") == 0 do
		-- Timeout after 9 minutes
		if not blocking or retries >= max_retries then return false end
		retries = retries + 1
		nixio.nanosleep(delay)
	end
	return true
end

---Calculates package's and all of it's dependencies size in bytes
---@param pkg_name string
---@return integer size
function o_utils.get_size_online(pkg_name)
	local all_pkgs = o_utils.get_pkg_list()
	local pkg_info_text = all_pkgs[pkg_name]


	-- find all depending pkgs recursively
	local depend_pkgs = {}
	local function get_depends(pkg)
		local pkg_info_text = all_pkgs[pkg]
		if not pkg_info_text then return end
		local pkg_depends = o_utils.get_opt(pkg_info_text, "Depends")
		if not pkg_depends then return end

		for _, d in ipairs(pkg_depends) do
			d = util.trim(d)
			depend_pkgs[d] = true
			get_depends(d)
		end
	end
	get_depends(pkg_name)

	-- calculate all depending pkgs size
	local total_size = 0
	for dep_pkg_name in pairs(depend_pkgs) do
		if not o_utils.pkg_installed(dep_pkg_name) and all_pkgs[dep_pkg_name] then
			local size = tonumber(o_utils.get_opt(all_pkgs[dep_pkg_name], "Installed-Size"))
			total_size = total_size + (size or 0)
		end
	end

	total_size = total_size + (tonumber(o_utils.get_opt(pkg_info_text or "", "Installed-Size")) or 0)
	return total_size
end

function o_utils._version_split(str)
	local t = {}
	for s in string.gmatch(str, "([^.-]+)") do
		table.insert(t, s)
	end
	return t
end

--FIXME: use opkg compare-versions <v1> <op> <v2>
---Returns v1 > v2
---@param version1 string
---@param version2 string
---@return boolean
function o_utils._compare_versions(version1, version2)
	local v1 = o_utils._version_split(version1)
	local v2 = o_utils._version_split(version2)
	local minlength = #v1
	if #v2 < #v1 then minlength = #v2 end
	-- checks version number parts
	for i = 1, minlength, 1 do
		if v1[i] > v2[i] then return true
		elseif v1[i] < v2[i] then return false end
	end
	-- if server version is longer but previous checks passed that means the version is bigger
	--  1.0.0.1 > 1.0.0
	if #v1 > #v2 then return true end
	return false
end


local _board
---Returns true if package's HWInfo key matches device's hardware features
---@param hw_info_string string? / means OR, space means AND, e.g. "usb/rs232 mobile ehternet" means "(usb or rs232) and mobile and ethernet"
---@return boolean
function o_utils.check_pkg_hw_info(hw_info_string)
	if hw_info_string then
		_board = _board or board:get_all()
		local condition_results = {}
		local parts = util.split(util.trim(hw_info_string), "%s+", nil, true)
		for i, hw_info in ipairs(parts) do
			condition_results[i] = false
			local hw_splitted = util.split(hw_info, "/")
			for _, hw in ipairs(hw_splitted) do
				if _board.hwinfo[hw] then
					condition_results[i] = true
					break
				end
			end
		end

		for _, cond in ipairs(condition_results) do
			if not cond then
				return false
			end
		end
	end

	return true
end

return o_utils
