class Shelly::Client
  def register_user(email, password)
    post("/users", :user => {:email => email, :password => password})
  end
end
