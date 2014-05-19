module View5D
export view5d

using JavaCall
using JavaShowMethods

#View5D_jar = joinpath(Pkg.dir(), "View5D", "View5D.jar")
#JavaCall.addClassPath(View5D_jar)


# myArray= rand(64,64,3,1,1)  # this is the 5D-Array to display

function view5d(myArray::Array)
        if ! JavaCall.isloaded()
                JavaCall.init(["-Djava.class.path=$(joinpath(Pkg.dir(), "View5D\\AllClasses"))"])
        end
        V = @JavaCall.jimport "View5D"

        mysize=prod(size(myArray))

        if iseltype(myArray,Complex)
            jArr=Array{Float32,1};
            myJArr=Array(jfloat,mysize*2);
            myJArr[1:mysize]=real(myArray[:]);  # copies all the real data
            myJArr[mysize+1:2*mysize]=imag(myArray[:]);  # copies all the imaginary data
            myviewer=jcall(V, "Start5DViewerC", JavaObject{:View5D}, (jArr, jint, jint, jint, jint, jint), myJArr, size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5));
        else
            if isa(myArray,Array{Float64})
                jArr=Array{Float64,1};
                myJArr=Array(jdouble,mysize);
            elseif isa(myArray,Array{Int32})
                jArr=Array{Int64,1};
                myJArr=Array(jint,mysize);
            elseif isa(myArray,Array{Int64})
                jArr=Array{Int32,1};
                myJArr=Array(jshort,mysize);
            else isa(myArray,Array{Float32})
                jArr=Array{Float32,1};
                myJArr=Array(jfloat,mysize);
            end
            myJArr=reshape(myArray,[mysize]);  # copies all the data  or use reshape...
            myviewer=jcall(V, "Start5DViewer", JavaObject{:View5D}, (jArr, jfloat, jint, jint, jint, jint), myJArr, size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5));
        end
        return myviewer
end

# To test:
# mv=view5d(rand(64,64,3,1,1)+im*rand(64,64,3,1,1))
#

end # module
