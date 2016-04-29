class FuncgenServerMessage
  def initialize(message, sender)
    @message = message
    @sender = sender
  end

  def message
    @message
  end

  def sender
    @sender
  end

  def is_from?(sender)
    return @sender.eql?(sender)
  end
end
