class Shelly::Client
  def deploy_logs(cloud)
    get("/apps/#{cloud}/deployment_logs")
  end

  def deploy_log(cloud, log)
    get("/apps/#{cloud}/deployment_logs/#{log}")
  end
end
