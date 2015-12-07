var PACKAGE_DIR, Packages, ROOT_DIR, _, addPackagesToMeteor, checkPathExist, fs, getPackageName, getPackagesDict, path, resolvePath, shell;

Packages = module.exports = {};

_ = require('lodash');

fs = require('fs-extra');

path = require('path');

shell = require('shelljs');

resolvePath = function(string) {
  var homedir;
  if (string.substr(0, 1) === '~') {
    homedir = process.platform.substr(0, 3) === 'win' ? process.env.HOMEPATH : process.env.HOME;
    string = homedir + string.substr(1);
  } else if (string.substr(0, 1) !== '/') {
    string = process.cwd() + '/' + string;
  }
  return path.resolve(string);
};

if (!shell.which('git')) {
  shell.echo('Sorry, this script requires git');
  shell.exit(1);
}

ROOT_DIR = process.cwd();

PACKAGE_DIR = ROOT_DIR + '/packages';


/**
 * Configure the package directory.
 * @param packageDir The directory to copy the packages to.
 *														 Defaults to cwd/packages
 */

Packages.config = function(packageDir) {
  PACKAGE_DIR = resolvePath(packageDir);
};


/**
 * Load the packages file.
 * @param [file] Defaults to cwd/git-packages.json
 * @param installEnvironments an array of enviroments that are passed in to install
 * @param callback
 */

Packages.fromFile = function(file, installEnvironments, callback) {
  var packagesFile;
  if (_.isArray(file)) {
    callback = installEnvironments;
    installEnvironments = file;
    file = null;
  }
  packagesFile = file || process.cwd() + '/git-packages.json';
  fs.readJson(packagesFile, function(err, packages) {
    var i, installPackages, installable, len;
    installPackages = {};
    if (installEnvironments.length === 0) {
      installEnvironments = ['all'];
    }
    for (i = 0, len = installEnvironments.length; i < len; i++) {
      installable = installEnvironments[i];
      installPackages = _.extend(installPackages, packages[installable]);
    }
    if (callback) {
      callback(err, installPackages);
    }
  });
};

getPackagesDict = function(packages) {
  var resolvedPackages;
  resolvedPackages = {};
  _.forOwn(packages, function(definition, packageName) {
    var branch, git, repo, version;
    if (!definition) {
      return;
    }
    git = definition.git;
    if (!git) {
      return;
    }
    repo = resolvedPackages[git] = resolvedPackages[git] || {};
    branch = definition.branch || '-q origin';
    version = definition.version || 'HEAD';
    repo[branch] = repo[branch] || {};
    repo[branch][version] = repo[branch][version] || {};
    repo[branch][version][packageName] = definition.path || '';
  });
  return resolvedPackages;
};

checkPathExist = function(path, errorMessage) {
  if (!shell.test('-e', path)) {
    shell.echo('Error: ' + errorMessage);
    shell.exit(1);
  }
};


/**
 * Get the Meteor name of the package being added
 * @param dest -	path to the package
 * @return string
 */

