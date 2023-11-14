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

"""
    prefix(name::Symbol)

Prefix for installation of the environment `name`.
"""
function prefix(name::Symbol)
    sname = string(name)
    if isempty(sname)
        throw(ArgumentError("Environment name should be non empty."))
    end
    return joinpath(ROOTENV, "envs", sname)
end

"""
    prefix(path::String)

Checks that `path` is a valid directory for a Conda environment, and
returns `path`.
"""
function prefix(path::AbstractString)
    if !isdir(path)
        throw(ArgumentError("Path to conda environment is not valid: $path"))
    end
    return path
end

const PREFIX = prefix(ROOTENV)

"""
    bin_dir(env::Union{AbstractString,Symbol})

Directory for the executable files installed with the packages for
the environment named `env`.
"""
function bin_dir(env::Environment)
    return Sys.iswindows() ? joinpath(prefix(env), "Library", "bin") : joinpath(prefix(env), "bin")
end
const BINDIR = bin_dir(ROOTENV)

"""
    lib_dir(env::Union{AbstractString,Symbol})

Directory for the shared libraries installed with the packages for
the environment named `env`.   To get this directory for the
default root environment `ROOTENV`, use `LIBDIR`.
"""
function lib_dir(env::Environment)
    return Sys.iswindows() ? joinpath(prefix(env), "Library", "bin") : joinpath(prefix(env), "lib")
end
const LIBDIR = lib_dir(ROOTENV)

"""
    script_dir(env::Union{AbstractString,Symbol})

Directory for the Python scripts installed with the packages for
the environment named `env`.   To get this directory for the
default root environment `ROOTENV`, use `SCRIPTDIR`.
"""
function script_dir(env::Environment)
    return Sys.iswindows() ? joinpath(prefix(env), "Scripts") : bin_dir(env)
end
const SCRIPTDIR = script_dir(ROOTENV)

"""
    python_dir(env::Union{AbstractString,Symbol})

Directory where the `python` command lives for
the environment named `env`.   To get this directory for the
default root environment `ROOTENV`, use `PYTHONDIR`.
"""
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

"""
    conda_rc(env::Union{AbstractString,Symbol}=ROOTENV)

Path of the condarc file for the environment named `env`,
defaulting to `ROOTENV`.
"""
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
    _get_conda_env(env::Union{AbstractString,Symbol}=ROOTENV)

Get a sanitized copy of the environment [`ENV`](@ref) for the
Conda environment named `env` (defaulting to `ROOTENV`),
in order to run the `conda` program.

In particular, this removes any environment
variable whose named begins with `CONDA` or `PYTHON`, which might
cause `conda` to have unexpected behaviors.
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

"""
    runconda(args::Cmd, env::Union{AbstractString,Symbol}=ROOTENV)

Run the `conda` program with the given arguments `args`, i.e.
run `conda \$args`, in the given environment `env` (defaulting to `ROOTENV`).

(Installs `conda` if necessary, and sanitizes the runtime environment using
`_get_conda_env`.)

Run conda command with environment variables set.
"""
function runconda(args::Cmd, env::Environment=ROOTENV)
    _install_conda(env)
    @info("Running $(`conda $args`) in $(env==ROOTENV ? "root" : env) environment")
    run(_set_conda_env(`$conda $args`, env))
    return nothing
end

"""
    parseconda(args::Cmd, env::Union{AbstractString,Symbol}=ROOTENV)

Run the `conda` program with the given arguments `args`, i.e.
run `conda --json \$args`, in the given environment `env` (defaulting to `ROOTENV`),
parsing resulting JSON output and returning a Julia dictionary of the contents.

(Installs `conda` if necessary, and sanitizes the runtime environment using
`_get_conda_env`.)
"""

"Run conda command with environment variables set and return the json output as a julia object"
function parseconda(args::Cmd, env::Environment=ROOTENV)
    _install_conda(env)
    JSON.parse(read(_set_conda_env(`$conda $args --json`, env), String))
end

"""
    _installer_url()

Get the miniconda/miniforge installer URL.
"""
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

"""
    _quiet()

Returns `conda` command-line argument to suppress progress bar
in continuous integration (CI) environments.
"""
_quiet() = get(ENV, "CI", "false") == "true" ? `-q` : ``

