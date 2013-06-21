class Shelly::Client
  def authorize_with_email_and_password(email, password)
    forget_authorization
    @email = email; @password = password
    api_key = get_token
    store_api_key_in_netrc(email, api_key)
  end

  def user_email
    @email || email_from_netrc
  end

  def authorize!
    get_token
    true
  end

  def forget_authorization
    remove_api_key_from_netrc
  end

  def get_token
    get("/token")["token"]
  end

  def basic_auth_from_netrc
    if netrc
      user, password = netrc[api_host]
      {:user => user, :password => password}
    else
      {}
    end
  end

  def store_api_key_in_netrc(email, api_key)
    FileUtils.mkdir_p(File.dirname(netrc_path))
    FileUtils.touch(netrc_path)
    FileUtils.chmod(0600, netrc_path)

    netrc[api_host] = [email, api_key]
    netrc.save
  end

  def remove_api_key_from_netrc
    if netrc
      netrc.delete(api_host)
      netrc.save
    end
  end

  def email_from_netrc
    netrc[api_host].first if netrc
  end

  def netrc
    @netrc ||= File.exists?(netrc_path) && Netrc.read(netrc_path)
  end

  def netrc_path
    default = Netrc.default_path
    encrypted = default + ".gpg"
    if File.exists?(encrypted)
      encrypted
    else
      default
    end
  end
end
