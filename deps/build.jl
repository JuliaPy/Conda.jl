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
        const ROOTENV = joinpath(Main.condadir, MINICONDA_VERSION)
    end

    USE_MINIFORGE_DEFAULT = true
    if Sys.ARCH in [:x86, :i686]:
        USE_MINIFORGE_DEFAULT = false
        @warn """The free/open-source Miniforge (i.e. the conda-forge channel) does not support this platform.
Using the Anaconda/defaults channel instead, which is free for non-commercial use but otherwise may require a license.
        """
    end
    if !isdefined(@__MODULE__, :USE_MINIFORGE)
        const USE_MINIFORGE = USE_MINIFORGE_DEFAULT
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
However, a root enviroment already exists at $(ROOTENV).
Setting Miniconda version is not supported for existing root enviroments.
To leave Miniconda version as, it is unset the CONDA_JL_VERSION enviroment variable and rebuild.
To change Miniconda version, you must delete the root enviroment and rebuild.
WARNING: deleting the root enviroment will delete all the packages in it.
This will break many Julia packages that have used Conda to install their dependancies.
These will require rebuilding.
""")
end

deps = """
const ROOTENV = "$(escape_string(ROOTENV))"
const MINICONDA_VERSION = "$(escape_string(MINICONDA_VERSION))"
const USE_MINIFORGE = $USE_MINIFORGE
"""

mkpath(condadir)
mkpath(ROOTENV)

for depsfile in ("deps.jl", condadeps)
    if !isfile(depsfile) || read(depsfile, String) != deps
        write(depsfile, deps)
    end
end
