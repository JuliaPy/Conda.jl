__precompile__()

"""
The Conda module provides access to the [conda](http://conda.pydata.org/) packages
manager. Its main purpose is to be used as a BinDeps provider, to install binary
dependencies of other Julia packages.

The main functions in Conda are:

- `Conda.add(package)`: install a package;
- `Conda.rm(package)`: remove (uninstall) a package;
- `Conda.update()`: update all installed packages to the latest version;
- `Conda.list()`: list all installed packages.
- `Conda.add_channel(channel)`: add a channel to the list of channels;
- `Conda.channels()`: get the current list of channels;
- `Conda.rm_channel(channel)`: remove a channel from the list of channels;

To use Conda as a binary provider for BinDeps, the `Conda.Manager` type is proposed. A
small example looks like this:

```julia
# Declare dependency
using BinDeps
@BinDeps.setup
netcdf = library_dependency("netcdf", aliases = ["libnetcdf","libnetcdf4"])

using Conda
#  Use alternative conda channel.
Conda.add_channel("my_channel")
provides(Conda.Manager, "libnetcdf", netcdf)
```
"""
module Conda
using Compat
import Compat.String
using JSON
include("../deps/deps.jl")

if !isdir(default_dir)
    # Ensure default_dir exists
    mkpath(default_dir)
end

type Environment
    path::ASCIIString
    function Environment(path::ASCIIString)
        if (!isdir(path))
            return error("Path to conda environment is not valid.")
        end
        return new(path)
    end
    function Environment(name::Symbol)
        if (length(string(name)) == 0)
            return error("Environment name should be non empty.")
        end
        return new(joinpath(default_dir, "envs", string(name)))
    end
end

RootEnv = Environment(default_dir)

"Prefix for installation of the environment"
function prefix(env::Environment)
    return env.path
end
const PREFIX = prefix(RootEnv)

"Prefix for the executable files installed with the packages"
function bin_dir(env::Environment)
    return is_windows() ? joinpath(prefix(env), "Library", "bin") : joinpath(prefix(env), "bin")
end
const BINDIR = bin_dir(RootEnv)

"Prefix for the python scripts. On UNIX, this is the same than Conda.BINDIR"
function scriptdir(env::Environment)
    return is_windows() ? joinpath(prefix(env), "Scripts") : bin_dir(env)
end
const SCRIPTDIR = scriptdir(RootEnv)

"Prefix where the `python` command lives"
function pythondir(env::Environment)
    return is_windows() ? prefix(env) : bin_dir(env)
end
const PYTHONDIR = pythondir(RootEnv)

conda_bin(env::Environment) = joinpath(scriptdir(env), "conda")
const conda = conda_bin(RootEnv)

"Path to the condarc file"
const CONDARC = joinpath(prefix(RootEnv), "condarc-julia")


"""
Use a cleaned up environment for the command `cmd`.

Any environment variable starting by CONDA will interact with the run.
"""
function _set_conda_env(cmd, env::Environment=RootEnv)
    env_hash = copy(ENV)
    to_remove = AbstractString[]
    for var in keys(env_hash)
        if startswith(var, "CONDA")
            push!(to_remove, var)
        end
    end
    for var in to_remove
        pop!(env_hash, var)
    end
    join_char = is_windows() ? ";" : ":"
    env_hash["CONDARC"] = CONDARC
    env_hash["PATH"] = scriptdir(env) * join_char * env_hash["PATH"]
    env_hash["CONDA_PREFIX"] = prefix(env)
    env_hash["CONDA_DEFAULT_ENV"] = prefix(env)
    setenv(cmd, env_hash)
end

"Get the miniconda installer URL."
function _installer_url()
    res = "http://repo.continuum.io/miniconda/Miniconda-latest-"
    if is_apple()
        res *= "MacOSX"
    elseif is_linux()
        res *= "Linux"
    elseif is_windows()
        res *= "Windows"
    else
        error("Unsuported OS.")
    end
    res *= Sys.WORD_SIZE == 64 ? "-x86_64" : "-x86"
    res *= is_windows() ? ".exe" : ".sh"
    return res
end

is_windows() && include("outlook.jl")

