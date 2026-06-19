local FunctionService = require("api/FunctionService")
local board = require("vuci.board")
local fs = require("nixio.fs")
local util = require("vuci.util")
local opkg = require("vuci.opkg")
local opkg_multi = require("vuci.opkg_multi")
local pac = require("vuci.package_checker")
local json = require "luci.jsonc"

local PKG_TAR_PATH = opkg.PKG_TAR_PATH
local PKG_CUSTOM_FOLDER_PATH = opkg.PKG_CUSTOM_FOLDER_PATH
local PKG_CACHE_FILE = opkg.PKG_CACHE_FILE
local PKG_RESTORE_PATH = opkg.PKG_RESTORE_PATH
local FAILED_PKG_PATH = opkg.FAILED_PKG_PATH

local PackageManager = FunctionService:new()
PackageManager.disable_upload_service_group_check = true

--- Used to rename package keys for API
local PKG_KEY_MAP = {
	Description = "description",
	Package = "package",
	AppName = "app_name",
	Depends = "depends",
	Size = "size",
	SHA256sum = "sha256",
	["Installed-Size"] = "installed_size",
	Version = "version",
	Router = "router",
	Architecture = "architecture",
	HWInfo = "hw_info",
	tlt_name = "tlt_name",
	Firmware = "firmware",
	License = "license",
	installedVersion = "installed_version",
	Hidden = "hidden",
	pkg_network_restart = "network_restart",
	pkg_reboot = "reboot",
	ipk_deps = "ipk_deps",
	ipk_file = "ipk_file",
}

local PKG_TYPES = opkg.PKG_TYPES

local function check_arch_and_hw(package)
	local ok = opkg.check_package_arch(package.architecture, package.router)

	if not ok then return false end
	ok = opkg.check_pkg_hw_info(package.hw_info)
	if not ok then return false end
	return true
end

local function get_pending_packages()
	local pkg_list
	local packages = {}

	pkg_list = fs.readfile(PKG_RESTORE_PATH) or ""
	for pkg_name, tlt_name in pkg_list:gmatch("([%w%.%-%+_]+) %- *(.-)\n") do
		if not tlt_name:find("^%s*%-*%s*$") then
			packages[pkg_name] = { package = pkg_name, tlt_name = tlt_name, type = PKG_TYPES.PENDING } -- In queue to download
		end
	end

	pkg_list = fs.readfile(FAILED_PKG_PATH) or ""
	for pkg_name, tlt_name in pkg_list:gmatch("([%w%.%-%+_]+) %- *(.-)\n") do
		if not tlt_name:find("^%s*%-*%s*$") then
			packages[pkg_name] = { package = pkg_name, tlt_name = tlt_name, type = PKG_TYPES.PENDING_ERRORED } -- Installation failed
		end
	end

	return packages
end

local function image_checksum(image)
	return (util.exec("md5sum %q" % image):match("^([^%s]+)"))
end

local function image_sha256_checksum(image)
	return (util.exec("sha256sum %q" % image):match("^([^%s]+)"))
end

local function rmdir(path)
	util.file_exec("/bin/rm", {"-rf", path})
end

---Parses ubus opkg feeds_info output, filters and converts keys
---@param pkgs { [string]: pkg_keys } ubus opkg feeds_info output
---@return { [string]: pkg_info }
local function parse_opkg_call(pkgs)
	---@type { [string]: pkg_info }
	local packages = {}
	for pkg_name, pkg in pairs(pkgs) do
		packages[pkg_name] = {}
		packages[pkg_name].package = pkg_name
		for key, value in pairs(pkg) do
			if key and value and PKG_KEY_MAP[key] then
				packages[pkg_name][PKG_KEY_MAP[key]] = value
			end
		end
	end
	return packages
end

---Parses .control file
---@param text string .control file text
---@return pkg_info
local function parse_pkg_info(text)
	local pkg = {}
	for s in text:gmatch("[^\r\n]+") do
		local key, value = s:match("([^:]+): ?(.*)")
		if key and value and not PKG_KEY_MAP[key] then
			-- Ignore unnecessary option and do not brake description
		elseif key and value and PKG_KEY_MAP[key] then
			if util.contains({"hidden", "network_restart", "reboot"}, PKG_KEY_MAP[key]) then
				pkg[PKG_KEY_MAP[key]] = value == "1" and true or nil
			else
				pkg[PKG_KEY_MAP[key]] = value
			end
		else -- adds remaining lines of description
			pkg["description"] = pkg["description"] .. s
		end
	end
	return pkg
