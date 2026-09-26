server "mendicant.com",
       user: "jason",
       roles: %w[app web db]

# Requires Windows OpenSSH agent running with key loaded:
#   ssh-add ~/.ssh/id_rsa
#
# No agent forwarding: the server pulls from GitHub with its own key, and
# forwarding hangs through the Windows agent pipe below.
ssh_options = {
  forward_agent: false,
  auth_methods:  %w[publickey]
}

if Gem.win_platform?
  require_relative "../../lib/capistrano/windows_agent_pipe"
  ssh_options[:agent_socket_factory] = -> { WindowsAgentPipe.open }
end

set :ssh_options, ssh_options
