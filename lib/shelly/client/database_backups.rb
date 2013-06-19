class Shelly::Client
  def database_backups(code_name)
    get("/apps/#{code_name}/database_backups")
  end

  def database_backup(code_name, handler)
    get("/apps/#{code_name}/database_backups/#{handler}")
  end

  def restore_backup(code_name, filename)
    put("/apps/#{code_name}/database_backups/#{filename}/restore")
  end

  def request_backup(code_name, kind = nil)
    post("/apps/#{code_name}/database_backups", :kind => kind)
  end

  def download_backup_url(code_name, filename)
    get("/apps/#{code_name}/database_backups/#{filename}/download_url")["url"]
  end
end
