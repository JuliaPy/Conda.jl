# Conda.jl

[![Build Status -- OS X and Linux](https://travis-ci.org/Luthaf/Conda.jl.svg)](https://travis-ci.org/Luthaf/Conda.jl)
[![Build status -- Windows](https://ci.appveyor.com/api/projects/status/wpm9cmlxttnfxcks/branch/master?svg=true)](https://ci.appveyor.com/project/Luthaf/conda-jl/branch/master)

This package allows one to use [conda](http://conda.pydata.org/) as a binary provider for Julia.
While other binary providers like [Hombrew.jl](https://github.com/JuliaLang/Homebrew.jl),
[AptGet](https://en.wikipedia.org/wiki/Advanced_Packaging_Tool#apt-get) or
[WinRPM.jl](https://github.com/JuliaLang/WinRPM.jl) are platform-specific,
Conda.jl is a cross-platform alternative. It can also be used without administrator rights,
in contrast to the current Linux-based providers.

`conda` is a package manager which started as the binary package manager
for the Anaconda Python distribution, but it also provides arbitrary packages.
Instead of the full Anaconda distribution, Conda.jl uses the miniconda Python environment,
which only includes `conda` and its dependencies.

You can install it by running `Pkg.add("Conda")` at the Julia prompt.

## Basic functionality

Basic package managing utilities are provided in the Conda module:

- `Conda.add(package)`: install a package;
- `Conda.rm(package)`: remove (uninstall) a package;
- `Conda.update()`: update all installed packages to the latest version;
- `Conda.list()`: list all installed packages.

## BinDeps integration: using Conda.jl as a package author

Conda.jl can be used as a `Provider` for [BinDeps](https://github.com/JuliaLang/BinDeps.jl)
with the `Conda.Manager` type. You first need to write a
[conda recipe](http://conda.pydata.org/docs/building/recipe.html),
and upload the corresponding build to [binstar](https://binstar.org/).
Then, add Conda in your REQUIRE file, and add the following to your `deps/build.jl` file:

```julia
using BinDeps
@BinDeps.setup
netcdf = library_dependency("netcdf", aliases = ["libnetcdf","libnetcdf4"])

...

using Conda
provides(Conda.Manager, "libnetcdf", netcdf)
```

If your dependency is available in another channel than the default one, you should add
that channel in the CHANNELS array. For example, if you use binstar:

```julia
using Conda
push!(Conda.CHANNELS, "https://conda.binstar.org/<username>")
provides(Conda.Manager, "libnetcdf", netcdf)
```

If the binary dependency is only available for some OS, give this information to BinDeps:

```julia
provides(Conda.Manager, "libnetcdf", netcdf, os=:Linux)
```

## Bugs and suggestions

Conda have been tested on Linux and OS X, and the code for Windows is present but untested.

Please report any bug or suggestion as an [issue](https://github.com/Luthaf/Conda.jl/issues)

## Licence

The Conda.jl package is licensed under the MIT Expat license, and is copyrighted by
Guillaume Fraux and contributors.
