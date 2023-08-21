const condadir = abspath(first(DEPOT_PATH), "conda")
const condadeps = joinpath(condadir, "deps.jl")

module DefaultDeps
    if isfile("deps.jl")
        include("deps.jl")
    elseif isfile(Main.condadeps)
        include(Main.condadeps)
    end
    if !isdefined(@__MODULE__, :MINICONDA_VERSION)
        const MINICONDA_VERSION = "3"
    end
    if !isdefined(@__MODULE__, :ROOTENV)
        const ROOTENV = joinpath(Main.condadir, MINICONDA_VERSION, string(Sys.ARCH))
    end

    USE_MINIFORGE_DEFAULT = true
    if Sys.ARCH in [:x86, :i686]
        USE_MINIFORGE_DEFAULT = false
        @warn """The free/open-source Miniforge (i.e. the conda-forge channel) does not support this platform.
Using the Anaconda/defaults channel instead, which is free for non-commercial use but otherwise may require a license.
        """
    end
    if !isdefined(@__MODULE__, :USE_MINIFORGE)
        const USE_MINIFORGE = USE_MINIFORGE_DEFAULT
    end
    function default_conda_exe(ROOTENV)
        @static if Sys.iswindows()
            p = joinpath(ROOTENV, "Scripts")
            conda_bat = joinpath(p, "conda.bat")
            isfile(conda_bat) ? conda_bat : joinpath(p, "conda.exe")
        else
            joinpath(ROOTENV, "bin", "conda")
        end
    end

    if !isdefined(@__MODULE__, :CONDA_EXE)
        const CONDA_EXE = default_conda_exe(ROOTENV)
    end
end

MINICONDA_VERSION = get(ENV, "CONDA_JL_VERSION", DefaultDeps.MINICONDA_VERSION)
ROOTENV = get(ENV, "CONDA_JL_HOME") do
    root = DefaultDeps.ROOTENV

    # Ensure the ROOTENV uses the current MINICONDA_VERSION when not using a custom ROOTENV
    if normpath(dirname(root)) == normpath(condadir) && all(isdigit, basename(root))
        joinpath(condadir, MINICONDA_VERSION)
    else
        root
    end
end

USE_MINIFORGE = lowercase(get(ENV, "CONDA_JL_USE_MINIFORGE", DefaultDeps.USE_MINIFORGE ? "1" : "0")) in ("1","true","yes")

if isdir(ROOTENV) && MINICONDA_VERSION != DefaultDeps.MINICONDA_VERSION
    error("""Miniconda version changed, since last build.
However, a root environment already exists at $(ROOTENV).
Setting Miniconda version is not supported for existing root environments.
To leave Miniconda version as, it is unset the CONDA_JL_VERSION environment variable and rebuild.
To change Miniconda version, you must delete the root environment and rebuild.
WARNING: deleting the root environment will delete all the packages in it.
This will break many Julia packages that have used Conda to install their dependancies.
These will require rebuilding.
""")
end

CONDA_EXE = get(ENV, "CONDA_JL_CONDA_EXE") do
    if ROOTENV == DefaultDeps.ROOTENV
        DefaultDeps.CONDA_EXE
    else
        DefaultDeps.default_conda_exe(ROOTENV)
    end
end

if haskey(ENV, "CONDA_JL_CONDA_EXE")
    # Check to see if CONDA_EXE is an executable file
    if isfile(CONDA_EXE)
        if Sys.isexecutable(CONDA_EXE)
            @info "Executable conda located." CONDA_EXE
        else
            error("CONDA_JL_CONDA_EXE, $CONDA_EXE, cannot be executed by the current user.")
        end
    else
        error("CONDA_JL_CONDA_EXE, $CONDA_EXE, does not exist.")
    end
else
    if !isfile(CONDA_EXE)
        # An old CONDA_EXE has gone missing, revert to default in ROOTENV
        @info "CONDA_EXE not found. Reverting to default in ROOTENV" CONDA_EXE ROOTENV
        CONDA_EXE = DefaultDeps.default_conda_exe(ROOTENV)
    end
end


deps = """
const ROOTENV = "$(escape_string(ROOTENV))"
const MINICONDA_VERSION = "$(escape_string(MINICONDA_VERSION))"
const USE_MINIFORGE = $USE_MINIFORGE
const CONDA_EXE = "$(escape_string(CONDA_EXE))"
"""

mkpath(condadir)
mkpath(ROOTENV)

for depsfile in ("deps.jl", condadeps)
    if !isfile(depsfile) || read(depsfile, String) != deps
        write(depsfile, deps)
    end
end
