VERSION < v"0.7.0-beta2.199" && __precompile__()

"""
The Conda module provides access to the [conda](http://conda.pydata.org/) packages
manager to install binary dependencies of other Julia packages.

The main functions in Conda are:

- `Conda.add(package)`: install a package;
- `Conda.rm(package)`: remove (uninstall) a package;
- `Conda.update()`: update all installed packages to the latest version;
- `Conda.list()`: list all installed packages.
- `Conda.add_channel(channel)`: add a channel to the list of channels;
- `Conda.channels()`: get the current list of channels;
- `Conda.rm_channel(channel)`: remove a channel from the list of channels;
```
"""
module Conda
using Compat, JSON, VersionParsing

const deps_file = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")

if isfile(deps_file)
    # Includes definition for ROOTENV, and MINICONDA_VERSION
    include(deps_file)
else
    error("Conda is not properly configured.  Run Pkg.build(\"Conda\") before importing the Conda module.")
end

const Environment = Union{AbstractString,Symbol}

"Prefix for installation of the environment"
function prefix(name::Symbol)
    sname = string(name)
    if isempty(sname)
        throw(ArgumentError("Environment name should be non empty."))
    end
    return joinpath(ROOTENV, "envs", sname)
end

function prefix(path::AbstractString)
    if !isdir(path)
        throw(ArgumentError("Path to conda environment is not valid: $path"))
    end
    return path
end

const PREFIX = prefix(ROOTENV)

"Prefix for the executable files installed with the packages"
function bin_dir(env::Environment)
    return Compat.Sys.iswindows() ? joinpath(prefix(env), "Library", "bin") : joinpath(prefix(env), "bin")
end
const BINDIR = bin_dir(ROOTENV)

"Prefix for the shared libraries installed with the packages"
function lib_dir(env::Environment)
    return Compat.Sys.iswindows() ? joinpath(prefix(env), "Library", "bin") : joinpath(prefix(env), "lib")
end
const LIBDIR = lib_dir(ROOTENV)

"Prefix for the python scripts. On UNIX, this is the same than Conda.BINDIR"
function script_dir(env::Environment)
    return Compat.Sys.iswindows() ? joinpath(prefix(env), "Scripts") : bin_dir(env)
end
const SCRIPTDIR = script_dir(ROOTENV)

"Prefix where the `python` command lives"
function python_dir(env::Environment)
    return Compat.Sys.iswindows() ? prefix(env) : bin_dir(env)
end
const PYTHONDIR = python_dir(ROOTENV)

# note: the same conda program is used for all environments
const conda = if Compat.Sys.iswindows()
    p = script_dir(ROOTENV)
    conda_bat = joinpath(p, "conda.bat")
    isfile(conda_bat) ? conda_bat : joinpath(p, "conda.exe")
else
    joinpath(bin_dir(ROOTENV), "conda")
end

"Path to the condarc file"
conda_rc(env::Environment) = joinpath(prefix(env), "condarc-julia.yml")
const CONDARC = conda_rc(ROOTENV)

"""
Use a cleaned up environment for the command `cmd`.

Any environment variable starting by CONDA or PYTHON will interact with the run.
"""
function _set_conda_env(cmd, env::Environment=ROOTENV)
    env_var = copy(ENV)
    to_remove = String[]
    for var in keys(env_var)
        if startswith(var, "CONDA") || startswith(var, "PYTHON")
            push!(to_remove, var)
        end
    end
    for var in to_remove
        pop!(env_var, var)
    end
    env_var["PYTHONIOENCODING"]="UTF-8"
    env_var["CONDARC"] = conda_rc(env)
    env_var["CONDA_PREFIX"] = prefix(env)
    setenv(cmd, env_var)
end

"Run conda command with environment variables set."
function runconda(args::Cmd, env::Environment=ROOTENV)
    _install_conda(env)
    Compat.@info("Running $(`conda $args`) in $(env==ROOTENV ? "root" : env) environment")
    run(_set_conda_env(`$conda $args`, env))
    return nothing
end

"Run conda command with environment variables set and return the json output as a julia object"
function parseconda(args::Cmd, env::Environment=ROOTENV)
    _install_conda(env)
    JSON.parse(read(_set_conda_env(`$conda $args --json`, env), String))
end

"Get the miniconda installer URL."
function _installer_url()
    res = "https://repo.continuum.io/miniconda/Miniconda$(MINICONDA_VERSION)-latest-"
    if Compat.Sys.isapple()
        res *= "MacOSX"
    elseif Compat.Sys.islinux()
        res *= "Linux"
    elseif Compat.Sys.iswindows()
        if MINICONDA_VERSION == "3"
            # Quick fix for:
            # * https://github.com/JuliaLang/IJulia.jl/issues/739
            # * https://github.com/ContinuumIO/anaconda-issues/issues/10082
            # * https://github.com/conda/conda/issues/7789
            res = "https://repo.continuum.io/miniconda/Miniconda$(MINICONDA_VERSION)-4.5.4-"
        end
        res *= "Windows"
    else
        error("Unsuported OS.")
    end
    res *= Sys.WORD_SIZE == 64 ? "-x86_64" : "-x86"
    res *= Compat.Sys.iswindows() ? ".exe" : ".sh"
    return res
end

"Suppress progress bar in continuous integration environments"
_quiet() = get(ENV, "CI", "false") == "true" ? `-q` : ``

