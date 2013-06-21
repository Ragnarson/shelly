class Shelly::Client
  def create_app(attributes)
    organization = attributes.delete(:organization_name)
    zone = attributes.delete(:zone_name)
    post("/apps", :app => attributes, :organization_name => organization,
           :zone_name => zone)
  end

  def delete_app(code_name)
    delete("/apps/#{code_name}")
  end

  def start_cloud(cloud)
    put("/apps/#{cloud}/start")
  end

  def stop_cloud(cloud)
    put("/apps/#{cloud}/stop")
  end

  def apps
    get("/apps")
  end

  def app(code_name)
    get("/apps/#{code_name}")
  end

  def statistics(code_name)
    get("/apps/#{code_name}/statistics")
  end

  def command(cloud, body, type)
    post("/apps/#{cloud}/command", {:body => body, :type => type})
  end

  def console(code_name, server = nil)
    get("/apps/#{code_name}/console", {:server => server})
  end
end
