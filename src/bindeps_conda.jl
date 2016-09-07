# This file contains the necessary ingredients to create a PackageManager for BinDeps
using BinDeps

type ManagerType{T} <: BinDeps.PackageManager
    packages::Vector{Compat.ASCIIString}
end

function Environment{T}(manager::ManagerType{T})
    Environment(T)
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
        if !exists(pkg, Environment(manager))
            return false
        end
    end
    return true
end

if is_unix()
    BinDeps.libdir{T}(m::ManagerType{T}, ::Any) = joinpath(prefix(Environment(m)), "lib")
end
if is_windows()
    function BinDeps.libdir{T}(m::ManagerType{T}, ::Any)
        package = m.packages[1]
        env = Environment(m)
        joinpath(prefix(env), "Library", "bin")]
    end
end

BinDeps.bindir{T}(m::ManagerType{T}, ::Any) = Conda.bin_dir(Environment(m))

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
        add(pkg, Environment(manager))
    end
end
