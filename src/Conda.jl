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
using JSON, VersionParsing
import Downloads

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
    return Sys.iswindows() ? joinpath(prefix(env), "Library", "bin") : joinpath(prefix(env), "bin")
end
const BINDIR = bin_dir(ROOTENV)

"Prefix for the shared libraries installed with the packages"
function lib_dir(env::Environment)
    return Sys.iswindows() ? joinpath(prefix(env), "Library", "bin") : joinpath(prefix(env), "lib")
end
const LIBDIR = lib_dir(ROOTENV)

"Prefix for the python scripts. On UNIX, this is the same than Conda.BINDIR"
function script_dir(env::Environment)
    return Sys.iswindows() ? joinpath(prefix(env), "Scripts") : bin_dir(env)
end
const SCRIPTDIR = script_dir(ROOTENV)

"Prefix where the `python` command lives"
function python_dir(env::Environment)
    return Sys.iswindows() ? prefix(env) : bin_dir(env)
end
const PYTHONDIR = python_dir(ROOTENV)

if ! @isdefined(CONDA_EXE)
    # We have an oudated deps.jl file that does not define CONDA_EXE
    error("CONDA_EXE not defined in $deps_file.\nPlease rebuild Conda.jl via `using Pkg; pkg\"build Conda\";`")
end
# note: the same conda program is used for all environments
const conda = CONDA_EXE

"Path to the condarc file"
function conda_rc(env::Environment)
    #=
    sys_condarc is looked at by conda for almost operations
    except when adding channels with --file argument.
    we copy it to env_condarc avoid this conda bug
    =#
    env_condarc = joinpath(prefix(env), "condarc-julia.yml")
    sys_condarc = joinpath(prefix(ROOTENV), ".condarc")
    if isdir(prefix(env)) && !isfile(env_condarc) && isfile(sys_condarc)
        cp(sys_condarc, env_condarc)
    end
    return env_condarc
end

const CONDARC = conda_rc(ROOTENV)

"""
Get a cleaned up environment

Any environment variable starting by CONDA or PYTHON will interact with the run.
"""
function _get_conda_env(env::Environment=ROOTENV)
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
    if Sys.iswindows()
        env_var["PATH"] = bin_dir(env) * ';' * get(env_var, "PATH", "")
    end
    env_var
end

_set_conda_env(cmd, env::Environment=ROOTENV) = setenv(cmd, _get_conda_env(env))

"Run conda command with environment variables set."
function runconda(args::Cmd, env::Environment=ROOTENV)
    _install_conda(env)
    @info("Running $(`conda $args`) in $(env==ROOTENV ? "root" : env) environment")
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
    if Sys.isapple()
        conda_os = "MacOSX"
    elseif Sys.islinux()
        conda_os = "Linux"
    elseif Sys.iswindows()
        conda_os = "Windows"
    else
        error("Unsuported OS.")
    end

    # mapping of Julia architecture names to Conda architecture names, where they differ
    arch2conda = Dict(:i686 => :x86, :powerpc64le => :ppc64le)

    if Sys.isapple()
        arch2conda[:aarch64] = :arm64
    end

    conda_platform = string(conda_os, '-', get(arch2conda, Sys.ARCH, Sys.ARCH))

    MINIFORGE_PLATFORMS = ["Linux-aarch64", "Linux-x86_64", "Linux-ppc64le",
                           "MacOSX-arm64", "MacOSX-x86_64",
                           "Windows-x86_64"]
    MINICONDA_PLATFORMS = ["Linux-aarch64", "Linux-x86_64", "Linux-ppc64le",
                           "Linux-x86", "Linux-s390x",
                           "MacOSX-arm64", "MacOSX-x86_64", "MacOSX-x86",
                           "Windows-x86", "Windows-x86_64"]

    if USE_MINIFORGE
        if !(conda_platform in MINIFORGE_PLATFORMS)
            error("Unsupported miniforge platform: $(conda_platform)")
        else
            res = "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-"
        end
    else
        if !(conda_platform in MINICONDA_PLATFORMS)
            error("Unsupported miniconda platform: $(conda_platform)")
        else
            res = "https://repo.continuum.io/miniconda/Miniconda$(MINICONDA_VERSION)-latest-"
        end
    end

    res *= conda_platform
    res *= Sys.iswindows() ? ".exe" : ".sh"
    return res
end

"Suppress progress bar in continuous integration environments"
_quiet() = get(ENV, "CI", "false") == "true" ? `-q` : ``

"Install miniconda if it hasn't been installed yet; _install_conda(true) installs Conda even if it has already been installed."
function _install_conda(env::Environment, force::Bool=false)
    if force || !isfile(Conda.conda)
        @assert startswith(abspath(Conda.conda), abspath(PREFIX)) "CONDA_EXE, $(conda), does not exist within $PREFIX"
        @info("Downloading miniconda installer ...")
        INSTALLER_DIR = tempdir()
        if Sys.isunix()
            installer = joinpath(INSTALLER_DIR, "installer.sh")
        end
        if Sys.iswindows()
            installer = joinpath(INSTALLER_DIR, "installer.exe")
        end
        mkpath(INSTALLER_DIR)
        Downloads.download(_installer_url(), installer)

        @info("Installing miniconda ...")
        mkpath(PREFIX)
        if Sys.isunix()
            chmod(installer, 33261)  # 33261 corresponds to 755 mode of the 'chmod' program
            run(`$installer -b -f -p $PREFIX`)
        end
        if Sys.iswindows()
            run(Cmd(`$installer /S --no-shortcuts /NoRegistry=1 /AddToPath=0 /RegisterPython=0 /D=$PREFIX`, windows_verbatim=true))
        end
    end
    if !isdir(prefix(env))
        create(env)
    end
