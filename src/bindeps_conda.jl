# This file contains the necessary ingredients to create a PackageManager for BinDeps
using BinDeps

struct EnvManager{T} <: BinDeps.PackageManager
    packages::Vector{String}
end

"Manager for root environment"
const Manager = EnvManager{Symbol(PREFIX)}

function Base.show(io::IO, manager::EnvManager)
    write(io, "Conda packages: ", join(manager.packages, ", "))
end

BinDeps.can_use(::Type{EnvManager}) = true

function BinDeps.package_available(manager::EnvManager{T}) where {T}
    pkgs = manager.packages
    # For each package, see if we can get info about it. If not, fail out
    for pkg in pkgs
        if !exists(pkg, T)
            return false
        end
    end
    return true
end

BinDeps.libdir(m::EnvManager{T}, ::Any) where {T} = lib_dir(T)
BinDeps.bindir(m::EnvManager{T}, ::Any) where {T} = bin_dir(T)

BinDeps.provider(::Type{EnvManager{T}}, packages::AbstractVector{<:AbstractString}; opts...) where {T} = EnvManager{T}(packages)
BinDeps.provider(::Type{EnvManager{T}}, packages::AbstractString; opts...) where {T} = EnvManager{T}([packages])

function BinDeps.generate_steps(dep::BinDeps.LibraryDependency, manager::EnvManager, opts)
    pkgs = manager.packages
    ()->install(pkgs, manager)
end

function install(pkgs, manager::EnvManager{T}) where {T}
    for pkg in pkgs
        add(pkg, T)
    end
end
