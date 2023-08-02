function latlon2distance(data, branch)
    fbus = branch["f_bus"]
    tbus = branch["t_bus"]

    lat1 = data["bus"]["$fbus"]["lat"]
    lon1 = data["bus"]["$fbus"]["lon"]
    lat2 = data["bus"]["$tbus"]["lat"]
    lon2 = data["bus"]["$tbus"]["lon"]

    R = 6371 # distance in kilometers
    φ1 = lat1 * pi/180 
    φ2 = lat2 * pi/180
    Δφ = (lat2-lat1) * pi/180
    Δλ = (lon2-lon1) * pi/180

    a = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2);
    c = 2 * atan(sqrt(a), sqrt(1-a));
    d = R * c


 return d
end

function latlon2distance(data, bus1, bus2)
    lat1 = data["bus"]["$bus1"]["lat"]
    lon1 = data["bus"]["$bus1"]["lon"]
    lat2 = data["bus"]["$bus2"]["lat"]
    lon2 = data["bus"]["$bus2"]["lon"]

    R = 6371 # distance in kilometers
    φ1 = lat1 * pi/180 
    φ2 = lat2 * pi/180
    Δφ = (lat2-lat1) * pi/180
    Δλ = (lon2-lon1) * pi/180

    a = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2);
    c = 2 * atan(sqrt(a), sqrt(1-a));
    d = R * c


 return d
end
