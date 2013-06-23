class Shelly::Client
  def app_configs(cloud)
    get("/apps/#{cloud}/configs")
  end

  def app_config(cloud, path)
    get("/apps/#{cloud}/configs/#{CGI.escape(path)}")
  end

  def app_create_config(cloud, path, content)
    post("/apps/#{cloud}/configs", :config => {:path => path, :content => content})
  end

  def app_update_config(cloud, path, content)
    put("/apps/#{cloud}/configs/#{CGI.escape(path)}", :config => {:content => content})
  end

  def app_delete_config(cloud, path)
    delete("/apps/#{cloud}/configs/#{CGI.escape(path)}")
  end
end
