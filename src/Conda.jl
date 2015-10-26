VERSION >= v"0.4.0-dev+6521" && __precompile__()

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

"Prefix for the executable files installed with the packages"
const BINDIR = @windows ? joinpath(PREFIX, "Library", "bin") : joinpath(PREFIX, "bin")

"Prefix for the python scripts. On UNIX, this is the same than Conda.BINDIR"
const SCRIPTDIR = @windows ? joinpath(PREFIX, "Scripts") : BINDIR

"Prefix where the `python` command lives"
const PYTHONDIR = @windows ? PREFIX : BINDIR

const conda = joinpath(SCRIPTDIR, "conda")

"""
Use a cleaned up environment for the command `cmd`.

Any environment variable starting by CONDA will interact with the run.
"""
function _set_conda_env(cmd)
    env = copy(ENV)
    to_remove = AbstractString[]
    for var in keys(env)
        if startswith(var, "CONDA")
            push!(to_remove, var)
        end
    end
    for var in to_remove
        pop!(env, var)
    end
    setenv(cmd, env)
end

const CHANNELS = UTF8String[]
"Get the list of additional channels"
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
            # Remove the error condition when https://github.com/JuliaLang/julia/issues/13776 is fixed and the change implemented.
            match(r" {2,}", "")!=nothing && error("The installer will fail when the path=\"$PREFIX\" contains two consecutive spaces")
            run(`$installer /S /AddToPath=0 /RegisterPython=0 $(split("/D=$PREFIX"))`)
        end
    end
end

"Install a new package."
function add(pkg::AbstractString)
    _install_conda()
    channels = additional_channels()
    run(_set_conda_env(`$conda install -y $channels $pkg`))
end

"Uninstall a package."
function rm(pkg::AbstractString)
    _install_conda()
    run(_set_conda_env(`$conda remove -y $pkg`))
end

"Update all installed packages."
function update()
    # _install_conda() # run by _installed_packages()
    channels = additional_channels()
    for package in _installed_packages()
        run(_set_conda_env(`$conda update $channels -y $package`))
    end
end

"List all installed packages as an dict of tuples with (version_number, fullname)."
function  _installed_packages_dict()
    _install_conda()
    packages = JSON.parse(readall(_set_conda_env(`$conda list --json`)))
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
    run(_set_conda_env(`$conda list`))
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
    return collect(keys(JSON.parse(readall(_set_conda_env(`$conda search $channels $package --json`)))))
end

"Search a specific version of a package"
function search(package::AbstractString,ver::AbstractString)
    _install_conda()
    channels = additional_channels()
    ret=JSON.parse(readall(_set_conda_env(`$conda search $channels $package --json`)))
    out=ASCIIString[]
    for k in keys(ret)
      for i in 1:length(ret[k])
        ret[k][i]["version"]==ver && push!(out,k)
      end
    end
    out
end

"Check if a given package exists."
function exists(package::AbstractString)
    if contains(package,"==")
      pkg,ver=split(package,"==") #Remove version if provided
      return pkg in search(pkg,ver)
    else
      if package in search(package)
        # Found exactly this package
        return true
      else
        return false
      end
    end
end

include("bindeps_conda.jl")

end
