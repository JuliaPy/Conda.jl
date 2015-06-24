using Conda

# Add pkg-config
Conda.add("pkgconfig")

# Now show that we have it
run(`pkg-config --version`)
