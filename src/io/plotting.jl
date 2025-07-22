function plot_grid(data, file_name; ac_only = false, color_branches = false, flows_ac = nothing, flows_dc = nothing, maximum_flows = false, plot_node_numbers_ac = false, plot_node_numbers_dc = false)
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
    
    
    for (c, conv) in data["convdc"]
        bus_ac = conv["busac_i"]
        bus_dc = conv["busdc_i"]
    
        data["busdc"]["$bus_dc"]["lat"] = data["bus"]["$bus_ac"]["lat"]
        data["busdc"]["$bus_dc"]["lon"] = data["bus"]["$bus_ac"]["lon"]
    end
     
    for (b_id,b) in data["busdc"]
        push!(nodes, b["index"])
        push!(lat, b["lat"])
        push!(lon, b["lon"])
        push!(type, 1)
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
            push!(branches, branch["index"])
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
            push!(branches, branch["index"])
            push!(lat_fr,data["busdc"]["$bus_fr"]["lat"])
            push!(lon_fr,data["busdc"]["$bus_fr"]["lon"])
            push!(lat_to,data["busdc"]["$bus_to"]["lat"])
            push!(lon_to,data["busdc"]["$bus_to"]["lon"])
        push!(type_,1)
        end
    end
     
    dict_nodes = DataFrames.DataFrame("node"=>nodes,"lat"=>lat,"lon"=>lon, "type"=> type)
    map_ = DataFrames.DataFrame("from"=>bus_fr_,"to"=>bus_to_,"lat_fr"=>lat_fr,"lon_fr"=>lon_fr,"lat_to"=>lat_to,"lon_to"=>lon_to,"type"=>type_, "branch" => branches)
    txt_x=1
     
    ac_buses=filter(:type => ==(0), dict_nodes)       
    markerAC = PlotlyJS.attr(size=[txt_x],
                color="green")
     
    dc_buses=filter(:type => ==(1), dict_nodes)       
    markerDC = PlotlyJS.attr(size=[txt_x],
                color="blue")
                
    if plot_node_numbers_ac == true            
        #AC buses legend
        traceAC = [PlotlyJS.scattergeo(;mode="markers+text",textfont=PlotlyJS.attr(size=txt_x),
        textposition="top center",text=string(row[:node][1]),
                    lat=[row[:lat]],lon=[row[:lon]],
                    marker=markerAC)  for row in eachrow(ac_buses)]
        
    else
        #AC buses legend
        traceAC = [PlotlyJS.scattergeo(;mode="markers",
                    lat=[row[:lat]],lon=[row[:lon]],
                    marker=markerAC)  for row in eachrow(ac_buses)]
        
    end
    if plot_node_numbers_dc == true 
                #DC buses legend
                traceDC = [PlotlyJS.scattergeo(;mode="markers+text",textfont=PlotlyJS.attr(size=txt_x),
                textposition="top center",text=string(row[:node][1]),
                            lat=[row[:lat]],lon=[row[:lon]],
                        marker=markerDC)  for row in eachrow(dc_buses)]
    else
            #DC buses legend
            traceDC = [PlotlyJS.scattergeo(;mode="markers",
            lat=[row[:lat]],lon=[row[:lon]],
            marker=markerDC)  for row in eachrow(dc_buses)]
    end
    
    if color_branches == false
        #DC line display
        lineDC = PlotlyJS.attr(width=1*txt_x,color="red")
        
        #AC line display
        lineAC = PlotlyJS.attr(width=1*txt_x,color="navy")#,dash="dash")
        
        #AC line legend
        trace_AC=[PlotlyJS.scattergeo(;mode="lines",
        lat=[row.lat_fr,row.lat_to],
        lon=[row.lon_fr,row.lon_to],
        line = lineAC)
        for row in eachrow(map_) if (row[:type]==0)]

        trace_DC=[PlotlyJS.scattergeo(;mode="lines",
        lat=[row.lat_fr,row.lat_to],
        lon=[row.lon_fr,row.lon_to],
        #opacity = row.overload,
        line = lineDC)
        for row in eachrow(map_) if (row[:type]==1)]
    else
        trace_AC = [PlotlyJS.scattergeo()]
        trace_DC = [PlotlyJS.scattergeo()]
        #AC line legend
        for row in eachrow(map_)
            if row[:type] == 0
                branch = row.branch
                if maximum_flows == true
                    flow =  maximum(flows_ac["$branch"])
                else
                    flow =  sum(flows_ac["$branch"]) / length(flows_ac["$branch"])
                end
                # color = Int(round(max(1, flow * 100)))
                lineAC = PlotlyJS.attr(width = 1 * txt_x, color = ColorSchemes.get(ColorSchemes.jet, flow))
                push!(trace_AC, PlotlyJS.scattergeo(;mode="lines", lat=[row.lat_fr,row.lat_to], lon=[row.lon_fr,row.lon_to], line = lineAC))
            else
                branch = row.branch
                if maximum_flows == true
                    flow =  maximum(flows_dc["$branch"])
                else
                    flow =  sum(flows_dc["$branch"]) / length(flows_dc["$branch"])
                end
                color = Int(round(max(1, flow * 100)))
                lineDC = PlotlyJS.attr(width = 2 * txt_x, color =  ColorSchemes.get(ColorSchemes.jet, flow))
                push!(trace_DC, PlotlyJS.scattergeo(;mode="lines", lat=[row.lat_fr,row.lat_to], lon=[row.lon_fr,row.lon_to], line = lineDC))
            end
        end
    end
     
    #combine plot data               
    if ac_only == true
        trace=vcat(trace_AC, traceAC) # only AC Branches and buses
    else
        trace=vcat(trace_AC, trace_DC, traceDC, traceAC) # both AC Branches and buses, DC Branches and buses
    end
    #set map location
    geo = PlotlyJS.attr(fitbounds="locations")
     
    #plot layput
    layout = PlotlyJS.Layout(geo = geo, geo_resolution = 50, width = 1000, height = 1100,
    showlegend = false,
    margin=PlotlyJS.attr(l=0, r=0, t=0, b=0))
    PlotlyJS.plot(trace, layout) # print figure
    PlotlyJS.savefig(PlotlyJS.plot(trace, layout), file_name)
    
