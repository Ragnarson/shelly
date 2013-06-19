class Shelly::Client
  def add_ssh_key(ssh_key)
    post("/ssh_keys", :ssh_key => ssh_key)
  end

  def logout(ssh_key)
    delete("/ssh_keys", :ssh_key => ssh_key)
  end
end