getPackageName = function(dest) {
  var line, lines, packageJsContents, packageJsPath, packageName;
  packageJsPath = dest + '/package.js';
  packageName = false;
  lines = [];
  checkPathExist(packageJsPath, 'package.js file not found.');
  packageJsContents = fs.readFileSync(packageJsPath, 'utf8');
  lines = packageJsContents.split(/\n/g);
  for (line in lines) {
    if (/name/.test(lines[line]) && lines[line].match(/:/g).length >= 2) {
      packageName = lines[line].split(/:(.+)?/)[1].trim().replace(/\"/g, '').replace(/\'/g, '').replace(/,/g, '');
      break;
    }
  }
  return packageName;
};


/**
 * Loop through the list of packages and add them to the Meteor app
 * @param packagesToAddToMeteor - list of packages
 */

addPackagesToMeteor = function(packagesToAddToMeteor) {
  var index, meteorPackage;
  shell.cd(ROOT_DIR);
  shell.echo('Adding the cloned packages to the Meteor app...');
  for (index in packagesToAddToMeteor) {
    meteorPackage = packagesToAddToMeteor[index];
    shell.echo('Adding package \'' + meteorPackage + '\'...');
    if (shell.exec('meteor add ' + meteorPackage, {
      silent: false
    }).code !== 0) {
      shell.echo('Error: Package \'' + meteorPackage + '\' could not be added to the Meteor app.');
    }
  }
};


/**
 * Create a git ignore in the package directory for the packages.
 * @param packages
 * @param {Function} callback
 */

Packages.ensureGitIgnore = function(packages, callback) {
  var filePath;
  filePath = PACKAGE_DIR + '/.gitignore';
  fs.ensureFileSync(filePath);
  fs.readFile(filePath, 'utf8', function(err, gitIgnore) {
    _.forOwn(packages, function(def, packageName) {
      packageName = packageName.replace(/:/g, '-');
      if (packageName === 'token' || gitIgnore.indexOf(packageName) > -1) {
        return;
      }
      gitIgnore += packageName + '\n';
    });
    fs.writeFile(filePath, gitIgnore, callback);
  });
};


/**
 * Clones repositories and copy the packages.
 * @param packages The packages to load.
 * @param addToGlobals whether or not to automatically add the packages with meteor add
 * @param {Function} callback
 */

Packages.load = function(packages, addToGlobals, callback) {
  var packagesToAddToMeteor, repoDirIndex, resolvedPackages, tempDir;
  shell.mkdir('-p', PACKAGE_DIR);
  if (addToGlobals === void 0 || addToGlobals === null) {
    addToGlobals = false;
  }
  tempDir = PACKAGE_DIR + '/temp';
  shell.rm('-fr', tempDir);
  shell.mkdir('-p', tempDir);
  shell.cd(tempDir);
  packagesToAddToMeteor = [];
  resolvedPackages = getPackagesDict(packages);
  repoDirIndex = 0;
  _.forOwn(resolvedPackages, function(repoPackages, gitRepo) {
    var repoDir;
    repoDir = tempDir + '/' + repoDirIndex;
    shell.cd(tempDir);
    if (shell.exec('git clone ' + gitRepo + ' ' + repoDirIndex, {
      silent: true
    }).code !== 0) {
      shell.echo('Error: Git clone failed: ' + gitRepo);
      shell.exit(1);
    }
    shell.cd(repoDir);
    repoDirIndex++;
    _.forOwn(repoPackages, function(branchPackages, branch) {
      if (shell.exec('git checkout -f ' + branch, {
        silent: false
      }).code !== 0) {
        shell.echo('Error: Git checkout branch failed for ' + gitRepo + '@' + version);
        shell.exit(1);
      }
      _.forOwn(branchPackages, function(storedPackages, version) {
        _.forOwn(storedPackages, function(src, packageName) {
          var dest, fetchedPackageName;
          if (shell.exec('git reset --hard ' + version, {
            silent: false
          }).code !== 0) {
            shell.echo('Error: Git checkout failed for ' + packageName + '@' + version);
            shell.exit(1);
          }
          packageName = packageName.replace(/:/g, '-');
          shell.echo('\nProcessing ' + packageName + ' at ' + version);
          shell.echo('Cleaning up');
          dest = PACKAGE_DIR + '/' + packageName;
          shell.rm('-rf', dest);
          src = repoDir + '/' + src + '/';
          checkPathExist(src, 'Cannot find package in repository: ' + src);
          shell.echo('Copying package');
          shell.cp('-rf', src + '.', dest);
          checkPathExist(dest, 'Cannot copy package: ' + dest);
          shell.echo('Done...\n');
          if (addToGlobals) {
            fetchedPackageName = getPackageName(dest);
            if (fetchedPackageName) {
              packagesToAddToMeteor.push(packageName);
            }
          }
        });
      });
    });
  });
  shell.cd(process.cwd());
  shell.rm('-fr', tempDir);
  if (addToGlobals) {
    addPackagesToMeteor(packagesToAddToMeteor);
  }
  callback();
};


/**
 * Convert git ssh urls to https. This is useful for defining ssh locally and then using .netrc in build tools.
 */

Packages.toHttps = function(packages) {
  packages = _.cloneDeep(packages);
  _.forOwn(packages, function(definition, packageName) {
    var gitUrl;
    if (!definition.git) {
      throw new Error('No Git url defined for ' + packageName);
    }
    gitUrl = definition.git.substring(definition.git.lastIndexOf('@') + 1, definition.git.lastIndexOf(':'));
    definition.git = 'https://' + gitUrl + '/' + definition.git.substring(gitUrl.length + 5);
  });
  return packages;
};
