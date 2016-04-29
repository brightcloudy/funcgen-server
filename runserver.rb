require_relative 'server'

serv = FuncgenServer.new("0.0.0.0", 37846, "/dev/ttyUSB0")
loop do
  what = STDIN.gets.strip
  if what == "list"
    serv.list_connections
  elsif what == "exit"
    serv.terminate
  elsif what != ""
    serv.server_message what
  end
end
