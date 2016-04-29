require 'celluloid/current'
require 'celluloid/io'
require 'serialport'
require_relative 'servermessage'

class FuncgenMessageHandler
  include Celluloid::IO

  def initialize(queue, registry, serial)
    @queue = queue
    @registry = registry
    @sp = serial
    @spmutex = Mutex.new
    sync_values
  end

  def sync_values
		@spmutex.synchronize {
      @sp.write(":r1f\n")
      resp = @sp.gets[4,10]
      @cur_freq = resp[0,5].to_i + (resp[5,5].to_i.to_f / 100000.0)
      @sp.write(":r1a\n")
      ampl = @sp.gets[4,4]
      @cur_ampl = ampl[0,2].to_i + (ampl[2,2].to_i.to_f / 100.0)
      @sp.write(":r1b\n")
      @cur_state = (@sp.gets[4,1] == '1' ? :on : :off)
		}
	end

  def pretty_values
    "%f kHz @ %f V [%s]" % [@cur_freq, @cur_ampl, pretty_state] if @cur_ampl and @cur_freq and @cur_state
  end

  def pretty_state
    (@cur_state == :on) ? "ON" : "OFF"
  end

  def messageloop
    loop do
      msg = @queue.pop
      puts "--- Message #{msg.message} from handler #{msg.sender}"
      if msg.sender.eql?("server")
        server_msg msg.message
      else
        handle_message msg
      end
    end
  end

  def server_msg(message)
    msg_all "NOTICE: #{message}"
  end

  def handle_message(msg)
    conn = Celluloid::Actor[msg.sender]
    if msg.message == "EOF"
      puts "Terminating connection #{msg.sender}"
      conn.terminate
      @registry.delete(msg.sender)
      msg_all "Client ID #{msg.sender} disconnected (Total: #{@registry.size})"
    end
    if msg.message == "PING!"
      msg_client "PONG!", msg.sender
    end
    args = msg.message.downcase.split(' ')
    case args[0]
      when "sync"
				sync_values
        msg_client pretty_values, msg.sender
      when "new-client"
        msg_all_others "New client ID #{msg.sender} (Total: #{@registry.size})", msg.sender
      when "off"
        send_serial_cmd ":s1b0"
        sync_values
        msg_all_others "OFF [by #{msg.sender}]", msg.sender
        msg_all pretty_values
      when "on"
        send_serial_cmd ":s1b1"
        sync_values
        msg_all_others "ON [by #{msg.sender}]", msg.sender
        msg_all pretty_values
      when "freq"
        if args[1].to_i < 25000
          msg_client "Please do not set the frequency so low!", msg.sender
        else
          send_serial_cmd ":s1f#{args[1]}"
          sync_values
          msg_all_others "Frequency set [by #{msg.sender}]", msg.sender
          msg_all pretty_values
        end
      when "ampl"
        send_serial_cmd ":s1a#{args[1]}"
        sync_values
        msg_all_others "Amplitude set [by #{msg.sender}]", msg.sender
        msg_all pretty_values
    end
  end

  def msg_client(message, sender)
    @registry[sender].puts message
  end

  def msg_all(message)
    @registry.each_value { |sock| sock.puts message }
  end

  def msg_all_others(message, sender)
    @registry.reject { |k,v| k.eql?(sender) }.each_value { |s| s.puts message }
  end

  def send_serial_cmd(cmd)
    @spmutex.synchronize {
      @sp.puts cmd
      @resp = @sp.gets
    }
    return @resp
  end
end
