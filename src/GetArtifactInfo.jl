using Tar, Inflate, SHA
filename="C:\\Users\\pi96doc\\Documents\\Programming\\Java\\View5D\\View5D_v$V.$VV.$VVV-jar.tar.gz"
println("git-tree-sha1 = \"", Tar.tree_hash(IOBuffer(inflate_gzip(filename))),"\"")
println("url = \"https://github.com/RainerHeintzmann/View5D/releases/download/View5D_v$(V).$VV.$VVV/View5D_v$V.$VV.$VVV-jar.tar.gz\" ")
println("sha256 = \"", bytes2hex(open(sha256, filename)), "\"")

# and then put these values into the Artifacts.toml file and also update the Version number there.
