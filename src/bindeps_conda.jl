# This file contains the necessary ingredients to create a PackageManager for BinDeps
using BinDeps

type Manager <: BinDeps.PackageManager
    packages::Vector{ASCIIString}
end

function Base.show(io::IO, manager::Manager)
    write(io, "Conda packages: ", join(manager.packages, ", "))
end

BinDeps.can_use(::Type{Manager}) = true

function BinDeps.package_available(manager::Manager)
    pkgs = manager.packages
    # For each package, see if we can get info about it. If not, fail out
    for pkg in pkgs
        if !exists(pkg)
            return false
        end
    end
    return true
end

BinDeps.libdir(::Manager, ::Any) = joinpath(PREFIX, "lib")
BinDeps.provider(::Type{Manager}, packages::Vector{ASCIIString}; opts...) = Manager(packages)
BinDeps.provider(::Type{Manager}, packages::ASCIIString; opts...) = Manager([packages])

function BinDeps.generate_steps(dep::BinDeps.LibraryDependency, manager::Manager, opts)
    pkgs = manager.packages
    if isa(pkgs, AbstractString)
        pkgs = [pkgs]
    end
    ()->install(pkgs)
end

function install(pkgs)
    for pkg in pkgs
        add(pkg)
    end
end
