# Conda.jl

[![Build Status -- OS X and Linux](https://travis-ci.org/JuliaPy/Conda.jl.svg?branch=master)](https://travis-ci.org/JuliaPy/Conda.jl)
[![Build status -- Windows](https://ci.appveyor.com/api/projects/status/edlxohso05re3v40/branch/master?svg=true)](https://ci.appveyor.com/project/StevenGJohnson/conda-jl)

This package allows one to use [conda](http://conda.pydata.org/) as a cross-platform binary provider for Julia for other Julia packages,
especially to install binaries that have complicated dependencies
like Python.

`conda` is a package manager which started as the binary package manager for the
Anaconda Python distribution, but it also provides arbitrary packages. Instead
of the full Anaconda distribution, `Conda.jl` uses the miniconda Python
environment, which only includes `conda` and its dependencies.

## Basic functionality

At the `julia>` prompt,
type a `]` (close square bracket) to get a [Julia package prompt `pkg>`](https://docs.julialang.org/en/v1/stdlib/Pkg/),
where you can type `add Conda` to install this package.

Once Conda is installed, you can run `import Conda` to load the package and run a variety of package-management functions:

- `Conda.add(package, env; channel="")`: install a package from a specified channel (optional);
- `Conda.rm(package, env)`: remove (uninstall) a package;
- `Conda.update(env)`: update all installed packages to the latest version;
- `Conda.list(env)`: list all installed packages.
- `Conda.add_channel(channel, env)`: add a channel to the list of channels;
- `Conda.channels(env)`: get the current list of channels;
- `Conda.rm_channel(channel, env)`: remove a channel from the list of channels;

The parameter `env` is optional and defaults to `ROOTENV`. See below for more info.

### Conda environments

[Conda environments](http://conda.pydata.org/docs/using/envs.html) allow you to
manage multiple distinct sets of packages in a way that avoids conflicts and
allows you to install different versions of packages simultaneously.

The `Conda.jl` package supports environments by allowing you to pass an optional
`env` parameter to functions for package installation, update, and so on. If
this parameter is not specified, then the default "root" environment
(corresponding to the path in `Conda.ROOTENV`) is used. The environment name can
be specified as a `Symbol`, or the full path of the environment
(if you want to use an environment in a nonstandard directory) can
be passed as a string.

For example:

```julia
using Conda
Conda.add("libnetcdf", :my_env)
Conda.add("libnetcdf", "/path/to/directory")
Conda.add("libnetcdf", "/path/to/directory"; channel="anaconda")
```

(NOTE: If you are installing Python packages for use with
[PyCall](https://github.com/JuliaPy/PyCall.jl), you must use the root
environment.)

## BinDeps integration: using Conda.jl as a package author

Conda.jl can be used as a `Provider` for
[BinDeps](https://github.com/JuliaLang/BinDeps.jl) with the
[CondaBinDeps](https://github.com/JuliaPackaging/CondaBinDeps.jl)
package.

## Manually specifying Conda directory

To manually specify the conda directory, for example, to use a pre-existing Conda installation, first create an environment for
`Conda.jl` and then set the `CONDA_JL_HOME` environment variable to the full
path of the environment.
You have to rebuild `Conda.jl` and many of the packages that use it after this.
So as to install their dependancies to the specified enviroment.

```shell
conda create -n conda_jl python conda
export CONDA_JL_HOME="/path/to/miniconda/envs/conda_jl"
julia -e 'Pkg.build("Conda")'
```
## Using Python 2
By default, the Conda.jl package [installs Python 3]((https://conda.io/docs/py2or3.htm)),
and this version of Python is used for all Python dependencies.  If you want to
use Python 2 instead, set `CONDA_JL_VERSION` to `"2"` *prior to installing Conda*.
(This only needs to be done once; Conda subsequently remembers the version setting.)

Once you have installed Conda and run its Miniconda installer, the Python version
cannot be changed without deleting your existing Miniconda installation.
If you set `ENV["CONDA_JL_VERSION"]="2"` and run `Pkg.build("Conda")`, it will
tell you how to delete your existing Miniconda installation if needed.

Most users will not need to use Python 2. This is provided primarily for developers wishing to test their packages for both Python 2 and Python, e.g. by setting the `CONDA_JL_VERSION`
variable on [TravisCI](https://docs.travis-ci.com/user/environment-variables/) and/or [AppVeyor](https://www.appveyor.com/docs/build-configuration/#environment-variables).


## Bugs and suggestions

Conda has been tested on Linux, OS X, and Windows.

Please report any bug or suggestion as an
[github issue](https://github.com/JuliaPy/Conda.jl/issues)

### Known issues

- Conda does not support paths with non-ASCII characters (e.g. see [conda issue #7023](https://github.com/conda/conda/issues/7023)). If you are experiencing issues(e.g. your home directory contains non-ASCII characters), then try [manually specifying the Conda directory](#manually-specifying-conda-directory).

## License

The Conda.jl package is licensed under the MIT Expat license, and is copyrighted
by Guillaume Fraux and contributors.
