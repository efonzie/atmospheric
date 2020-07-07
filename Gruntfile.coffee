module.exports = (grunt) ->

	grunt.initConfig
		pkg: grunt.file.readJSON('package.json')
		coffee:
			atmospheric:
				options:
					bare: true
				files:
					'lib/run.js': 'src/run.coffee'
					'lib/packages.js': 'src/packages.coffee'
		usebanner:
			atmospheric:
				options:
					position: 'top'
					banner: '#!/usr/bin/env node'
					linebreak: true
				files:
					src: [ 'lib/run.js' ]
		watch:
			coffee:
				files: [ 'src/**/*.coffee' ]
				tasks: [ 'coffee', 'banner' ]
				options:
					spawn: false

	grunt.loadNpmTasks 'grunt-contrib-coffee'
	grunt.loadNpmTasks 'grunt-banner'

	grunt.registerTask 'default', [ 'coffee', 'usebanner', 'watch' ]
