class Shelly::Client
  def organizations
    get("/organizations")
  end

  def organization(name)
    get("/organizations/#{name}")
  end

  def members(name)
    get("/organizations/#{name}/memberships")
  end

  def send_invitation(name, email, owner = false)
    post("/organizations/#{name}/memberships", :email => email, :owner => owner)
  end

  def delete_member(name, email)
    delete("/organizations/#{name}/memberships/#{email}")
  end
end
