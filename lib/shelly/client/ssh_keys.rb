class Shelly::Client
  def add_ssh_key(ssh_key)
    post("/ssh_keys", :ssh_key => ssh_key)
  end

  def delete_ssh_key(fingerprint)
    delete("/ssh_keys/#{fingerprint}")
  end

  def ssh_key(fingerprint)
    get("/ssh_keys/#{fingerprint}")
  end
end
