function plot_grid(data, file_name; ac_only = false)
# Creating a series of vectors to be added to a DataFrame dictionary
# AC Buses (type 0) and DC Buses (type 1)
nodes = []
lat = []
lon = []
type = []
for (b_id,b) in data["bus"]
    push!(nodes,b["index"])
    push!(lat,b["lat"])
    push!(lon,b["lon"])
    push!(type,0)
end
 
for (b_id,b) in data["busdc"]
    push!(nodes,b["index"])
    push!(lat,b["lat"])
    push!(lon,b["lon"])
    push!(type,1)
end
 
# Creating a series of vectors to be added to a DataFrame dictionary
# AC Branches (type 0) and DC Branches (type 1)
 
branches = []
lat_fr = []
lon_fr = []
lat_to = []
lon_to = []
bus_fr = []
bus_to = []
bus_fr_ = []
bus_to_ = []
type_ = []
overload = []
 
for (b, branch) in data["branch"]
    bus_fr = branch["f_bus"]
    bus_to = branch["t_bus"]
    if haskey(data["bus"], "$bus_fr") && haskey(data["bus"], "$bus_to")
        push!(branches,branch["index"])
        push!(bus_fr_,deepcopy(branch["f_bus"]))
        push!(bus_to_,deepcopy(branch["t_bus"]))
        push!(lat_fr,data["bus"]["$bus_fr"]["lat"])
        push!(lon_fr,data["bus"]["$bus_fr"]["lon"])
        push!(lat_to,data["bus"]["$bus_to"]["lat"])
        push!(lon_to,data["bus"]["$bus_to"]["lon"])
        push!(type_,0)
    end
end
for (b, branch) in data["branchdc"]
    bus_fr = branch["fbusdc"]
    bus_to = branch["tbusdc"]
    if haskey(data["busdc"], "$bus_fr") && haskey(data["busdc"], "$bus_to")
        push!(bus_fr_,branch["fbusdc"])
        push!(bus_to_,branch["tbusdc"])
        push!(branches,branch["index"])
        push!(lat_fr,data["busdc"]["$bus_fr"]["lat"])
        push!(lon_fr,data["busdc"]["$bus_fr"]["lon"])
        push!(lat_to,data["busdc"]["$bus_to"]["lat"])
        push!(lon_to,data["busdc"]["$bus_to"]["lon"])
    push!(type_,1)
    end
end
 
dict_nodes =DataFrames.DataFrame("node"=>nodes,"lat"=>lat,"lon"=>lon, "type"=> type)
map_=DataFrames.DataFrame("from"=>bus_fr_,"to"=>bus_to_,"lat_fr"=>lat_fr,"lon_fr"=>lon_fr,"lat_to"=>lat_to,"lon_to"=>lon_to,"type"=>type_)
txt_x=1
 
ac_buses=filter(:type => ==(0), dict_nodes)       
markerAC = PlotlyJS.attr(size=[txt_x],
            color="green")
 
dc_buses=filter(:type => ==(1), dict_nodes)       
markerDC = PlotlyJS.attr(size=[txt_x],
            color="blue")
       
 
#AC buses legend
traceAC = [PlotlyJS.scattergeo(;mode="markers",#textfont=PlotlyJS.attr(size=10*txt_x),
##textposition="top center",text=string(row[:node][1]),
            lat=[row[:lat]],lon=[row[:lon]],
            marker=markerAC)  for row in eachrow(ac_buses)]
 
#DC buses legend
traceDC = [PlotlyJS.scattergeo(;mode="markers",textfont=PlotlyJS.attr(size=10*txt_x),
textposition="top center",text=string(row[:node][1]),
            lat=[row[:lat]],lon=[row[:lon]],
           marker=markerDC)  for row in eachrow(dc_buses)]
#mode="markers+text"
 
#DC line display
lineDC = PlotlyJS.attr(width=1*txt_x,color="red")
 
#AC line display
lineAC = PlotlyJS.attr(width=1*txt_x,color="navy")#,dash="dash")
 
#AC line legend
trace_AC=[PlotlyJS.scattergeo(;mode="lines",
lat=[row.lat_fr,row.lat_to],
lon=[row.lon_fr,row.lon_to],
#opacity = row.overload,
line=lineAC)
for row in eachrow(map_) if (row[:type]==0)]
 
#DC line display
#lineDC = PlotlyJS.attr(width=1*txt_x,color="red")#,dash="dash")
 
#DC line legend
trace_DC=[PlotlyJS.scattergeo(;mode="lines",
lat=[row.lat_fr,row.lat_to],
lon=[row.lon_fr,row.lon_to],
#opacity = row.overload,
line=lineDC)
for row in eachrow(map_) if (row[:type]==1)]
 
#combine plot data               
if ac_only == true
    trace=vcat(trace_AC,traceAC) # only AC Branches and buses
else
    trace=vcat(trace_AC,trace_DC,traceDC,traceAC) # both AC Branches and buses, DC Branches and buses
end
#set map location
geo = PlotlyJS.attr(scope="europe",fitbounds="locations")
 
#plot layput
layout = PlotlyJS.Layout(geo=geo,geo_resolution=50, width=1000, height=1100,
showlegend = false,
#legend = PlotlyJS.attr(x=0,y = 0.95,font=PlotlyJS.attr(size=25*txt_x),bgcolor= "#1C00ff00"),
margin=PlotlyJS.attr(l=0, r=0, t=0, b=0))
#display plot
PlotlyJS.plot(trace, layout) # print figure
PlotlyJS.savefig(PlotlyJS.plot(trace, layout), file_name)


end