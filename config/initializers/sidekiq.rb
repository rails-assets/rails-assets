Sidekiq.configure_server do |config|
  config.redis = { :namespace => REDIS_NAMESPACE }
end

Sidekiq.configure_client do |config|
  config.redis = { :namespace => REDIS_NAMESPACE }
end
