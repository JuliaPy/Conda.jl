# Conda.jl

[![Build Status -- OS X and Linux](https://travis-ci.org/JuliaPy/Conda.jl.svg?branch=master)](https://travis-ci.org/JuliaPy/Conda.jl)
[![Build status -- Windows](https://ci.appveyor.com/api/projects/status/edlxohso05re3v40/branch/master?svg=true)](https://ci.appveyor.com/project/StevenGJohnson/conda-jl)


This package allows one to use [conda](http://conda.pydata.org/) as a binary
provider for Julia. While other binary providers like
[Hombrew.jl](https://github.com/JuliaLang/Homebrew.jl),
[AptGet](https://en.wikipedia.org/wiki/Advanced_Packaging_Tool#apt-get) or
[WinRPM.jl](https://github.com/JuliaLang/WinRPM.jl) are platform-specific,
Conda.jl is a cross-platform alternative. It can also be used without
administrator rights, in contrast to the current Linux-based providers.

As such, `Conda.jl` primary audience is Julia packages developers who have a
dependency on  some native library.

`conda` is a package manager which started as the binary package manager for the
Anaconda Python distribution, but it also provides arbitrary packages. Instead
of the full Anaconda distribution, `Conda.jl` uses the miniconda Python
environment, which only includes `conda` and its dependencies.

`Conda.jl` is **NOT** an alternative Julia package manager, nor a way to manage
Python installations. It will not use any pre-existing Anaconda or Python
installation on  your machine.

## Basic functionality

You can install this package by running `Pkg.add("Conda")` at the Julia prompt.

Basic package managing utilities are provided in the Conda module:

- `Conda.add(package, env)`: install a package;
- `Conda.rm(package, env)`: remove (uninstall) a package;
- `Conda.update(env)`: update all installed packages to the latest version;
- `Conda.list(env)`: list all installed packages.
- `Conda.add_channel(channel, env)`: add a channel to the list of channels;
- `Conda.channels(env)`: get the current list of channels;
- `Conda.rm_channel(channel, env)`: remove a channel from the list of channels;

Parameter `env` is optional and defaults to `ROOTENV`. See below for more info.

### Conda Environments

You can use Conda environments via `Conda.jl`. Note that python packages should
be installed to the root environment or the python environment used in
`PyCall.jl`. To use environments use the `env` parameter. Environment name can
be specified as a `Symbol` or the full path as a `String`.

```julia
using Conda
Conda.add("libnetcdf", :my_env)
Conda.add("libnetcdf", "/path/to/directory")
```

## BinDeps integration: using Conda.jl as a package author

Conda.jl can be used as a `Provider` for
[BinDeps](https://github.com/JuliaLang/BinDeps.jl) with the `Conda.Manager`
type. You first need to write a [conda
recipe](http://conda.pydata.org/docs/building/recipe.html), and upload the
corresponding build to [binstar](https://binstar.org/). Then, add Conda in your
REQUIRE file, and add the following to your `deps/build.jl` file:

```julia
using BinDeps
@BinDeps.setup
netcdf = library_dependency("netcdf", aliases = ["libnetcdf","libnetcdf4"])

...

using Conda
provides(Conda.Manager, "libnetcdf", netcdf)
```

If your dependency is available in another channel than the default one, you
should register that channel.

```julia
using Conda
Conda.add_channel("my_channel")
provides(Conda.Manager, "libnetcdf", netcdf)
```

If the binary dependency is only available for some OS, give this information to
BinDeps:

```julia
provides(Conda.Manager, "libnetcdf", netcdf, os=:Linux)
```

To tell BinDeps to install the package to an environments, use `EnvManager`.

```julia
provides(Conda.EnvManager{:my_env}, "libnetcdf", netcdf)
```

## Using an already existing Conda installation
To use an already existing Conda installation, first create an environment for
`Conda.jl` and then set `CONDA_JL_HOME` to the full path of the environment.
You have to build `Conda.jl` and all the packages using `Conda.jl` after this.

```shell
conda create -n conda_jl python
export CONDA_JL_HOME="/path/to/miniconda/envs/conda_jl"
julia -e "Pkg.build('Conda')"
```


## Bugs and suggestions

Conda have been tested on Linux, OS X, and Windows. It should work on all these
platforms.

Please report any bug or suggestion as an
[issue](https://github.com/Luthaf/Conda.jl/issues)

## Licence

The Conda.jl package is licensed under the MIT Expat license, and is copyrighted
by Guillaume Fraux and contributors.
