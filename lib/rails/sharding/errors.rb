module Rails::Sharding
  module Errors

    class UninitializedError < StandardError; end

    class WrongUsageError < StandardError; end

    class ConnectionPoolRetrievalError < StandardError; end

    class ConfigNotFoundError < StandardError; end

  end
end
