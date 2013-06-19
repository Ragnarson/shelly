class Shelly::Client
  def register_user(email, password, ssh_key)
    post("/users", :user => {:email => email, :password => password, :ssh_key => ssh_key})
  end
end
