# This tools helps you share private meteor packages.

It is forked from [@DispatchMe's](https://github.com/DispatchMe) project [mgp](https://github.com/DispatchMe/mgp) and modified for Practichem's needs.

## Getting Started

Installing this package is just like any other NPM package (we recommend installing it globally):

    $ sudo npm install -g atmospheric

Add `git-packages.json` to the root of your project.

````
{
	"all": {
    "my:private-package": {
      "git": "git@github.com:my/private-packages.git",
      "version": "commithashortag",
      "path": "optional/directory/path"
    },
    "my:other-private-package": {
      "git": "git@github.com:my/private-packages.git",
      "version": "commithashortag"
    }
  },
  "dev": {
    "my:yet-another-private-package": {
      "git": "git@github.com:my/private-packages.git",
      "branch": "dev"
    }
  }
}
````

- Run `atmospheric` in your meteor directory to copy the packages.

## Flags

**--https**: Convert github ssh urls to https. This is useful for using [`.netrc`](https://gist.github.com/jperl/91f32a37dc1c12c48ad8) on build machines.

    $ atomospheric --https

**--addToGlobals**: This will keep a list of all of the package names as described in the `package.js` file inside of each package and then run `$ meteor add` on each.

    $ atomospheric --addToGlobals

**--**: The list of environments to install from the git-packages.json file. If this options is not used, the packages in the 'all' collection will be installed. **Note:** there must be a space on both sides of the `--` and it should be the last flag. When using this flag, _all_ is not automatically included and must be part of the list.

    $ atmospheric -- all dev staging
    $ atmospheric --addToGlobals -- all staging

## Development

The project is written in Coffeescript. A grunt task is available to automatically build the Coffeescript for release. To develop, run the following:

    $ npm install
    $ grunt
