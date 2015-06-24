module Conda
using Compat

const PREFIX = Pkg.dir("Conda", "deps", "usr")
const conda = joinpath(PREFIX, "bin", "conda")
const DL_LOAD_PATH = VERSION >= v"0.4.0-dev+3844" ? Libdl.DL_LOAD_PATH : Base.DL_LOAD_PATH

function __init__()
    # Let's see if Conda is installed.  If not, let's do that first!
    install_conda()
    # Update environment variables such as PATH, DL_LOAD_PATH, etc...
    update_env()
end

# Ignore STDERR
function quiet_run(cmd::Cmd)
    run(cmd, (STDIN, STDOUT, DevNull), false, false)
end

# Ignore STDOUT and STDERR
function really_quiet_run(cmd::Cmd)
    run(cmd, (STDIN, DevNull, DevNull), false, false)
end

function install_conda()
    # Ensure PREFIX exists
    mkpath(PREFIX)

    # Make sure conda isn't already installed
    if !isexecutable(conda)
        # Install
        # TODO
    end
    update()
end

function update()
    run(`$conda install conda`)
end

# Update environment variables so we can natively call conda, etc...
function update_env()
    if length(Base.search(ENV["PATH"], joinpath(PREFIX, "bin"))) == 0
        ENV["PATH"] = "$(realpath(joinpath(PREFIX, "bin"))):$(joinpath(PREFIX, "sbin")):$(ENV["PATH"])"
    end
    if !(joinpath(PREFIX, "lib") in DL_LOAD_PATH)
        push!(DL_LOAD_PATH, joinpath(PREFIX, "lib") )
    end
end

immutable CondaPkg
    name::ASCIIString
    version::VersionNumber
    version_str::ASCIIString
    CondaPkg(n, v, vs) = new(n, v, vs)
end

function show(io::IO, b::CondaPkg)
    write(io, "$(b.name): $(b.version)")
end

# Install a package
function add(pkg::AbstractString)
    # TODO
end

function rm(pkg::AbstractString)
    # TODO
end

# Include our own, personal bindeps integration stuff
include("bindeps.jl")

__init__()
end
