# Conda.jl

[![Build Status](https://travis-ci.org/Luthaf/Conda.jl.svg)](https://travis-ci.org/Luthaf/Conda.jl)

This package allow to use [conda](http://conda.pydata.org/) as a binary provider for
Julia. `conda` is a package manager which started as the binary package manager for the
Anaconda Python distribution, but it also provide arbitrary packages. Conda.jl uses the
miniconda minimalistic Python environment to use `conda`.


## Basic functionalities

Basic package managing utilities are provided in the Conda module:
- `Conda.add(package)`: install a package;
- `Conda.rm(package)`: remove (uninstall) a package;
- `Conda.update()`: update all installed packages to the latest version;
- `Conda.list()`: list all installed packages.


## BinDeps integration: using Conda.jl as a package author

Conda.jl can be used as a `Provider` for BinDeps with the `Conda.Manager` type. You first
needs to write a [conda recipe](http://conda.pydata.org/docs/building/recipe.html), and
upload the corresponding build to binstar. Then, add Conda in your REQUIRE file, and add
in your `deps/build.jl` file the following:

```julia
using BinDeps
@BinDeps.setup
netcdf = library_dependency("netcdf", aliases = ["libnetcdf","libnetcdf4"])

...

using Conda
provides(Conda.Manager, "libnetcdf", netcdf)
```

If your dependency is available in another channel than the default one, you should add
this channel in the CHANNELS array. For example, if you uses binstar:
```julia
using Conda
push!(Conda.CHANNELS, "https://conda.binstar.org/<username>")
provides(Conda.Manager, "libnetcdf", netcdf)
```

If the binary dependency is only available for some OS, give this information to BinDeps:
```julia
provides(Conda.Manager, "libnetcdf", netcdf, os=:Linux)
```