end



function plot_grid_with_arrows(data, file_name;
                               flows_ac::Dict{String,Vector{Float64}},
                               flows_dc::Dict{String,Vector{Float64}},
                               ac_only::Bool=false)
    
    # 1) Collect buses
    nodes, lat, lon, ntype = Int[], Float64[], Float64[], Int[]
    for (_, b) in data["bus"]
        push!(nodes, b["index"]); push!(lat, b["lat"]); push!(lon, b["lon"]); push!(ntype, 0)
    end
    for (_, c) in data["convdc"]
        a, d = c["busac_i"], c["busdc_i"]
        data["busdc"][string(d)]["lat"] = data["bus"][string(a)]["lat"]
        data["busdc"][string(d)]["lon"] = data["bus"][string(a)]["lon"]
    end
    for (_, b) in data["busdc"]
        push!(nodes, b["index"]); push!(lat, b["lat"]); push!(lon, b["lon"]); push!(ntype, 1)
    end
    df_nodes = _DF.DataFrame(node=nodes, lat=lat, lon=lon, type=ntype)

    # 2) Collect branches & net flows
    bid, from_, to_, lat1, lon1, lat2, lon2, btype, netflow =
      String[], Int[], Int[], Float64[], Float64[], Float64[], Float64[], Int[], Float64[]

    for (_, br) in data["branch"]
        id, f, t = string(br["index"]), br["f_bus"], br["t_bus"]
        flows = get(flows_ac, id, nothing)
        flows === nothing && continue
        push!(bid, id); push!(from_, f); push!(to_, t)
        push!(lat1, data["bus"][string(f)]["lat"]); push!(lon1, data["bus"][string(f)]["lon"])
        push!(lat2, data["bus"][string(t)]["lat"]); push!(lon2, data["bus"][string(t)]["lon"])
        push!(btype, 0); push!(netflow, sum(flows))
    end
    for (_, br) in data["branchdc"]
        id, f, t = string(br["index"]), br["fbusdc"], br["tbusdc"]
        flows = get(flows_dc, id, nothing)
        flows === nothing && continue
        push!(bid, id); push!(from_, f); push!(to_, t)
        push!(lat1, data["busdc"][string(f)]["lat"]); push!(lon1, data["busdc"][string(f)]["lon"])
        push!(lat2, data["busdc"][string(t)]["lat"]); push!(lon2, data["busdc"][string(t)]["lon"])
        push!(btype, 1); push!(netflow, sum(flows))
    end

    df_br = _DF.DataFrame(id=bid, from=from_, to=to_,
                      lat1=lat1, lon1=lon1, lat2=lat2, lon2=lon2,
                      type=btype, netflow=netflow)

    # 3) Branch lines coloured by netflow
    maxf = maximum(abs.(df_br.netflow))
    lines = PlotlyBase.AbstractTrace[]
    for r in eachrow(df_br)
        t   = (r.netflow + maxf) / (2 * maxf)
        col = ColorSchemes.get(ColorSchemes.jet, t)
        push!(lines, PlotlyJS.scattergeo(
            mode      = "lines",
            lat       = [r.lat1, r.lat2],
            lon       = [r.lon1, r.lon2],
            line      = PlotlyJS.attr(width=1, color=col),
            showlegend=false
        ))
    end

    # 4) Invisible marker for shared colorbar (inside map)
    cb = PlotlyJS.scattergeo(
        mode   = "markers",
        lat    = [0, 0],
        lon    = [0, 0],
        marker = PlotlyJS.attr(
            size       = 0,
            opacity    = 0,
            color      = [-maxf, maxf],
            colorscale = "Jet",
            cmin       = -maxf,
            cmax       =  maxf,
            showscale  = true,
            colorbar   = PlotlyJS.attr(
                title     = "Net flow",
                titleside = "top",
                thickness = 15,
                len       = 0.5,
                x         = 0.82,   # inside geo domain
                y         = 0.5
            )
        ),
        showlegend=false,
        hoverinfo="none"
    )
    push!(lines, cb)

    # 5) Node markers (size=1)
    ac_pts = [ PlotlyJS.scattergeo(mode="markers",
                          lat=[r.lat], lon=[r.lon],
                          marker=PlotlyJS.attr(size=1, color="green"),
                          showlegend=false)
               for r in eachrow(filter(:type=>==(0), df_nodes)) ]

    dc_pts = [ PlotlyJS.scattergeo(mode="markers",
                          lat=[r.lat], lon=[r.lon],
                          marker=PlotlyJS.attr(size=1, color="blue"),
                          showlegend=false)
               for r in eachrow(filter(:type=>==(1), df_nodes)) ]

    # 6) Arrow‐text at midpoints (size=1)
    arrow_traces = PlotlyBase.AbstractTrace[]
    for r in eachrow(df_br)
        midlat, midlon = (r.lat1 + r.lat2)/2, (r.lon1 + r.lon2)/2
        dx, dy  = r.lon2 - r.lon1, r.lat2 - r.lat1
        angle   = atan(dy, dx) * 180 / π
        arrow   = r.netflow ≥ 0 ? "►" : "◄"
        push!(arrow_traces, PlotlyJS.scattergeo(
            mode      = "text",
            lat       = [midlat], lon=[midlon],
            text      = [arrow],
            textfont  = PlotlyJS.attr(size=2, color="black"),
            textangle = angle,
            showlegend=false
        ))
    end

    # 7) Assemble and save
    traces = ac_only ? vcat(lines, ac_pts) : vcat(lines, ac_pts, dc_pts)
    traces = vcat(traces, arrow_traces)

    layout = PlotlyJS.Layout(
        geo = PlotlyJS.attr(
            scope            = "europe",
            center           = PlotlyJS.attr(lat=42, lon=12),
            projection_scale = 7,
            showcountries    = true,
            landcolor        = "lightgray",
            domain           = PlotlyJS.attr(x=[0.0, 0.8], y=[0.0, 1.0])
        ),
        margin = PlotlyJS.attr(l=0, r=0, t=0, b=0)
    )

    fig = PlotlyJS.plot(traces, layout)
    PlotlyJS.savefig(fig, file_name)
    return fig
