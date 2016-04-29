require 'celluloid/current'
require 'celluloid/io'
require 'serialport'
require 'ruby-progressbar'
require 'securerandom'
require_relative 'servermessage'
require_relative 'connectionhandler'
require_relative 'messagehandler'

class FuncgenServer
  include Celluloid::IO
  finalizer :shutdown

  def initialize(host, port, serialport)
    puts "--- Starting server on #{host} port #{port}..."
    puts "--- Opening serial device #{serialport}..."
    begin
      @sp = SerialPort.new(serialport, 57600, 8, 1, SerialPort::NONE)
    rescue
      abort "!!! Failed to open #{serialport}!"
    end
    puts "--- Successfully opened serial device."
    begin
      @server = TCPServer.new(host, port)
    rescue
      abort "!!! Failed to open server port for binding!"
    end
    puts "--- Successfully bound to port #{port}."
    @masterqueue = Queue.new
    @registry = Hash.new
    @messagehandler = FuncgenMessageHandler.new(@masterqueue, @registry, @sp)
    @messagehandler.async.messageloop
    async.run
  end

  def shutdown
    @masterqueue << FuncgenServerMessage.new("Server shutting down NOW!", "server")
    @server.close if @server
  end

  def run
    loop { handle_connection @server.accept }
  end

  def list_connections
    puts "No connections currently." if @registry.empty?
    @registry.each do |k,v|
      _, port, host = v.peeraddr
      puts "Connection #{k}: #{host}:#{port}"
    end
  end

  def server_message(message)
    @masterqueue << FuncgenServerMessage.new(message, "server")
  end

  def handle_connection(socket)
    _, port, host = socket.peeraddr
    handle = SecureRandom.hex(8)
    puts "Opened connection #{handle} to #{host}:#{port}"
    Celluloid::Actor[handle] = FuncgenConnectionHandler.new_link(@masterqueue, socket, handle)
    @registry.store(handle, socket)
    Celluloid::Actor[handle].async.listen
    @masterqueue << FuncgenServerMessage.new("sync", handle) #forge sync request to client in question
    @masterqueue << FuncgenServerMessage.new("new-client", handle) #new-client to other clients
  end
end
