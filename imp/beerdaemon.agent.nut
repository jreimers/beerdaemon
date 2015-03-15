/*
Beer Daemon Agent
John Reimers 2015
http://ohm.ninja
*/


device.on("update_temp", function(temp) {
    local request = http.get("http://pt.ohm.ninja/update_temp", { "temp": temp, "api_key": "super_secure_password" });
    local response = request.sendsync();
})
device.on("update_dist", function(dist) {
    local request = http.get("http://pt.ohm.ninja/update_dist", { "dist": dist, "api_key": "super_secure_password" });
    local response = request.sendsync();
});