end




function plot_grid1(data, file_name; ac_only = false, color_branches = false, flows_ac = nothing, flows_dc = nothing, maximum_flows = false, plot_node_numbers_ac = false, plot_node_numbers_dc = false)
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

    for (c, conv) in data["convdc"]
        bus_ac = conv["busac_i"]
        bus_dc = conv["busdc_i"]

        data["busdc"]["$bus_dc"]["lat"] = data["bus"]["$bus_ac"]["lat"]
        data["busdc"]["$bus_dc"]["lon"] = data["bus"]["$bus_ac"]["lon"]
    end

    for (b_id,b) in data["busdc"]
        push!(nodes, b["index"])
        push!(lat, b["lat"])
        push!(lon, b["lon"])
        push!(type, 1)
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
            push!(branches, branch["index"])
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
            push!(branches, branch["index"])
            push!(lat_fr,data["busdc"]["$bus_fr"]["lat"])
            push!(lon_fr,data["busdc"]["$bus_fr"]["lon"])
            push!(lat_to,data["busdc"]["$bus_to"]["lat"])
            push!(lon_to,data["busdc"]["$bus_to"]["lon"])
            push!(type_,1)
        end
    end

    dict_nodes = DataFrames.DataFrame("node"=>nodes,"lat"=>lat,"lon"=>lon, "type"=> type)
    map_ = DataFrames.DataFrame("from"=>bus_fr_,"to"=>bus_to_,"lat_fr"=>lat_fr,"lon_fr"=>lon_fr,"lat_to"=>lat_to,"lon_to"=>lon_to,"type"=>type_, "branch" => branches)
    txt_x=2
    marker_txt_x=1

    ac_buses=filter(:type => ==(0), dict_nodes)       
    markerAC = PlotlyJS.attr(size=[marker_txt_x], color="green")

    dc_buses=filter(:type => ==(1), dict_nodes)       
    markerDC = PlotlyJS.attr(size=[marker_txt_x], color="blue")

    if plot_node_numbers_ac == true            
        traceAC = [PlotlyJS.scattergeo(;mode="markers+text",textfont=PlotlyJS.attr(size=txt_x),
        textposition="top center",text=string(row[:node][1]),
                    lat=[row[:lat]],lon=[row[:lon]],
                    marker=markerAC)  for row in eachrow(ac_buses)]
    else
        traceAC = [PlotlyJS.scattergeo(;mode="markers",
                    lat=[row[:lat]],lon=[row[:lon]],
                    marker=markerAC)  for row in eachrow(ac_buses)]
    end
    if plot_node_numbers_dc == true 
        traceDC = [PlotlyJS.scattergeo(;mode="markers+text",textfont=PlotlyJS.attr(size=txt_x),
        textposition="top center",text=string(row[:node][1]),
                    lat=[row[:lat]],lon=[row[:lon]],
                    marker=markerDC)  for row in eachrow(dc_buses)]
    else
        traceDC = [PlotlyJS.scattergeo(;mode="markers",
        lat=[row[:lat]],lon=[row[:lon]],
        marker=markerDC)  for row in eachrow(dc_buses)]
    end

    if color_branches == false
        lineDC = PlotlyJS.attr(width=1*txt_x,color="red")
        lineAC = PlotlyJS.attr(width=1*txt_x,color="navy")

        trace_AC=[PlotlyJS.scattergeo(;mode="lines",
        lat=[row.lat_fr,row.lat_to],
        lon=[row.lon_fr,row.lon_to],
        line = lineAC)
        for row in eachrow(map_) if (row[:type]==0)]

        trace_DC=[PlotlyJS.scattergeo(;mode="lines",
        lat=[row.lat_fr,row.lat_to],
        lon=[row.lon_fr,row.lon_to],
        line = lineDC)
        for row in eachrow(map_) if (row[:type]==1)]
    else
        trace_AC = [PlotlyJS.scattergeo()]
        trace_DC = [PlotlyJS.scattergeo()]
        for row in eachrow(map_)
            branch = row.branch
            if row[:type] == 0
                if maximum_flows == true
                    flow = maximum(flows_ac["$branch"])
                else
                    flow = sum(flows_ac["$branch"])/ length(flows_ac["$branch"])
                end
                lineAC = PlotlyJS.attr(width = 1 * txt_x, color = ColorSchemes.get(ColorSchemes.jet, flow))
                text_label = "$(round(flow; digits=2))"#$branch → 
                push!(trace_AC, PlotlyJS.scattergeo(;mode="lines+text", lat=[row.lat_fr,row.lat_to], lon=[row.lon_fr,row.lon_to], line = lineAC, text=[text_label], textposition="top right", textfont=PlotlyJS.attr(size=txt_x)))
            else
                if maximum_flows == true
                    flow = maximum(flows_dc["$branch"])
                else
                    flow = sum(flows_dc["$branch"])/ length(flows_dc["$branch"])
                end
                lineDC = PlotlyJS.attr(width = 2 * txt_x, color = ColorSchemes.get(ColorSchemes.jet, flow))
                text_label = "$(round(flow; digits=2))" #$branch → 
                push!(trace_DC, PlotlyJS.scattergeo(;mode="lines+text", lat=[row.lat_fr,row.lat_to], lon=[row.lon_fr,row.lon_to], line = lineDC, text=[text_label], textposition="top right", textfont=PlotlyJS.attr(size=txt_x)))
            end
        end
    end

    if ac_only == true
        trace=vcat(trace_AC, traceAC)
    else
        trace=vcat(trace_AC, trace_DC, traceDC, traceAC)
    end

    geo = PlotlyJS.attr(fitbounds="locations")
    layout = PlotlyJS.Layout(geo = geo, geo_resolution = 50, width = 1000, height = 1100,
    showlegend = true,
    margin=PlotlyJS.attr(l=0, r=0, t=0, b=0))
    PlotlyJS.plot(trace, layout)
    PlotlyJS.savefig(PlotlyJS.plot(trace, layout), file_name)
