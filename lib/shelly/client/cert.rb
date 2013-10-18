class Shelly::Client
  def cert(cloud)
    get("/apps/#{cloud}/cert")
  end

  def create_cert(cloud, content, key)
    post("/apps/#{cloud}/cert", :cert => {:content => content, :key => key})
  end

  def update_cert(cloud, content, key)
    put("/apps/#{cloud}/cert", :cert => {:content => content, :key => key})
  end
end
