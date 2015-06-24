# This file contains the necessary ingredients to create a PackageManager for BinDeps
using BinDeps

type CondaManager <: BinDeps.PackageManager
    packages
end

function Base.show(io::IO, hb::CondaManager)
    write(io, "Homebrew Bottles ", join(isa(hb.packages, AbstractString) ? [hb.packages] : hb.packages,", "))
end

# Only return true on Darwin platforms
BinDeps.can_use(::Type{CondaManager}) = OS_NAME == :Darwin

function BinDeps.package_available(p::CondaManager)
    !can_use(CondaManager) && return false
    pkgs = p.packages
    if isa(pkgs, AbstractString)
        pkgs = [pkgs]
    end

    # For each package, see if we can get info about it.  If not, fail out
    for pkg in pkgs
        try
            info(pkg)
        catch
            return false
        end
    end
    return true
end

BinDeps.libdir(::CondaManager, ::Any) = joinpath(PREFIX, "lib")
BinDeps.provider(::Type{CondaManager}, packages::Vector{ASCIIString}; opts...) = CondaManager(packages)

function BinDeps.generate_steps(dep::BinDeps.LibraryDependency, p::CondaManager, opts)
    pkgs = p.packages
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
