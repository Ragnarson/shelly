class Shelly::Client
  def maintenances(cloud)
    get("/apps/#{cloud}/maintenances")
  end

  def start_maintenance(cloud, attributes)
    post("/apps/#{cloud}/maintenances", :maintenance => attributes)
  end

  def finish_maintenance(cloud)
    put("/apps/#{cloud}/maintenances/last", :maintenance => {:finished => true})
  end
end