end

---Extracts the uploaded package and returns info about it. Returns nil if failed
---@return pkg_info?
local function extract_package()
	rmdir(PKG_CUSTOM_FOLDER_PATH)
	fs.mkdir(PKG_CUSTOM_FOLDER_PATH)
	util.file_exec("/bin/tar", {"-xzC"..PKG_CUSTOM_FOLDER_PATH, "-f", PKG_TAR_PATH})
	fs.remove(PKG_TAR_PATH)
	local _, matches = fs.glob(PKG_CUSTOM_FOLDER_PATH.."/*.ipk")
	if matches == 0 then
		util.perror("No .ipk files found in the uploaded package")
		rmdir(PKG_CUSTOM_FOLDER_PATH)
		return
	end

	local main = fs.readfile(PKG_CUSTOM_FOLDER_PATH.."/main")
	local pkg = main and parse_pkg_info(main) or {}

	if not pkg.package or not pkg.version or not pkg.router or not pkg.ipk_file then
		rmdir(PKG_CUSTOM_FOLDER_PATH)
		util.perror("Missing required package fields in control file")
		return
	end

	local main_pkg_fileglob = PKG_CUSTOM_FOLDER_PATH .. "/" .. pkg.package .. "_" .. pkg.version .. "*.ipk"
	local _, main_matches = fs.glob(main_pkg_fileglob)

	if main_matches ~= 1 then
		rmdir(PKG_CUSTOM_FOLDER_PATH)
		util.perror("Main package file not found or multiple matches for pattern: " .. main_pkg_fileglob)
		return
	end

	return pkg
end

local _pkg_info
---Returns available filtered (by router name and by hidden flag) packages. Uses cache if present
---@return { [string]: pkg_info }
local function get_available_pkgs()
	if _pkg_info then return _pkg_info end
	_pkg_info = json.parse(fs.readfile(PKG_CACHE_FILE) or "")
	if _pkg_info and next(_pkg_info) then return _pkg_info end

	local packages = parse_opkg_call(opkg.get_pkg_list())
	local filtered_pkgs = {}
	for pkg_name, pkg in pairs(packages) do
		if not pkg.hidden and pkg.tlt_name and check_arch_and_hw(pkg) then
			filtered_pkgs[pkg_name] = pkg
			filtered_pkgs[pkg_name].type = PKG_TYPES.AVAILABLE
		end
	end
	_pkg_info = filtered_pkgs
	fs.writefile(PKG_CACHE_FILE, json.stringify(_pkg_info))
	fs.chmod(PKG_CACHE_FILE, "rw-rw-r--")
	return _pkg_info
end

---Parses .control file and adds additional info
---@param control_file_text string
---@return pkg_info
local function parse_pkg_info_full(control_file_text)
	local all_available = get_available_pkgs()
	local pkginfo = parse_pkg_info(control_file_text)
	pkginfo.type = PKG_TYPES.INSTALLED
	pkginfo.installed_version = pkginfo.version
	pkginfo.version = nil

	if all_available[pkginfo.package] and opkg.check_pkg_version(pkginfo.installed_version, all_available[pkginfo.package].version) then
		pkginfo.upgrade = true
	end

	pkginfo.url = opkg.get_pkg_url(opkg.DEST_ROOT.."/usr/lib/opkg/info/%s.list" % pkginfo.package)
	return pkginfo
end

local function get_installed_packages()
	local installed_pkgs = {}
	for _, value in ipairs(pac.list_control_files_ext(opkg.DEST_ROOT .. "/usr/lib/opkg/info/")) do
		local info = fs.readfile(value) or "" -- info can be nil if pkg is being removed
		if info:find("\ntlt_name: ", nil, true) then
			local pkginfo = parse_pkg_info_full(info)
			installed_pkgs[pkginfo.package] = pkginfo
		end
	end
	return installed_pkgs
end

local function get_all_packages()
	local all_pkgs = get_available_pkgs()
	local pending_packages = get_pending_packages()
	local installed_packages = get_installed_packages()
	for _, p in pairs(pending_packages) do
		local found
		for pkg_name, pkg in pairs(all_pkgs) do
			if pkg.app_name == p.package then
				pkg.type = p.type
				found = true
				break
			end
		end
		if not found then
			all_pkgs[p.package] = all_pkgs[p.package] or p
			all_pkgs[p.package].type = p.type
		end
	end
	for key, p in pairs(installed_packages) do
		all_pkgs[key] = all_pkgs[key] or p
		all_pkgs[key].type = p.type
		all_pkgs[key].installed_version = p.installed_version
		all_pkgs[key].installed_size = p.installed_size
		all_pkgs[key].upgrade = p.upgrade
		all_pkgs[key].url = p.url
	end
	return all_pkgs
