using Tar, Inflate, SHA    
filename="C:\\Users\\pi96doc\\Documents\\Programming\\Java\\View5D\\View5D_v2.3.8-jar.tar.gz"
println("git-tree-sha1 = \"", Tar.tree_hash(IOBuffer(inflate_gzip(filename))),"\"")
println("sha256 = \"", bytes2hex(open(sha256, filename)), "\"")
# and then put these values into the Artifacts.toml file and also update the Version number there.
