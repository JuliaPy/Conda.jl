"""
The Conda module provides access to the [conda](http://conda.pydata.org/) packages
manager. Its main purpose is to be used as a BinDeps provider, to install binary
dependencies of other Julia packages.

The main functions in Conda are:

- `Conda.add(package)`: install a package;
- `Conda.rm(package)`: remove (uninstall) a package;
- `Conda.update()`: update all installed packages to the latest version;
- `Conda.list()`: list all installed packages.

To use Conda as a binary provider for BinDeps, the `Conda.Manager` type is proposed. A
small example looks like this:

```julia
# Declare dependency
using BinDeps
@BinDeps.setup
netcdf = library_dependency("netcdf", aliases = ["libnetcdf","libnetcdf4"])

using Conda
# Use alternative conda channel.
push!(Conda.CHANNELS, "https://conda.binstar.org/<username>")
provides(Conda.Manager, "libnetcdf", netcdf)
```
"""
module Conda
using Compat
using JSON

"Prefix for installation of all the packages."
const PREFIX = Pkg.dir("Conda", "deps", "usr")

const conda = joinpath(PREFIX, "bin", "conda")
const DL_LOAD_PATH = VERSION >= v"0.4.0-dev+3844" ? Libdl.DL_LOAD_PATH : Base.DL_LOAD_PATH

CHANNELS = AbstractString[]
additional_channels() = ["--channel " * channel for channel in CHANNELS]

"Get the miniconda installer URL."
function _installer_url()
    res = "https://repo.continuum.io/miniconda/Miniconda-latest-"
    if OS_NAME == :Darwin
        res *= "MacOSX"
    elseif OS_NAME in [:Linux, :Windows]
        res *= string(OS_NAME)
    else
        error("Unsuported OS.")
    end

    if WORD_SIZE == 64
        res *= "-x86_64"
    else
        res *= "-x86"
    end

    if OS_NAME in [:Darwin, :Linux]
        res *= ".sh"
    else
        res *= ".exe"
    end
    return res
end

"Install miniconda"
function _install()
    # Ensure PREFIX exists
    mkpath(PREFIX)
    info("Downloading miniconda installer …")
    installer = joinpath(PREFIX, "installer")
    download(_installer_url(), installer)
    chmod(installer, 33261)  # 33261 corresponds to 755 mode of the 'chmod' program
    run(`$installer -b -f -p $PREFIX`)
end

"Install a new package."
function add(pkg::AbstractString)
    channels = additional_channels()
    run(`$conda install -y $channels $pkg`)
end

"Uninstall a package."
function rm(pkg::AbstractString)
    run(`$conda remove -y $pkg`)
end

"Update all installed packages."
function update()
    channels = additional_channels()
    for package in _installed_packages()
        run(`$conda update $channels -y $package`)
    end
end

"List all installed packages as an array."
function _installed_packages()
    packages = JSON.parse(readall(`$conda list --json`))
    regex = r"([\w_-]*)-\d.*"
    for i in 1:length(packages)
        m = match(regex, packages[i])
        if m != nothing
            packages[i] = m.captures[1]
        else
            error("Failed parsing string: $(packages[i]). Please open an issue!")
        end
    end
    return packages
end

"List all installed packages to standard output."
function list()
    run(`$conda list`)
end

"Check if a given package exists."
function exists(package::AbstractString)
    channels = additional_channels()
    res = readall(`$conda search $channels --full-name $package`)
    if chomp(res) == "Fetching package metadata: ...."
        # No package found
        return false
    else
        return true
    end
end

include("bindeps_conda.jl")

end
