Vagrant.configure("2") do |config|
  config.vm.box = "debian/contrib-stretch64"
  config.vm.synced_folder ".", "/vagrant", type: "sshfs"
  config.vm.network :public_network, bridge: 'enp0s7', ip: "192.168.10.245"
  config.vm.provision :shell, :path => "provision.sh"
end
