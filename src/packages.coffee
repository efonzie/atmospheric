Packages = module.exports = {}
_ = require('lodash')
fs = require('fs-extra')
path = require('path')
shell = require('shelljs')
# We rely on system git command and its configuration
# In this way it is possible to pick up .netrc

resolvePath = (string) ->
	if string.substr(0, 1) == '~'
		homedir = if process.platform.substr(0, 3) == 'win' then process.env.HOMEPATH else process.env.HOME
		string = homedir + string.substr(1)
	else if string.substr(0, 1) != '/'
		string = process.cwd() + '/' + string
	path.resolve string

if !shell.which('git')
	shell.echo 'Sorry, this script requires git'
	shell.exit 1
ROOT_DIR = process.cwd()
PACKAGE_DIR = ROOT_DIR + '/packages'

###*
# Configure the package directory.
# @param packageDir The directory to copy the packages to.
#														 Defaults to cwd/packages
###

Packages.config = (packageDir) ->
	PACKAGE_DIR = resolvePath(packageDir)
	return

###*
# Load the packages file.
# @param [file] Defaults to cwd/git-packages.json
# @param installEnvironments an array of enviroments that are passed in to install
# @param callback
###

Packages.fromFile = (file, installEnvironments, callback) ->
	if _.isArray(file)
		callback = installEnvironments
		installEnvironments = file
		file = null

	packagesFile = file or process.cwd() + '/git-packages.json'

	fs.readJson packagesFile, (err, packages) ->
		# get the packages for the specified installEnvironments
		installPackages = {}
		installEnvironments = [ 'all' ] if installEnvironments.length == 0
		for installable in installEnvironments
			installPackages = _.extend(installPackages, packages[installable])

		if callback
			callback err, installPackages
		return
	return

# Create a packages document per git url.
# { gitRepo: { version: { packageName: packagePath, .. }, ... } }

getPackagesDict = (packages) ->
	resolvedPackages = {}
	_.forOwn packages, (definition, packageName) ->
		if !definition
			return
		git = definition.git
		if !git
			return
		repo = resolvedPackages[git] = resolvedPackages[git] or {}
		# If no branch provided - checkout origin HEAD and
		# don't show 'detached HEAD' notification
		branch = definition.branch or '-q origin'
		# If no version provided - pull HEAD
		version = definition.version or 'HEAD'
		repo[branch] = repo[branch] or {}
		repo[branch][version] = repo[branch][version] or {}
		repo[branch][version][packageName] = definition.path or ''
		return
	resolvedPackages

# Test if path exists and fail with error if it is not exists

checkPathExist = (path, errorMessage) ->
	if !shell.test('-e', path)
		shell.echo 'Error: ' + errorMessage
		shell.exit 1
	return

###*
# Get the Meteor name of the package being added
# @param dest -	path to the package
# @return string
###

