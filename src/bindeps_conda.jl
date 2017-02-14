# This file contains the necessary ingredients to create a PackageManager for BinDeps
using BinDeps

type EnvManager{T} <: BinDeps.PackageManager
    packages::Vector{Compat.UTF8String}
end

"Manager for root environment"
const Manager = EnvManager{Symbol(PREFIX)}

function Base.show{T}(io::IO, manager::EnvManager{T})
    write(io, "Conda packages: ", join(manager.packages, ", "))
end

BinDeps.can_use(::Type{EnvManager}) = true

function BinDeps.package_available{T}(manager::EnvManager{T})
    pkgs = manager.packages
    # For each package, see if we can get info about it. If not, fail out
    for pkg in pkgs
        if !exists(pkg, T)
            return false
        end
    end
    return true
end

BinDeps.libdir{T}(m::EnvManager{T}, ::Any) = lib_dir(T)
BinDeps.bindir{T}(m::EnvManager{T}, ::Any) = bin_dir(T)

BinDeps.provider{T, S<:String}(::Type{EnvManager{T}}, packages::Vector{S}; opts...) = EnvManager{T}(packages)
BinDeps.provider{T}(::Type{EnvManager{T}}, packages::String; opts...) = EnvManager{T}([packages])

function BinDeps.generate_steps(dep::BinDeps.LibraryDependency, manager::EnvManager, opts)
    pkgs = manager.packages
    if isa(pkgs, AbstractString)
        pkgs = [pkgs]
    end
    ()->install(pkgs, manager)
end

function install{T}(pkgs, manager::EnvManager{T})
    for pkg in pkgs
        add(pkg, T)
    end
end
