using Tar, Inflate, SHA    
filename="C:\\Users\\pi96doc\\Documents\\Programming\\Java\\View5D\\View5D_v2.3.2-jar.tar.gz"
println("git-tree-sha1 = \"", Tar.tree_hash(IOBuffer(inflate_gzip(filename))),"\"")
println("sha256 = \"", bytes2hex(open(sha256, filename)), "\"")
