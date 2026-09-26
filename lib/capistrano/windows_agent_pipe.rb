# Lets net-ssh talk to the Windows OpenSSH agent (the ssh-agent service, fed by
# `ssh-add`). net-ssh only knows Unix sockets and Pageant, so without this it
# falls back to reading ~/.ssh/id_rsa and prompting for the passphrase, which
# fails when there's no terminal.
#
# net-ssh's agent client only calls #send(data, flags), #read(n) and #close.
class WindowsAgentPipe
  PATH = '\\\\.\\pipe\\openssh-ssh-agent'

  def self.open
    new(File.open(PATH, "r+b"))
  end

  def initialize(io)
    @io = io
  end

  # Unbuffered I/O: Ruby's buffered read/write on one pipe handle can stall.
  def send(data, _flags)
    @io.syswrite(data)
  end

  def read(length)
    buffer = +""
    buffer << @io.sysread(length - buffer.bytesize) while buffer.bytesize < length
    buffer
  end

  def close
    @io.close
  end
end