getPackageName = (dest) ->
	packageJsPath = dest + '/package.js'
	packageName = false
	lines = []
	checkPathExist packageJsPath, 'package.js file not found.'
	packageJsContents = fs.readFileSync(packageJsPath, 'utf8')
	lines = packageJsContents.split(/\n/g)
	for line of lines
		if /name/.test(lines[line]) and lines[line].match(/:/g).length >= 2
			packageName = lines[line].split(/:(.+)?/)[1].trim().replace(/\"/g, '').replace(/\'/g, '').replace(/,/g, '')
			break
	packageName

###*
# Loop through the list of packages and add them to the Meteor app
# @param packagesToAddToMeteor - list of packages
###

addPackagesToMeteor = (packagesToAddToMeteor) ->
	shell.cd ROOT_DIR
	shell.echo 'Adding the cloned packages to the Meteor app...'
	for index of packagesToAddToMeteor
		meteorPackage = packagesToAddToMeteor[index]
		shell.echo 'Adding package \'' + meteorPackage + '\'...'
		if shell.exec('meteor add ' + meteorPackage, silent: false).code != 0
			shell.echo 'Error: Package \'' + meteorPackage + '\' could not be added to the Meteor app.'
	return

###*
# Create a git ignore in the package directory for the packages.
# @param packages
# @param {Function} callback
###

Packages.ensureGitIgnore = (packages, callback) ->
	filePath = PACKAGE_DIR + '/.gitignore'
	fs.ensureFileSync filePath
	fs.readFile filePath, 'utf8', (err, gitIgnore) ->
		# Append packages to the gitignore
		_.forOwn packages, (def, packageName) ->
			# Convert colons in package names to dashes for Windows
			packageName = packageName.replace(/:/g, '-')
			if packageName == 'token' or gitIgnore.indexOf(packageName) > -1
				return
			gitIgnore += packageName + '\n'
			return
		fs.writeFile filePath, gitIgnore, callback
		return
	return

###*
# Clones repositories and copy the packages.
# @param packages The packages to load.
# @param addToGlobals whether or not to automatically add the packages with meteor add
# @param {Function} callback
###

Packages.load = (packages, addToGlobals, callback) ->
	shell.mkdir '-p', PACKAGE_DIR
	if addToGlobals == undefined or addToGlobals == null
		addToGlobals = false
	# Create a temp directory to store the tarballs
	tempDir = PACKAGE_DIR + '/temp'
	shell.rm '-fr', tempDir
	shell.mkdir '-p', tempDir
	shell.cd tempDir
	packagesToAddToMeteor = []
	resolvedPackages = getPackagesDict(packages)
	repoDirIndex = 0
	_.forOwn resolvedPackages, (repoPackages, gitRepo) ->
		repoDir = tempDir + '/' + repoDirIndex
		# Change to the temp directory before cloning the repo
		shell.cd tempDir
		if shell.exec('git clone ' + gitRepo + ' ' + repoDirIndex, silent: true).code != 0
			shell.echo 'Error: Git clone failed: ' + gitRepo
			shell.exit 1
		# Change to the repo directory
		shell.cd repoDir
		repoDirIndex++
		_.forOwn repoPackages, (branchPackages, branch) ->
			if shell.exec('git checkout -f ' + branch, silent: false).code != 0
				shell.echo 'Error: Git checkout branch failed for ' + gitRepo + '@' + version
				shell.exit 1
			_.forOwn branchPackages, (storedPackages, version) ->
				_.forOwn storedPackages, (src, packageName) ->
					if shell.exec('git reset --hard ' + version, silent: false).code != 0
						shell.echo 'Error: Git checkout failed for ' + packageName + '@' + version
						shell.exit 1
					packageName = packageName.replace(/:/g, '-')
					shell.echo '\nProcessing ' + packageName + ' at ' + version
					shell.echo 'Cleaning up'
					dest = PACKAGE_DIR + '/' + packageName
					shell.rm '-rf', dest
					src = repoDir + '/' + src + '/'
					checkPathExist src, 'Cannot find package in repository: ' + src
					shell.echo 'Copying package'
					# Adding the dot after `src` forces it to copy hidden files as well
					shell.cp '-rf', src + '.', dest
					checkPathExist dest, 'Cannot copy package: ' + dest
					shell.echo 'Done...\n'
					if addToGlobals
						fetchedPackageName = getPackageName(dest)
						if fetchedPackageName
							packagesToAddToMeteor.push packageName
					return
				return
			return
		return
	# Remove the temp directory after the packages are copied.
	shell.cd process.cwd()
	shell.rm '-fr', tempDir
	# add the packages to meteor
	if addToGlobals
		addPackagesToMeteor packagesToAddToMeteor
	# finish up
	callback()
	return

###*
# Convert git ssh urls to https. This is useful for defining ssh locally and then using .netrc in build tools.
###

Packages.toHttps = (packages) ->
	packages = _.cloneDeep(packages)
	_.forOwn packages, (definition, packageName) ->
		if !definition.git
			throw new Error('No Git url defined for ' + packageName)
		gitUrl = definition.git.substring(definition.git.lastIndexOf('@') + 1, definition.git.lastIndexOf(':'))
		definition.git = 'https://' + gitUrl + '/' + definition.git.substring(gitUrl.length + 5)
		return
	packages