"Install miniconda if it hasn't been installed yet; _install_conda(true) installs Conda even if it has already been installed."
function _install_conda(env::Environment, force::Bool=false)
    if force || !isfile(Conda.conda)
        Compat.@info("Downloading miniconda installer ...")
        if Compat.Sys.isunix()
            installer = joinpath(PREFIX, "installer.sh")
        end
        if Compat.Sys.iswindows()
            installer = joinpath(PREFIX, "installer.exe")
        end
        download(_installer_url(), installer)

        Compat.@info("Installing miniconda ...")
        if Compat.Sys.isunix()
            chmod(installer, 33261)  # 33261 corresponds to 755 mode of the 'chmod' program
            run(`$installer -b -f -p $PREFIX`)
        end
        if Compat.Sys.iswindows()
            run(Cmd(`$installer /S /AddToPath=0 /RegisterPython=0 /D=$PREFIX`, windows_verbatim=true))
        end
        Conda.add_channel("defaults")
        # Update conda because conda 4.0 is needed and miniconda download installs only 3.9
        runconda(`update $(_quiet()) -y conda`)
    end
    if !isdir(prefix(env))
        runconda(`create $(_quiet()) -y -p $(prefix(env))`)
    end
end

const PkgOrPkgs = Union{AbstractString, AbstractVector{<: AbstractString}}

"Install a new package or packages."
function add(pkg::PkgOrPkgs, env::Environment=ROOTENV)
    runconda(`install $(_quiet()) -y $pkg`, env)
end

"Uninstall a package or packages."
function rm(pkg::PkgOrPkgs, env::Environment=ROOTENV)
    runconda(`remove $(_quiet()) -y $pkg`, env)
end

"Update all installed packages."
function update(env::Environment=ROOTENV)
    if env == ROOTENV
        runconda(`update $(_quiet()) -y --all conda`, env)
    else
        runconda(`update $(_quiet()) -y --all`, env)
    end
end

"List all installed packages as an dict of tuples with (version_number, fullname)."
function  _installed_packages_dict(env::Environment=ROOTENV)
    _install_conda(env)
    package_dict = Dict{String, Tuple{VersionNumber, String}}()
    for line in eachline(_set_conda_env(`$conda list`, env))
        line = chomp(line)
        if !startswith(line, "#")
            name, version, build_string = split(line)
            try
                package_dict[name] = (vparse(version), line)
            catch
                package_dict[name] = (v"9999.9999.9999", line)
                warn("Failed parsing string: \"$(version)\" to a version number. Please open an issue!")
            end
        end
    end
    return package_dict
end

"List all installed packages as an array."
_installed_packages(env::Environment=ROOTENV) = keys(_installed_packages_dict(env))

"List all installed packages to standard output."
function list(env::Environment=ROOTENV)
    runconda(`list`, env)
end

"Get the exact version of a package as a `VersionNumber`."
function version(name::AbstractString, env::Environment=ROOTENV)
    packages = parseconda(`list`, env)
    for package in packages
        pname = get(package, "name", "")
        startswith(pname, name) && return vparse(package["version"])
    end
    error("Could not find the $name package")
end

"Search packages for a string"
function search(package::AbstractString, env::Environment=ROOTENV)
    return collect(keys(parseconda(`search $package`, env)))
end

"Search a specific version of a package"
function search(package::AbstractString, _ver::Union{AbstractString,VersionNumber}, env::Environment=ROOTENV)
    ret=parseconda(`search $package`, env)
    out = String[]
    ver = string(_ver)
    verv = vparse(ver)
    for k in keys(ret)
      for i in 1:length(ret[k])
        kver = ret[k][i]["version"]
        (kver==ver || vparse(kver)==verv) && push!(out,k)
      end
    end
    out
end

"Check if a given package exists."
function exists(package::AbstractString, env::Environment=ROOTENV)
    if occursin("==", package)
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
function channels(env::Environment=ROOTENV)
    ret=parseconda(`config --get channels`, env)
    if haskey(ret["get"], "channels")
        return collect(String, ret["get"]["channels"])
    else
        return String[]
    end
end

"Add a channel to the list of channels"
function add_channel(channel::AbstractString, env::Environment=ROOTENV)
    runconda(`config --add channels $channel --force`, env)
end

"Remove a channel from the list of channels"
function rm_channel(channel::AbstractString, env::Environment=ROOTENV)
    runconda(`config --remove channels $channel --force`, env)
end

"Cleanup all unused packages and caches"
function cleanall(; debug=false)
    clean(; debug=debug, index=true, locks=true, tarballs=true, packages=true, sources=true)
end

"""
    clean(;
        debug=false, index=false, locks=false, tarballs=false, packages=false, sources=false
    )

Runs `conda clean -y` with the specified flags. If
"""
function clean(;
    debug=false, index=false, locks=false, tarballs=false, packages=false, sources=false
)
    kwargs = [debug, index, locks, tarballs, packages, sources]
    if !any(kwargs[2:end])
        @warn(
            "Please specify 1 or more of the conda artifacts to cleanup " *
            "(e.g., `packages=true`)"
        )
    end

    flags = [
        "--debug",
        "--index-cache",
        "--lock",
        "--tarballs",
        "--packages",
        "--source-cache",
    ]
    cmd = Cmd([conda, "clean", "--yes", flags[kwargs]...])
    run(_set_conda_env(cmd))
end

end