"""
    _install_conda(env::Union{AbstractString,Symbol}, force::Bool=false)

Install miniconda/miniforge into `env` if it hasn't been installed yet;
`_install_conda(env, true)` re-installs Conda even if it has already been installed.
"""
function _install_conda(env::Environment, force::Bool=false)
    if force || !isfile(Conda.conda)
        @assert startswith(abspath(Conda.conda), abspath(PREFIX)) "CONDA_EXE, $(conda), does not exist within $PREFIX"

        if (' ' ∈ PREFIX) || (Sys.iswindows() && !isascii(PREFIX))
            error("""Conda.jl cannot be installed to its default location $(PREFIX)
as Miniconda does not support the installation to a directory with a space or a
non-ASCII character on Windows. The work-around is to install Miniconda to a
user-writable directory by setting the CONDA_JL_HOME environment variable. For
example on Windows:

ENV["CONDA_JL_HOME"] = raw"C:\\Conda-Julia\\3"
using Pkg
Pkg.build("Conda")

The Julia session need to be restarted. More information is available at
https://github.com/JuliaPy/Conda.jl.
""")
        end

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
        write("$PREFIX/condarc-julia.yml", "auto_update_conda: false")
    end
    if !isdir(prefix(env))
        create(env)
    end
end

const PkgOrPkgs = Union{AbstractString, AbstractVector{<: AbstractString}}

"""
    add(pkg, env::Union{AbstractString,Symbol}=ROOTENV)

Installs new package(s) `pkg` into the conda environment `env`
(defaulting to `ROOTENV`).   `pkg` can be a string giving the name
of a single package, or a vector of strings giving the names of
several packages.
"""
function add(pkg::PkgOrPkgs, env::Environment=ROOTENV;
             channel::AbstractString="",
             satisfied_skip_solve::Bool = false,
             args::Cmd = ``,
            )
    c = isempty(channel) ? `` : `-c $channel`
    @static if Sys.iswindows() && Sys.WORD_SIZE == 32
        if satisfied_skip_solve
            @warn """
            The keyword satisfied_skip_solve was set to true,
            but conda does not support --satisfied-skip-resolve on 32-bit Windows.
            """
        end
        S = ``
    else
        S = satisfied_skip_solve ? `--satisfied-skip-solve` : ``
    end
    runconda(`install $(_quiet()) -y $c $S $args $pkg`, env)
end

"""
    rm(pkg, env::Union{AbstractString,Symbol}=ROOTENV)

Uninstall package(s) `pkg` from the conda environment `env`
(defaulting to `ROOTENV`).   `pkg` can be a string giving the name
of a single package, or a vector of strings giving the names of
several packages.
"""
function rm(pkg::PkgOrPkgs, env::Environment=ROOTENV)
    runconda(`remove $(_quiet()) -y $pkg`, env)
end

"""
    create(env::Union{AbstractString,Symbol})

Create a new conda environment `env` (running `conda create`).
"""
function create(env::Environment)
    runconda(`create $(_quiet()) -y -p $(prefix(env))`)
end

"""
    update(env::Union{AbstractString,Symbol}=ROOTENV)

Update all installed packages for the conda environment `env`
(defaulting to `ROOTENV`).
"""
function update(env::Environment=ROOTENV)
    if env == ROOTENV
        runconda(`update $(_quiet()) -y --all conda`, env)
    else
        runconda(`update $(_quiet()) -y --all`, env)
    end
end

"""
    _installed_packages_dict(env::Union{AbstractString,Symbol}=ROOTENV)

Return a list of all installed packages for the conda environment `env`
(defaulting to `ROOTENV`) as a dictionary mapping package names to
 tuples of `(version_number, fullname)`.
"""
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

"""
    _installed_packages(env::Union{AbstractString,Symbol}=ROOTENV)

Return an array of names of all installed packages for the conda environment `env`
(defaulting to `ROOTENV`).
"""
_installed_packages(env::Environment=ROOTENV) = keys(_installed_packages_dict(env))

"""
    list(env::Union{AbstractString,Symbol}=ROOTENV)

List all installed packages for the conda environment `env`
(defaulting to `ROOTENV`) to standard output (`stdout`).
"""
function list(env::Environment=ROOTENV)
    runconda(`list`, env)
end

"""
    export_list(filepath, env=$ROOTENV)
    export_list(io, env=$ROOTENV)

List all installed packages for the conda environment `env`
(defaulting to `ROOTENV`) and write them to an export `filepath`
or I/O stream `io`, mainly for use the [`import_list`](@ref) function.
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

"""
    version(name::AbstractString, env::Union{AbstractString,Symbol}=ROOTENV)

