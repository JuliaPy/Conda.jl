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
- **experimental:** read the section **Conda and pip** below before using the following
    - `Conda.pip_interop(bool, env)`: config environment to interact with `pip`
    - `Conda.pip(command, package, env)`: run `pip` command on packages in environment

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

## Using a pre-existing Conda installation
To use a pre-existing Conda installation, first create an environment for
`Conda.jl` and then set the `CONDA_JL_HOME` environment variable to the full
path of the environment.
(You have to rebuild `Conda.jl` and many of the packages that use it after this.)
In Julia, run:

```jl
julia> run(`conda create -n conda_jl python conda`)

julia> ENV["CONDA_JL_HOME"] = "/path/to/miniconda/envs/conda_jl"  # change this to your path

pkg> build Conda
```

## Retrieving Miniconda from an alternative location

If you need to download Miniconda from an alternative location, for example if you are behind a corporate firewall that forbids you internet access but it has conda available in the local network, you can set the `CONDA_JL_BASEURL` variable prior to installing `Conda`. For example:

``` jl
julia> ENV["CONDA_JL_BASEURL"] = "https://miniconda-mirror.intranet.net/miniconda"
```

This will retrieve Miniconda installation archive from your intranet location.

## Conda and pip
As of [conda 4.6.0](https://docs.conda.io/projects/conda/en/latest/user-guide/configuration/pip-interoperability.html#improving-interoperability-with-pip) there is improved support for PyPi packages.
**Conda is still the recommended installation method** however if there are packages that are only availible with `pip` one can do the following:

```jl
julia> Conda.pip_interop(true, env)

julia> Conda.pip("install", "somepackage")

julia> Conda.pip("install", ["somepackage1", "somepackage2"])

julia> Conda.pip("uninstall", "somepackage")

julia> Conda.pip("uninstall", ["somepackage1", "somepackage2])
```

If the uninstall command is to be used noninteractively, one can use `"uninstall -y"` to answer yes to the prompts.

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

## License

The Conda.jl package is licensed under the MIT Expat license, and is copyrighted
by Guillaume Fraux and contributors.
