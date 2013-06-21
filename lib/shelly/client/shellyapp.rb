class Shelly::Client
  def shellyapp_url
    get("/shellyapp")["url"]
  end
end
