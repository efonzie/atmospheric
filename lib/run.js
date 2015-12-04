#!/usr/bin/env node
var Packages, _, argv, packageDefinitionFile, useHttps;

_ = require('lodash');

argv = require('minimist')(process.argv.slice(2), {
  '--': true
});

Packages = require('./packages');

useHttps = !!argv.https;

packageDefinitionFile = (process.cwd()) + "/git-packages.json";

Packages.fromFile(packageDefinitionFile, argv['--'], function(error, packages) {
  var done;
  if (error) {
    return console.log('Unable to load ' + packageDefinitionFile);
  }
  done = _.after(2, function() {
    process.exit();
  });
  Packages.ensureGitIgnore(packages, done);
  if (useHttps) {
    packages = Packages.toHttps(packages);
  }
  Packages.load(packages, argv.addToGlobals, done);
});