end













function plot_marginal_zonal_prices(result, input_data, file_name; zones = nothing)

    print("Calculating and printing zonal marginal prices", "\n")
    print("-----------------------","\n")

    if isnothing(zones)
        zones = [load["node"] for (l, load) in input_data["load"]]
    end

    zonal_price = Dict{String, Any}()
    hours = sort(parse.(Int, collect(keys(result))))
    
    for hour in hours
        for (g, gen) in result["$hour"]["solution"]["gen"]
            if gen["pg"] > 0
            node = input_data["gen"][g]["gen_bus"]
                if any(input_data["bus"]["$node"]["string"] .== zones)
                    zone = input_data["bus"]["$node"]["string"]
                    if haskey(zonal_price, zone)
                        zonal_price[zone][hour] = max(zonal_price[zone][hour], input_data["gen"][g]["cost"][2]/input_data["baseMVA"])
                    else
                        zonal_price[zone] = zeros(length(hours))
                        zonal_price[zone][hour] = max(zonal_price[zone][hour], input_data["gen"][g]["cost"][2]/input_data["baseMVA"])
                    end
                end
            end
        end
    end

    p = Plots.plot()
    for k ∈ keys(zonal_price)
        p = Plots.plot!(zonal_price[k], label = k, seriestype = :scatter)
    end

    Plots.xlabel!("Hour of the year")
    Plots.ylabel!("Zonal marginal price in € / MWh")
    Plots.savefig(p, file_name)
