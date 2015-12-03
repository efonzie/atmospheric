#!/usr/bin/env node?
_ = require('lodash')
argv = require('minimist')(process.argv.slice(2), { '--': true })
Packages = require('./packages')

# If https is passed, convert any ssh urls to https
# this is useful for using .netrc
useHttps = ! !argv.https

# console.log argv

packageDefinitionFile = "#{process.cwd()}/git-packages.json"
Packages.fromFile packageDefinitionFile, argv['--'], (error, packages) ->
	# Fail gracefully.
	if error
		return console.log('Unable to load ' + packageDefinitionFile)
	done = _.after(2, ->
		process.exit()
		return
	)

	Packages.ensureGitIgnore packages, done

	if useHttps
		packages = Packages.toHttps(packages)
	Packages.load packages, argv.addToGlobals, done

	return
