class Shelly::Client
  def endpoints(cloud)
    get("/apps/#{cloud}/endpoints")
  end

  def endpoint(cloud, uuid)
    get("/apps/#{cloud}/endpoints/#{uuid}")
  end

  def create_endpoint(cloud, certificate, key, sni)
    endpoint = certificate && key ? {:certificate => certificate,
      :key => key} : {}

    post("/apps/#{cloud}/endpoints", :endpoint => endpoint.merge(:sni => sni))
  end

  def update_endpoint(cloud, uuid, certificate, key)
    put("/apps/#{cloud}/endpoints/#{uuid}",
      :endpoint => {:certificate => certificate, :key => key})
  end

  def delete_endpoint(cloud, uuid)
    delete("/apps/#{cloud}/endpoints/#{uuid}")
  end
end
