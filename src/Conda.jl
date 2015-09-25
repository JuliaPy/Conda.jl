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

@unix_only begin
    const BINDIR = joinpath(PREFIX, "bin")
    const SCRIPTDIR = joinpath(PREFIX, "bin")
end
@windows_only begin
    const BINDIR = joinpath(PREFIX, "Library", "bin")
    const SCRIPTDIR = joinpath(PREFIX, "Scripts")
end

"Prefix for the python scripts. On UNIX, this is the same than Conda.BINDIR"
SCRIPTDIR
"Prefix for the executable files installed with the packages"
BINDIR

"Returns the directory for python"
@windows_only const PYTHONDIR = PREFIX
"Returns the directory for python"
@unix_only const PYTHONDIR = BINDIR

const conda = joinpath(SCRIPTDIR, "conda")

CHANNELS = AbstractString[]
function additional_channels()
    res = AbstractString[]
    for channel in CHANNELS
        push!(res, "--channel")
        push!(res, channel)
    end
    return res
end


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

"Install miniconda if it hasn't been installed yet; _install_conda(true) installs Conda even if it has already been installed."
function _install_conda(force=false)
    if force || !(@windows? isfile(Conda.conda * ".exe") : isexecutable(Conda.conda))
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
end

"Install a new package."
function add(pkg::AbstractString)
    _install_conda()
    channels = additional_channels()
    run(`$conda install -y $channels $pkg`)
end

"Uninstall a package."
function rm(pkg::AbstractString)
    _install_conda()
    run(`$conda remove -y $pkg`)
end

"Update all installed packages."
function update()
    # _install_conda() # run by _installed_packages()
    channels = additional_channels()
    for package in _installed_packages()
        run(`$conda update $channels -y $package`)
    end
end

"List all installed packages as an dict of tuples with (version_number, fullname)."
function  _installed_packages_dict()
    _install_conda()
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
    _install_conda()
    run(`$conda list`)
end

"Get the exact version of a package."
function version(name::AbstractString)
    _install_conda()
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
    _install_conda()
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
