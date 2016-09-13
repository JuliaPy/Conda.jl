# This file contains the necessary ingredients to create a PackageManager for BinDeps
using BinDeps

type ManagerType{T} <: BinDeps.PackageManager
    packages::Vector{Compat.ASCIIString}
end

"Manager for root environment"
Manager = ManagerType{Symbol(prefix(RootEnv))}

function Base.show{T}(io::IO, manager::ManagerType{T})
    write(io, "Conda packages: ", join(manager.packages, ", "))
end

BinDeps.can_use{T}(::Type{ManagerType{T}}) = true

function BinDeps.package_available{T}(manager::ManagerType{T})
    pkgs = manager.packages
    # For each package, see if we can get info about it. If not, fail out
    for pkg in pkgs
        if !exists(pkg, manager)
            return false
        end
    end
    return true
end

BinDeps.libdir{T}(m::ManagerType{T}, ::Any) = lib_dir(m)
BinDeps.bindir{T}(m::ManagerType{T}, ::Any) = bin_dir(m)

BinDeps.provider{T, S<:String}(::Type{ManagerType{T}}, packages::Vector{S}; opts...) = ManagerType{T}(packages)
BinDeps.provider{T}(::Type{ManagerType{T}}, packages::String; opts...) = ManagerType{T}([packages])

function BinDeps.generate_steps{T}(dep::BinDeps.LibraryDependency, manager::ManagerType{T}, opts)
    pkgs = manager.packages
    if isa(pkgs, AbstractString)
        pkgs = [pkgs]
    end
    ()->install(pkgs, manager)
end

function install(pkgs, manager::ManagerType)
    for pkg in pkgs
        add(pkg, manager)
    end
end