Return the installed version of the package `name`
(as a [`VersionNumber`](@ref) for the conda environment `env`
(defaulting to `ROOTENV`).
"""
function version(name::AbstractString, env::Environment=ROOTENV)
    packages = parseconda(`list`, env)
    for package in packages
        pname = get(package, "name", "")
        startswith(pname, name) && return vparse(package["version"])
    end
    error("Could not find the $name package")
end

"""
    search(matchspec::AbstractString, env::Union{AbstractString,Symbol}=ROOTENV;
           version::Union{AbstractString,VersionNumber,Nothing}=nothing)

Search the list of available conda packages for the string `matchspec`,
for the conda environment `env` (defaulting to `ROOTENV`), and return
the result as an array of package names.

If the optional keyword `version` is passed, then only packages having a match
for this version number will be returned.
"""
function search(matchspec::AbstractString, env::Environment=ROOTENV;
                version::Union{AbstractString,VersionNumber,Nothing}=nothing)
    ret = parseconda(`search $matchspec`, env)
    if isnothing(version)
        return collect(keys(ret))
    else
        ver = string(version)
        verv = vparse(ver)
        return collect(filter(keys(ret)) do k
            any(ret[k]) do pkg
                kver = pkg["version"]
                kver==ver || vparse(kver)==verv
            end
        end)
    end
end

# old API, has a method ambiguity for `search(package, version)` when
# `version` is a string:
search(package::AbstractString, _ver::AbstractString, env::Environment) =
    search(package, env; version=_ver)
search(package::AbstractString, _ver::VersionNumber, env::Environment=ROOTENV) =
    search(package, env; version=_ver)

"""
    exists(package::AbstractString, env::Union{AbstractString,Symbol}=ROOTENV)

Return whether the given `package` exists for the conda environment `env`
(defaulting to `ROOTENV`).   A particular version may be specified by
passing `"package==version"` as the `package` string.
"""
function exists(package::AbstractString, env::Environment=ROOTENV)
    if occursin("==", package)
      pkg,ver=split(package,"==")  # Remove version if provided
      return pkg in search(pkg,env; version=ver)
    else
      return package in search(package,env)
    end
end

"""
    channels(env::Union{AbstractString,Symbol}=ROOTENV)

Return an array of channels used to search packages in
the conda environment `env` (defaulting to `ROOTENV`).
"""
function channels(env::Environment=ROOTENV)
    ret=parseconda(`config --get channels --file $(conda_rc(env))`, env)
    if haskey(ret["get"], "channels")
        return collect(String, ret["get"]["channels"])
    else
        return String[]
    end
end

"""
    add_channel(channel::AbstractString, env::Union{AbstractString,Symbol}=ROOTENV)

Add `channel` to the list of channels used to search packages in
the conda environment `env` (defaulting to `ROOTENV`).
"""
function add_channel(channel::AbstractString, env::Environment=ROOTENV)
    runconda(`config --add channels $channel --file $(conda_rc(env)) --force`, env)
end

"""
    rm_channel(channel::AbstractString, env::Union{AbstractString,Symbol}=ROOTENV)

Remove `channel` from the list of channels used to search packages in
the conda environment `env` (defaulting to `ROOTENV`).
"""
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
    import_list(filename, env=ROOTENV; channels=String[])
    import_list(io, env=ROOTENV; channels=String[])

Create a new environment `env` (defaulting to `ROOTENV`)
with various channels and a packages list file `filename`
(or I/O stream `io`)
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
    pip_interop(enabled::Bool, env::Union{AbstractString,Symbol}=ROOTENV)

Sets the `pip_interop_enabled` value to `enabled` for
the conda environment `env` (defaulting to `ROOTENV`)

If `enabled==true`, then the conda solver is allowed to
interact with non-conda-installed python packages.
"""
function pip_interop(enabled::Bool, env::Environment=ROOTENV)
    runconda(`config --set pip_interop_enabled $enabled --file $(conda_rc(env))`, env)
end

"""
    pip_interop(env::Union{AbstractString,Symbol}=ROOTENV)

Gets the `pip_interop_enabled` value from the conda config for
the conda environment `env` (defaulting to `ROOTENV`)
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

"""
    _pip(env::Union{AbstractString,Symbol}=ROOTENV)

Return the path of the `pip` command for
the conda environment `env` (defaulting to `ROOTENV`),
installing `pip` if necessary.
"""
function _pip(env::Environment)
    "pip" ∉ _installed_packages(env) && add("pip", env)
    joinpath(script_dir(env), _pip())
end

"""
    pip(cmd::AbstractString, pkg, env::Union{AbstractString,Symbol}=ROOTENV)

Run the `pip` command `cmd` for the package(s) `pkg` in
the conda environment `env` (defaulting to `ROOTENV`).
`pkg` can be a string giving the name of a single package,
or a vector of strings giving the names of several packages.
"""
function pip(cmd::AbstractString, pkgs::PkgOrPkgs, env::Environment=ROOTENV)
    check_pip_interop(env)
    # parse the pip command
    _cmd = String[split(cmd, " ")...]
    @info("Running $(`pip $_cmd $pkgs`) in $(env==ROOTENV ? "root" : env) environment")
    run(_set_conda_env(`$(_pip(env)) $_cmd $pkgs`, env))
    nothing
end

end
