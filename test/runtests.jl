using View5D, Test

data1 = rand(5,5,3,2,2);
data2 = rand(5,5,3,2,2);
data3 = rand(5,5,3,4,2); # more elements

@testset "start viewers" begin
    @vv data1 # start the viewer
    @ve data2 # append along element
    @vt data3 # append along time
    @vt data3 # append along time
    @test 6 == get_num_times()
    @test 4 == get_num_elements()
    hide_viewer() 
end

@testset "interaction with markers" begin
    @vv data1 # start the viewer
    markers = empty_marker_list(2,2)
    markers[1][3]=1.0 
    markers[2][4]=2.0 
    markers[2][5]=1.0 
    markers[3][3]=3.0 
    markers[3][5]=2.0 
    markers[4][3]=1.5 
    markers[4][4]=1.5 
    markers[4][5]=2.0 
    import_marker_lists(markers)
    exported = export_marker_lists()
    mydiff = exported .- markers
    for d in 1:4
        @test mydiff[d][2:9] == zeros(8)
    end
    delete_all_marker_lists()
end

data1 = rand(5,5,3,1,1) .+ 1im.*rand(5,5,3,1,1);
data2 = rand(5,5,3,1,1) .+ 1im.*rand(5,5,3,1,1);
data3 = rand(5,5,3,2,1) .+ 1im.*rand(5,5,3,2,1); # more elements

@testset "complex-valued display" begin
    @vp data1 # start a new viewer in phase mode
    set_gamma(1.0)
    @vep data2 # start a new viewer in phase mode
    hide_viewer() 
end

