class Shelly::Client
  def redeploy(cloud)
    post("/apps/#{cloud}/deploys")
  end

  def deployment(cloud, deployment_id)
    get("/apps/#{cloud}/deploys/#{deployment_id}")
  end
end
