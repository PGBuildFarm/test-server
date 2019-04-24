
# default value, override when calling vagrant
ENV['BFIP'] ||= "192.168.10.60"

Vagrant.configure("2") do |config|
  config.vm.box = "debian/contrib-stretch64"
  config.vm.synced_folder ".", "/vagrant", type: "sshfs"
  config.vm.network :public_network, bridge: 'enp0s7', ip: ENV['BFIP']
  config.vm.provision :shell, :path => "provision.sh"
end
