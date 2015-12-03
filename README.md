# This tools helps you share private meteor packages.

## Getting Started

- `$ npm install -g ssh://git@code.practichem.com:7999/npm/atmospheric.git`
- Add `git-packages.json` to the root of your project.

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

**--**: The list of environments to install from the git-packages.json file. If this options is not used, the packages in the 'all' collection will be installed. **Note:** there must be a space on both sides of the `--` and it should be the last flag.

    $ atmospheric -- all dev staging
    $ atmospheric --addToGlobals -- all staging
