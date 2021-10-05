ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

# default value, override when calling vagrant
ENV['BFIP'] ||= "192.168.10.60"
ENV['PGIP'] ||= "192.168.10.59"

# default box
# override with bfbase if installed
ENV['VGBOX'] ||= "debian/contrib-stretch64"

Vagrant.configure("2") do |config|
  config.vm.box = ENV['VGBOX'] ||= "debian/contrib-stretch64"
  config.vm.synced_folder ".", "/vagrant", type: "sshfs"
  # this provisioner should basically be a no-op if using
  # a bfbase box that's been previously set up
  config.vm.provision "shell", path: "base_provision.sh"

  config.vm.define "testbf" do |bf|
    bf.vm.network :public_network, bridge: 'enp0s7', ip: ENV['BFIP']
    bf.vm.provision :shell, :path => "provision.sh",
                    :args => [ ENV['BFIP'], ENV['PGIP'] ]
    bf.vm.hostname = 'bfserver'
  end
  config.vm.define "pgweb" do |pg|
    pg.vm.network :public_network, bridge: 'enp0s7', ip: ENV['PGIP']
    pg.vm.provision :shell, :path => "pg_provision.sh",
                    :args => [ ENV['BFIP'], ENV['PGIP'] ]
    pg.vm.hostname = 'pgweb'
  end
end
