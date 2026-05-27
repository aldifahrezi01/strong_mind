Rails.application.config.secret_key_base = Rails.application.credentials.secret_key_base rescue nil
Rails.application.config.secret_key_base ||= ENV["SECRET_KEY_BASE"]

if Rails.application.config.secret_key_base.blank?
  env = Rails.env
  secrets_path = Rails.root.join("config/secrets.yml")
  if File.exist?(secrets_path)
    secrets = YAML.safe_load(ERB.new(File.read(secrets_path)).result, aliases: true)
    Rails.application.config.secret_key_base = secrets.dig(env, "secret_key_base")
  end
end