end

local function _fix_keys(pkg, pkg_name)
	pkg.package = pkg.app_name or pkg_name
	pkg.type_str = opkg.pkg_type_str(pkg.type)

	pkg.app_name = nil
	pkg.architecture = nil
	pkg.architecture = nil
	pkg.section = nil
	pkg.firmware = nil
	pkg.ipk_deps = nil
	pkg.ipk_file = nil
	pkg.hw_info = nil
	pkg.hidden = nil

	pkg.size = pkg.size and tostring(pkg.size) or nil
	pkg.installed_size = pkg.installed_size and tostring(pkg.installed_size) or nil
	pkg.depends = type(pkg.depends) == "table" and table.concat(pkg.depends, ", ") or pkg.depends

	return pkg
end

local function convert_to_array(object)
	local array = {}
	for pkg_name, pkg in pairs(object) do
		pkg = _fix_keys(pkg, pkg_name)
		table.insert(array, pkg)
	end
	return array
end

local function validate_uploaded_package() -- checks uploaded package and extracts it
	local checksum = image_checksum(PKG_TAR_PATH)
	local sha = image_sha256_checksum(PKG_TAR_PATH)
	local pkg = extract_package()

	if not pkg then return { code = 1, message = "Invalid file."} end
	
	local new_pkg = opkg.OpkgPkg.get_pkg_from_dir(PKG_CUSTOM_FOLDER_PATH)
	local old_pkg = opkg.OpkgPkg.get_installed_pkg(pkg.package)
	if new_pkg and old_pkg and not old_pkg:version_lesser_than(new_pkg) then
		local message = "Package '%s' with higher version '%s' already installed" % {new_pkg.pkg_name, old_pkg:get("Version")}
		util.perror(message)
		return { code = opkg.ERR_CODES.LOWER_VERSION, message = message, value = pkg.tlt_name }
	end

	pkg.ipk_deps = util.trim(pkg.ipk_deps or "")
	local pkg_files_str = #pkg.ipk_deps > 0 and util.split(pkg.ipk_deps, "%s+", nil, true) or {}
	pkg_files_str[#pkg_files_str + 1] = pkg.ipk_file

	local pkg_file_names = {}
	local pkg_file_sigs = {}
	for _, pkg_file_str in ipairs(pkg_files_str) do
		local name, sig = pkg_file_str:match("([^:]+):(.+)")
		pkg_file_names[#pkg_file_names+1] = name
		pkg_file_sigs[#pkg_file_sigs+1] = sig
	end

	local glob, matches = fs.glob(PKG_CUSTOM_FOLDER_PATH.."/*")
	local hidden_glob = fs.glob(PKG_CUSTOM_FOLDER_PATH.."/.*")
	local verified = matches > 0

	if os.execute("usign -V -m %s/main -P /etc/opkg/keys &> /dev/null" % PKG_CUSTOM_FOLDER_PATH) ~= 0 then
		verified = false
	end

	if verified then
		-- Checks if all files present are in the pkg_files list
		for _, globster in ipairs({glob, hidden_glob}) do
			for file_path in globster do
				local filename = file_path:match(".*/(.+)$")
				if not util.contains({"main", "main.sig", ".", "..", "control_dir"}, filename) then
					if not util.contains(pkg_file_names, filename) then
						verified = false
						break
					end
				end
			end
		end

		-- Check if no files are missing
		-- Checks if all files signed
		for i, pkg_file in ipairs(pkg_file_names) do
			local file_path = PKG_CUSTOM_FOLDER_PATH.."/"..pkg_file
			if not fs.access(file_path) then
				verified = false
				break
			end
			local ipk_sig = util.file_exec("/bin/ipk-sig.sh", {file_path, pkg_file_sigs[i]}) or {}
			if ipk_sig.code ~= 0 then
				verified = false
				break
			end
		end
	end

	return {
		code = 0,
		name = pkg.tlt_name,
		reboot = pkg.reboot or false,
		network_restart = pkg.network_restart or false,
		package = pkg.package,
		checksum = checksum,
		sha256 = sha,
		verified = verified
	}
end

local function append_pkg_statuses(pkgs)
	local pkg_stats = opkg_multi.get_pkg_statuses()
	for app_name, pkg_stat in pairs(pkg_stats) do
		local p
		for pkg_name, pkg in pairs(pkgs) do
			-- first search by app_name
			if pkg.app_name == app_name then
				p = pkg
				break
			end
		end
		p = p or pkgs[app_name]
		if not p then
			p = {}
			pkgs[app_name] = p
		end
		for key, value in pairs(pkg_stat) do
			p[key] = value
		end
	end
	return pkgs
end

function PackageManager:check_status_sid()
	-- actions and status endpoints are conflicting, that's why this check is needed
	local endpoint_url = self.bulk and self.arguments.endpoint or self.request_info.PATH_INFO
	if not endpoint_url:match(self.service_group .. "/status") or (self.sid and self.sid ~= "status") then
		return self:ResponseNotImplemented(string.format("Endpoint for '%s' not implemented.", self.sid or self.service_group))
	end
end

function PackageManager:GET_TYPE_all_packages()
	self:check_status_sid()
	if util.trim(self.query_parameters.refresh_package_list or "") == "1" then
		opkg.fetch_pkg_list(true)
	else
		opkg.fetch_pkg_list()
	end
	return self:ResponseOK(convert_to_array(append_pkg_statuses(get_all_packages())))
end

function PackageManager:GET_TYPE_available_packages()
	self:check_status_sid()
	if util.trim(self.query_parameters.refresh_package_list or "") == "1" then
		opkg.fetch_pkg_list(true)
	else
		opkg.fetch_pkg_list()
	end
	return self:ResponseOK(convert_to_array(get_available_pkgs()))
end

function PackageManager:GET_TYPE_language_packages()
	self:check_status_sid()
	if util.trim(self.query_parameters.refresh_package_list or "") == "1" then
		opkg.fetch_pkg_list(true)
	else
		opkg.fetch_pkg_list()
	end
	local packages = get_available_pkgs()
	local lang_packages = {}
	for pkg_name, p in pairs(packages) do
		if pkg_name:match("vuci%-i18n%-.*") and not opkg.pkg_installed(pkg_name) and not opkg.pkg_pending(pkg_name) then
			lang_packages[pkg_name] = p
			lang_packages[pkg_name].type = PKG_TYPES.AVAILABLE
		end
	end
	return self:ResponseOK(convert_to_array(lang_packages))
end

function PackageManager:GET_TYPE_installed_packages()
	self:check_status_sid()
	return self:ResponseOK(convert_to_array(get_installed_packages()))
end

function PackageManager:GET_TYPE_pending_packages()
	self:check_status_sid()
	opkg.fetch_pkg_list()
	return self:ResponseOK(convert_to_array(get_pending_packages()))
end

function PackageManager:DeleteInstallFiles() -- deletes package and its extracted files
	local _, f = opkg.acquire_lock()
	opkg.delete_custom_pkg_files()
	return self:ResponseOK()
end
PackageManager:action("delete_install_files", PackageManager.DeleteInstallFiles)

function PackageManager:UpdatePackage() -- updates package from server
	opkg.fetch_pkg_list()
	local ok, err_code, msgs = opkg.handle_online_upgrade(self.arguments.data.package)
	if not ok then
		return self:add_critical_error(err_code, opkg.err_str(err_code), "package")
	end
	return self:ResponseOK(nil, msgs)
end

local update_package = PackageManager:action("update_package", PackageManager.UpdatePackage)

	local package_name = update_package:option("package")

function PackageManager:InstallPackage() -- installs package into device
	local custom = self.arguments.data.custom
	local package = self.arguments.data.package
	local language = self.arguments.data.language
	if (not custom or custom == "0") and not package then
		return self:ResponseError("Missing required 'package' option.")
	end

	local ok, err_code, msgs, installed_pkg
	if custom == "1" then
		ok, err_code, msgs, installed_pkg = opkg.handle_offline_install(PKG_CUSTOM_FOLDER_PATH, language == "1")
	else
		opkg.fetch_pkg_list()
		ok, err_code, msgs = opkg.handle_online_install(package, language == "1")
	end

	if not ok then
		return self:add_critical_error(err_code, opkg.err_str(err_code), "package")
	end

	local pkg = installed_pkg or opkg.OpkgPkg.get_installed_pkg(package, true)
	local pkginfo = _fix_keys(parse_pkg_info_full(pkg.pkg_text), pkg.pkg_name)
	pkginfo.messages = msgs
	return self:ResponseOK(pkginfo)
end

local install_package = PackageManager:action("install_package", PackageManager.InstallPackage)

	local package_name = install_package:option("package")

	local custom = install_package:option("custom")
		function custom:validate(value)
			local res, msg = self.dt:is_bool(value)
			if not res then
				return res, msg
			end
			if value == "0" and not self.arguments.data.package then
				return false, "Missing required 'package' option."
			end
			return true
		end

	local language = install_package:option("language")
		function language:validate(value)
			return self.dt:is_bool(value)
		end

local delete_package = PackageManager:action("remove_package", function(self, data)
	local ok, err_code, depends = opkg.handle_package_remove(self.arguments.data.package)
	if not ok then
		return self:add_critical_error(err_code, opkg.err_str(err_code), depends and "depends" or "package", nil, nil, depends)
	end
	return self:ResponseOK()
end)

local delete_package_name = delete_package:option("package")
	delete_package_name.require = true

function PackageManager:install_multiple_packages()
	local packages = self.arguments.data.packages
	if #packages == 0 then return self:add_critical_error(STD_CODES.INVALID_OPT, "Empty packages array.", "packages") end

	local ok, err_code, failed_pkg = opkg_multi.start_multi_install(packages)
	if not ok then
		return self:add_critical_error(err_code, opkg.err_str(err_code), failed_pkg and "packages" or nil, nil, nil, failed_pkg)
	end
	return self:ResponseOK()
end

local install_multiple_packages = PackageManager:action("install_multiple_packages", PackageManager.install_multiple_packages)

local package_names = install_multiple_packages:option("packages", { list = true })
	package_names.require = true

function PackageManager:remove_multiple_packages()
	local packages = self.arguments.data.packages
	if #packages == 0 then return self:add_critical_error(STD_CODES.INVALID_OPT, "Empty packages array.", "packages") end

	local ok, err_code, failed_pkg = opkg_multi.start_multi_remove(packages)
	if not ok then
		return self:add_critical_error(err_code, opkg.err_str(err_code), failed_pkg and "packages" or nil, nil, nil, failed_pkg)
	end
	return self:ResponseOK()
end

local remove_multiple_packages = PackageManager:action("remove_multiple_packages", PackageManager.remove_multiple_packages)

local package_names = remove_multiple_packages:option("packages", { list = true })
	package_names.require = true

function PackageManager:update_multiple_packages()
	local packages = self.arguments.data.packages
	if #packages == 0 then return self:add_critical_error(STD_CODES.INVALID_OPT, "Empty packages array.", "packages") end

	local ok, err_code, failed_pkg = opkg_multi.start_multi_upgrade(packages)
	if not ok then
		return self:add_critical_error(err_code, opkg.err_str(err_code), failed_pkg and "packages" or nil, nil, nil, failed_pkg)
	end
	return self:ResponseOK()
end

local update_multiple_packages = PackageManager:action("update_multiple_packages", PackageManager.update_multiple_packages)

local package_names = update_multiple_packages:option("packages", { list = true })
	package_names.require = true

local lock_file
function PackageManager:UPLOAD_init()
	local ok
	ok, lock_file = opkg.acquire_lock(false) -- <- need to keep file reference, otherwise it gets gc'd by nixio and unlocked
	if not ok or not opkg.delete_custom_pkg_files(true, 10) then -- wait 10 seconds for opkg lock
		return self:add_critical_error(opkg.ERR_CODES.OPKG_BUSY, opkg.err_str(opkg.ERR_CODES.OPKG_BUSY), "package")
	end

	local function handle_request(upload_request)
		for _, file in ipairs(upload_request.files) do
			file.location = PKG_TAR_PATH
		end
		return true
	end

	return { handle_request = handle_request }
end

function PackageManager:UPLOAD_validate_path()
	if self.service_group ~= "actions" or self.sid ~= "upload_package" then
		self:ResponseError("Incorrect upload path")
	end
end

function PackageManager:UPLOAD_after_upload_hook(upload_request)
	local package_size = tonumber(util.exec("zcat " .. PKG_TAR_PATH .. " | wc -c")) / 1024
	local free_space, _, err = require("vuci.util_tlt").check_reserved_space(package_size, "/tmp")
	if not free_space then
		opkg.delete_custom_pkg_files()
		return self:add_critical_error(STD_CODES.NO_SPACE, err, "Upload")
	end

	local validation = validate_uploaded_package()
	if validation.code ~= 0 then
		opkg.delete_custom_pkg_files()
		return self:add_critical_error(validation.code, validation.message, "Request", nil, nil, validation.value)
	end
	return self:ResponseOK(validation)
end

return PackageManager