end


function plot_average_zonal_costs(result, input_data, file_name; zones = nothing)

    print("Calculating and printing zonal average cost of generation", "\n")
    print("-----------------------","\n")

    if isnothing(zones)
        zones = [load["node"] for (l, load) in input_data["load"]]
    end

    zonal_price = Dict{String, Any}()
    hours = sort(parse.(Int, collect(keys(result))))
    
    for zone in zones
        zonal_price[zone] = zeros(length(hours))
        for hour in hours
            zonal_gen = 0
            cost = 0
            for (g, gen) in result["$hour"]["solution"]["gen"]
                gen_bus = input_data["gen"][g]["gen_bus"]
                node = input_data["bus"]["$gen_bus"]["string"]
                if node .== zone
                    cost = cost + result["$hour"]["solution"]["gen"][g]["pg"] * input_data["gen"][g]["cost"][2]
                    zonal_gen = result["$hour"]["solution"]["gen"][g]["pg"] * input_data["baseMVA"]
                end
            end
            zonal_price[zone][hour] = cost / zonal_gen
        end
    end

    p = Plots.plot()
    for k ∈ keys(zonal_price)
        p = Plots.plot!(zonal_price[k], label = k, seriestype = :scatter)
    end

    Plots.xlabel!("Hour of the year")
    Plots.ylabel!("Average cost of generation € / MWh")
    Plots.savefig(p, file_name)
end
