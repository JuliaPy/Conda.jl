using Conda

# Let's see if Conda is installed. If not, let's do that first!
@unix_only is_installed = isexecutable(Conda.conda)
@windows_only is_installed =  isfile(Conda.conda * ".exe")
if !is_installed
    Conda._install_conda()
end
