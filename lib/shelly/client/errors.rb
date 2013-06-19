class Shelly::Client
  class APIException < Exception
    attr_reader :status_code, :body, :request_id

    def initialize(body = {}, status_code = nil, request_id = nil)
      @status_code = status_code
      @body = body
      @request_id = request_id
    end

    def [](key)
      body[key.to_s]
    end
  end

  class UnauthorizedException < APIException; end

  class ForbiddenException < APIException; end

  class ConflictException < APIException; end

  class GemVersionException < APIException; end

  class GatewayTimeoutException < APIException; end

  class LockedException < APIException; end

  class ValidationException < APIException
    def errors
      self[:errors]
    end

    def each_error
      errors.each do |field, message|
        yield [field.gsub('_',' ').capitalize, message].join(" ")
      end
    end
  end

  class NotFoundException < APIException
    def resource
      self[:resource].to_sym
    end

    def id
      self[:id]
    end
  end
end
