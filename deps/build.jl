using Conda

# Let's see if Conda is installed. If not, let's do that first!
if !isexecutable(Conda.conda)
    Conda._install()
end
