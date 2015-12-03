#!/usr/bin/env node?
_ = require('lodash')
argv = require('minimist')(process.argv.slice(2))
Packages = require('./packages')
# If link is passed we should symlink the local-packages.json
# or the individual package that was passed.
link = _.contains(argv._, 'link')
# If https is passed, convert any ssh urls to https
# this is useful for using .netrc
useHttps = ! !argv.https
# The last parameter can be an individual package to copy or link.
packageName = argv._[1] or !link and argv._[0]
packageDefinitionFile = process.cwd() + '/' + (if link then 'local-packages.json' else 'git-packages.json')
Packages.fromFile packageDefinitionFile, (error, packages) ->
	# Fail gracefully.
	if error
		return console.log('Unable to load ' + packageDefinitionFile)
	done = _.after(2, ->
		process.exit()
		return
	)
	# Only copy or link the specified package.
	if packageName
		if !packages[packageName]
			return console.log(packageName + ' was not defined in ' + packageDefinitionFile)
		packages = _.pick(packages, packageName, 'token')
	Packages.ensureGitIgnore packages, done
	if link
		Packages.link packages, done
	else
		if useHttps
			packages = Packages.toHttps(packages)
		Packages.load packages, argv.addToGlobals, done
	return
