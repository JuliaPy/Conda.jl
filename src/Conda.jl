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
const PREFIX = abspath(dirname(@__FILE__), "..", "deps", "usr")
"""Returns the directory for the binary files of a package. Attention on unix
 `bindir` and `scriptsdir` returns the same path while on windows it is two separate directories.
 Use `scriptdir()` to ex. get numpy's f2py or ipython"""
@unix_only begin function bindir(package) 
        packages = _installed_packages_dict()
        haskey(packages, package) || error("Package '$package' not found")
        joinpath(PREFIX, "pkgs", packages[package][2], "bin")
    end
end
"""Returns the directory for the scripts files of a package. Attention on unix
 `bindir` and `scriptsdir` returns the same path while on windows it is two separate directories.
 Use `scriptdir()` to ex. get numpy's f2py or ipython"""
scriptsdir(package) = bindir(package)
"""Returns the directory for the binary files of a package. Attention on unix
 `bindir` and `scriptsdir` returns the same path while on windows it is two separate directories.
 Use `scriptdir()` to ex. get numpy's f2py or ipython"""
@windows_only function bindir(package) 
    packages = _installed_packages_dict()
    haskey(packages, package) || error("Package '$package' not found")
    joinpath(PREFIX, "pkgs", packages[package][2], "Library", "bin")
end
"""Returns the directory for the scripts files of a package. Attention on unix
 `bindir` and `scriptsdir` returns the same path while on windows it is two separate directories.
 Use `scriptdir()` to ex. get numpy's f2py or ipython"""
@windows_only function scriptsdir(package) 
    packages = _installed_packages_dict()
    haskey(packages, package) || error("Package '$package' not found")
    joinpath(PREFIX, "pkgs", packages[package][2], "Scripts")
end

@unix_only const conda = joinpath(PREFIX, "bin", "conda")
@windows_only const conda = joinpath(PREFIX, "Scripts", "conda")

CHANNELS = AbstractString[]
additional_channels() = ["--channel " * channel for channel in CHANNELS]

"Get the miniconda installer URL."
function _installer_url()
    res = "http://repo.continuum.io/miniconda/Miniconda-3.9.1-"
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
function _install_conda()
    # Ensure PREFIX exists
    mkpath(PREFIX)
    info("Downloading miniconda installer ...")
    @unix_only installer = joinpath(PREFIX, "installer.sh")
    @windows_only installer = joinpath(PREFIX, "installer.exe")
    download(_installer_url(), installer)

    info("Installing miniconda ...")
    @unix_only begin
        chmod(installer, 33261)  # 33261 corresponds to 755 mode of the 'chmod' program
        run(`$installer -b -f -p $PREFIX`)
    end
    @windows_only begin
        run(`$installer /S  /AddToPath=0 /RegisterPython=0 /D=$PREFIX`)
    end
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

"List all installed packages as an dict of tuples with (version_number, fullname)."
function  _installed_packages_dict()
    packages = JSON.parse(readall(`$conda list --json`))
    # As julia do not accepts xx.yy.zz.rr version number the last part is removed.
    # see issue https://github.com/JuliaLang/julia/issues/7282 a maximum of three levels is inserted
    regex = r"^(.*?)-((\d+\.){1,2}\d+)[^-]*-(.*)$"
    package_dict = Dict{UTF8String, Any}()
    for i in 1:length(packages)
        m = match(regex, packages[i])
        if m != nothing
            package_dict[m.captures[1]] = (convert(VersionNumber, m.captures[2]), packages[i])
        else
            error("Failed parsing string: $(packages[i]). Please open an issue!")
        end
    end
    return package_dict
end

"List all installed packages as an array."
_installed_packages() = keys(_installed_packages_dict())

"List all installed packages to standard output."
function list()
    run(`$conda list`)
end

"Get the exact version of a package."
function version(name::AbstractString)
    packages = JSON.parse(readall(`$conda list --json`))
    for package in packages
        if startswith(package, name)
            return package
        end
    end
    error("Could not find the $name package")
end

"Search packages for a string"
function search(package::AbstractString)
    channels = additional_channels()
    return collect(keys(JSON.parse(readall(`$conda search $channels $package --json`))))
end

"Check if a given package exists."
function exists(package::AbstractString)
    if package in search(package)
        # Found exactly this package
        return true
    else
        return false
    end
end

include("bindeps_conda.jl")

end