end

const PkgOrPkgs = Union{AbstractString, AbstractVector{<: AbstractString}}

"Install a new package or packages."
function add(pkg::PkgOrPkgs, env::Environment=ROOTENV;
             channel::AbstractString="",
             satisfied_skip_solve::Bool = false,
             args::Cmd = ``,
            )
    c = isempty(channel) ? `` : `-c $channel`
    S = satisfied_skip_solve ? `--satisfied-skip-solve` : ``
    runconda(`install $(_quiet()) -y $c $S $args $pkg`, env)
end

"Uninstall a package or packages."
function rm(pkg::PkgOrPkgs, env::Environment=ROOTENV)
    runconda(`remove $(_quiet()) -y $pkg`, env)
end

function create(env::Environment)
    runconda(`create $(_quiet()) -y -p $(prefix(env))`)
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

"""
    export_list(filepath, env=$ROOTENV)
    export_list(io, env=$ROOTENV)

List all packages and write them to an export file for use the Conda.import_list
"""
function export_list(filepath::AbstractString, env::Environment=ROOTENV)
    _install_conda(env)
    open(filepath, "w") do fobj
        export_list(fobj, env)
    end
end

function export_list(io::IO, env::Environment=ROOTENV)
    write(io, read(_set_conda_env(`$conda list --export`, env)))
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
    ret=parseconda(`config --get channels --file $(conda_rc(env))`, env)
    if haskey(ret["get"], "channels")
        return collect(String, ret["get"]["channels"])
    else
        return String[]
    end
end

"Add a channel to the list of channels"
function add_channel(channel::AbstractString, env::Environment=ROOTENV)
    runconda(`config --add channels $channel --file $(conda_rc(env)) --force`, env)
end

"Remove a channel from the list of channels"
function rm_channel(channel::AbstractString, env::Environment=ROOTENV)
    runconda(`config --remove channels $channel --file $(conda_rc(env)) --force`, env)
end

"""
    clean(;
        debug=false, index=true, locks=false, tarballs=true, packages=true, sources=false
    )

Runs `conda clean -y` with the specified flags.
"""
function clean(;
    debug=false, index=true, locks=false, tarballs=true, packages=true, sources=false
)
    kwargs = [debug, index, locks, tarballs, packages, sources]
    if !any(kwargs[2:end])
        @warn(
            "Please specify 1 or more of the conda artifacts to clean up (e.g., `packages=true`)."
        )
    end
    if locks
        @warn "clean --lock is no longer supported in Anaconda 4.8.0"
    end
    if sources
        @warn "clean --source-cache is no longer supported"
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

""""
    import_list(filename, env=$ROOTENV, channels=String[])
    import_list(io, env=$ROOTENV, channels=String[])

Create a new environment with various channels and a packages list file.
"""
function import_list(
    filepath::AbstractString,
    env::Environment=ROOTENV;
    channels=String[]
)
    channel_str = ["-c=$channel" for channel in channels]
    run(_set_conda_env(
                       `$conda create $(_quiet()) -y -p $(prefix(env)) $(Cmd(channel_str)) --file $filepath`,
        env
    ))
    # persist the channels given for this environment
    for channel in reverse(channels)
        add_channel(channel, env)
    end
end

function import_list(io::IO, args...; kwargs...)
    mktemp() do path, fobj
        write(fobj, read(io))
        close(fobj)
        import_list(path, args...; kwargs...)
    end
end

"""
    pip_interop(bool::Bool, env::Environment=$ROOTENV)

Sets the `pip_interop_enabled` value to bool.
If `true` then the conda solver is allowed to interact with non-conda-installed python packages.
"""
function pip_interop(bool::Bool, env::Environment=ROOTENV)
    runconda(`config --set pip_interop_enabled $bool --file $(conda_rc(env))`, env)
end

"""
    pip_interop(env::Environment=$ROOTENV)

Gets the `pip_interop_enabled` value from the conda config.
"""
function pip_interop(env::Environment=ROOTENV)
    dict = parseconda(`config --get pip_interop_enabled --file $(conda_rc(env))`, env)["get"]
    get(dict, "pip_interop_enabled", false)
end

function check_pip_interop(env::Environment=ROOTENV)
    pip_interop(env) || error("""
                              pip_interop is not enabled
                              Use `Conda.pip_interop(true; [env::Environment=ROOTENV])` to enable
                              """)
end

_pip() = Sys.iswindows() ? "pip.exe" : "pip"

"pip command to use for specified environment"
function _pip(env::Environment)
    "pip" ∉ _installed_packages(env) && add("pip", env)
    joinpath(script_dir(env), _pip())
end

function pip(cmd::AbstractString, pkgs::PkgOrPkgs, env::Environment=ROOTENV)
    check_pip_interop(env)
    # parse the pip command
    _cmd = String[split(cmd, " ")...]
    @info("Running $(`pip $_cmd $pkgs`) in $(env==ROOTENV ? "root" : env) environment")
    run(_set_conda_env(`$(_pip(env)) $_cmd $pkgs`, env))
    nothing
end

end
