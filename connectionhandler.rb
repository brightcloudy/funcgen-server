require 'celluloid/current'
require 'celluloid/io'
require 'serialport'
require_relative 'servermessage'

class FuncgenConnectionHandler
  include Celluloid::IO

  def initialize(queue, socket, handle)
    @queue = queue
    @socket = socket
    @handle = handle
  end

  def handle
    @handle
  end

  def listen
    begin
      return if @socket.nil?
      loop do
        raise "EOF" if @socket.eof?
        cmd = @socket.gets.strip
        @queue << FuncgenServerMessage.new(cmd, @handle)
      end
    rescue
      @socket.close
      @socket = nil
      @queue << FuncgenServerMessage.new("EOF", @handle)
    end
  end
end
