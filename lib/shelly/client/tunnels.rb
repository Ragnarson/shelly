class Shelly::Client
  def tunnel(code_name, service, server = nil)
    post("/apps/#{code_name}/tunnels", {:server => server, :service => service})
  end

  def configured_db_server(code_name, server = nil)
    get("/apps/#{code_name}/configured_db_server",
      {:server => server, :service => "ssh"})
  end
end
