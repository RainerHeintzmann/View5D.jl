using Tar, Inflate, SHA
fn = "View5D_-$V.$VV.$VVV$Suffix-jar"
filename="C:\\Users\\pi96doc\\Documents\\Programming\\Java\\View5D\\target\\$(fn).tar.gz"
println("[View5D-jar]")
println("git-tree-sha1 = \"", Tar.tree_hash(IOBuffer(inflate_gzip(filename))),"\"")
println("lazy = true\n")
println("    [[View5D-jar.download]]")
println("    url = \"https://github.com/bionanoimaging/View5D/releases/download/View5D_v$(V).$VV.$VVV/$(fn).tar.gz\" ")
println("    sha256 = \"", bytes2hex(open(sha256, filename)), "\"")
println("\n\n#Put this into libne 40 of viewer_core:")
fn = "View5D_-$V.$VV.$VVV$Suffix.jar"
println("const View5D_jar = joinpath(rootpath, \"$(fn)\")")

# and then put these values into the Artifacts.toml file and also update the Version number there.
