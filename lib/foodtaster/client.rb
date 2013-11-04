require 'drb'

module Foodtaster
  class Client
    MAX_ATTEMPTS = 20

    def self.connect(drb_port, server_process = nil)
      attempt_index = 1
      begin
        sleep 0.2
        client = Foodtaster::Client.new(drb_port)
      rescue DRb::DRbConnError => e
        Foodtaster.logger.debug "DRb connection failed (attempt #{attempt_index}/#{MAX_ATTEMPTS}): #{e.message}"
        attempt_index += 1
        retry if attempt_index <= MAX_ATTEMPTS && (server_process.nil? || server_process.alive?)
      end

      if client
        Foodtaster.logger.debug "DRb connection established"
      else
        Foodtaster.logger.debug "Can't connect to Foodtaster DRb Server"
      end

      client
    end

    [:vm_defined?, :prepare_vm, :rollback_vm,
     :run_chef_on_vm, :execute_command_on_vm,
     :shutdown_vm].each do |method_name|
       define_method method_name do |*args|
         begin
           @v.send(method_name, *args)
         rescue DRb::DRbUnknownError => e
           message = "Folowing error was raised on server:\n#{e.unknown.buf}"
           Foodtaster.logger.fatal(message)
           raise e
         end
       end
     end

     private

     def initialize(drb_port)
       # start local service to be able to redirect stdout & stderr
       # to client
       DRb.start_service("druby://localhost:0")
       @v = DRbObject.new_with_uri("druby://localhost:#{drb_port}")

       init
     end


     def init
       $stdout.extend DRbUndumped
       $stderr.extend DRbUndumped

       @v.redirect_stdstreams($stdout, $stderr)
     end
  end
end
