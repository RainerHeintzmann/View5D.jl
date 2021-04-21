using JavaCall
using Pkg
#View5D_jar = joinpath(Pkg.dir(), "View5D", "View5D.jar")
#JavaCall.addClassPath(View5D_jar)

#JavaCall.init(["-verbose:jni", "-verbose:gc","-Djava.class.path=$(joinpath(Pkg.dir(), "View5D\\AllClasses"))"])
JavaCall.init(["-Djava.class.path=$(joinpath(Pkg.dir(), "View5D\\AllClasses"))"])


#JavaCall.init(["-verbose:jni", "-verbose:gc","-Djava.class.path=$(joinpath(Pkg.dir(), "JavaCall", "test"))"])
#JavaCall.init(["-verbose:jni", "-verbose:gc","-Djava.class.path=$(joinpath(Pkg.dir(), "JavaCall", "test"))","-Djava.class.path=C:\\Users\\pi96doc\\Programs\\Fiji.app\\plugins\\View5D_-1.3.1-SNAPSHOT.jar"])
#JavaCall.init(["-Xmx512M", "-verbose:jni", "-verbose:gc","-Djava.class.path=C:\\Users\\pi96doc\\Programs\\Fiji.app\\plugins\\View5D_-1.3.1-SNAPSHOT.jar"])
#JavaCall.init(["-Xmx512M", "-verbose:jni", "-verbose:gc","-Djava.class.path=$(joinpath(Pkg.dir(), "View5D", "View5D.jar"))"])
#JavaCall.init(["-Xmx512M", "-verbose:jni", "-verbose:gc","-Djava.class.path=$(joinpath(Pkg.dir(), "View5D", "AllClasses"))"])

#a=JString("how are you")
#a.ptr != C_NULL
#11==ccall(JavaCall.jnifunc.GetStringUTFLength, jint, (Ptr{JavaCall.JNIEnv}, Ptr{Void}), JavaCall.penv, a.ptr)
#b=ccall(JavaCall.jnifunc.GetStringUTFChars, Ptr{Uint8}, (Ptr{JavaCall.JNIEnv}, Ptr{Void}, Ptr{Void}), JavaCall.penv, a.ptr, C_NULL)
#bytestring(b) == "how are you"

myArray= rand(64,64,3,2,2)  # this is the 5D-Array to display

jfloatArr=Array{Float32,1};
myJArr=Array(jfloat,prod(size(myArray)));
myJArr[:]=myArray[:];
V = @jimport "View5D"
#qq=jcall(V, "testing456", jfloatArr, (jfloatArr,), myJArr)

myviewer=jcall(V, "Start5DViewer", JavaObject{:View5D}, (jfloatArr, jint, jint, jint, jint, jint), myJArr, size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5))

#jcall(V, "testing123", jfloat, (jfloat,), 10.0)
#jcall(V, "testing123", myf, (myf,), 12.2)

#T = @jimport "Test"
#10 == jcall(T, "testInt", jint, (jint,), 10)

#T2 = @jimport "Testq"
#10 == jcall(T2, "testInt", jint, (jint,), 10)

#T3 = @jimport "TaggedComponent"
#yyy=jcall(T3, "TaggedComponent", JObject, (JString,JString,JObject),"Hello","World",0)
#yyy=jcall(T3, "getDescription", JString, ())
#zzz=jcall(T3, "getValue", JObject)

#T4 = @jimport "View5D"
#jcall(T4, "testing123", jfloat, (jfloat,), 10.0)

#T2 = @jimport "Testq"
#jcall(T2, "testFloat", jfloat, (jfloat,), 10.0)