"Install miniconda if it hasn't been installed yet; _install_conda(true) installs Conda even if it has already been installed."
function _install_conda(force::Bool=false, env::Environment=RootEnv)
    if is_windows()
          if is_outlook_running()
              error("""\n
              Outlook is running, and running the Miniconda installer will crash it.
              Please quit Outlook and then restart the installation.

              For more information, see:
                    https://github.com/Luthaf/Conda.jl/issues/15
                    https://github.com/conda/conda/issues/1084
              """)
          end
    end

    if force || !(is_windows() ? isfile(Conda.conda * ".exe") : isfile(Conda.conda))
        info("Downloading miniconda installer ...")
        if is_unix()
            installer = joinpath(PREFIX, "installer.sh")
        end
        if is_windows()
            installer = joinpath(PREFIX, "installer.exe")
        end
        download(_installer_url(), installer)

        info("Installing miniconda ...")
        if is_unix()
            chmod(installer, 33261)  # 33261 corresponds to 755 mode of the 'chmod' program
            run(`$installer -b -f -p $PREFIX`)
        end
        if is_windows()
            if VERSION >= v"0.5.0-dev+8873" # Julia PR #13780
                run(Cmd(`$installer /S /AddToPath=0 /RegisterPython=0 /D=$PREFIX`, windows_verbatim=true))
            else
                # Workaround a bug in command-line argument parsing, see
                # https://github.com/Luthaf/Conda.jl/issues/17
                if match(r" {2,}", "") != nothing
                    error("The installer will fail when the path=\"$PREFIX\" contains two consecutive spaces")
                end
                run(`$installer /S /AddToPath=0 /RegisterPython=0 $(split("/D=$PREFIX"))`)
            end
        end
        Conda.add_channel("defaults")
    end
    if !isdir(prefix(env))
        # conda doesn't allow totally empty environments. using zlib as the default package
        run(_set_conda_env(`conda create -p $(prefix(env)) zlib`, RootEnv))
    end
end

"Install a new package."
function add(pkg::AbstractString, env::Environment=RootEnv)
    _install_conda(false, env)
    run(_set_conda_env(`conda install -y $pkg`, env))
end

"Uninstall a package."
function rm(pkg::AbstractString, env::Environment=RootEnv)
    _install_conda(false, env)
    run(_set_conda_env(`conda remove -y $pkg`, env))
end

"Update all installed packages."
function update(env::Environment=RootEnv)
    _install_conda(false, env)
    for package in _installed_packages()
        run(_set_conda_env(`conda update -y $package`, env))
    end
end

"List all installed packages as an dict of tuples with (version_number, fullname)."
function  _installed_packages_dict(env::Environment=RootEnv)
    _install_conda(false, env)
    package_dict = Dict{Compat.UTF8String, Tuple{VersionNumber, Compat.UTF8String}}()
    for line in eachline(_set_conda_env(`conda list --export`, env))
        line = chomp(line)
        if !startswith(line, "#")
            name, version, build_string = split(line, "=")
            # As julia do not accepts xx.yy.zz.rr version number the last part is removed.
            # see issue https://github.com/JuliaLang/julia/issues/7282 a maximum of three levels is inserted
            version_number = join(split(version,".")[1:min(3,end)],".")
            try
                package_dict[name] = (convert(VersionNumber, version_number), line)
            catch
                package_dict[name] = (v"9999.9999.9999", line)
                warn("Failed parsing string: \"$(version_number)\" to a version number. Please open an issue!")
            end
        end
    end
    return package_dict
end

"List all installed packages as an array."
_installed_packages(env::Environment=RootEnv) = keys(_installed_packages_dict(env))

"List all installed packages to standard output."
function list(env::Environment=RootEnv)
    _install_conda(false, env)
    run(_set_conda_env(`conda list`, env))
end

"Get the exact version of a package."
function version(name::AbstractString, env::Environment=RootEnv)
    _install_conda(false, env)
    packages = JSON.parse(readstring(_set_conda_env(`conda list --json`, env)))
    for package in packages
        if startswith(package, name) || ismatch(Regex("::$name"), package)
            return package
        end
    end
    error("Could not find the $name package")
end

"Search packages for a string"
function search(package::AbstractString, env::Environment=RootEnv)
    _install_conda(false, env)
    return collect(keys(JSON.parse(readstring(_set_conda_env(`conda search $package --json`, env)))))
end

"Search a specific version of a package"
function search(package::AbstractString, ver::AbstractString, env::Environment=RootEnv)
    _install_conda(false, env)
    ret=JSON.parse(readstring(_set_conda_env(`conda search $package --json`, env)))
    out = Compat.ASCIIString[]
    for k in keys(ret)
      for i in 1:length(ret[k])
        ret[k][i]["version"]==ver && push!(out,k)
      end
    end
    out
end

"Check if a given package exists."
function exists(package::AbstractString, env::Environment=RootEnv)
    if contains(package,"==")
      pkg,ver=split(package,"==")  # Remove version if provided
      return pkg in search(pkg,ver,env)
    else
      if package in search(package,env)
        # Found exactly this package
        return true
      else
        return false
      end
    end
end

"Get the list of channels used to search packages"
function channels(env::Environment=RootEnv)
    _install_conda(false, env)
    ret=JSON.parse(readstring(_set_conda_env(`conda config --get channels --json`, env)))
    if haskey(ret["get"], "channels")
        return collect(Compat.ASCIIString, ret["get"]["channels"])
    else
        return Compat.ASCIIString[]
    end
end

"Add a channel to the list of channels"
function add_channel(channel::Compat.String, env::Environment=RootEnv)
    _install_conda(false, env)
    run(_set_conda_env(`conda config --add channels $channel --force`, env))
end

"Remove a channel from the list of channels"
function rm_channel(channel::Compat.String, env::Environment=RootEnv)
    _install_conda(false, env)
    run(_set_conda_env(`conda config --remove channels $channel --force`, env))
end

include("bindeps_conda.jl")

end
