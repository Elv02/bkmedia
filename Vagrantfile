# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # Multi machine server setup  
  config.vm.define "server1" do |server1|
    config.vm.box = "bento/ubuntu-22.04"
    config.vm.network "private_network", ip: "192.168.33.10"
  end
  config.vm.define "server2" do |server2|
    config.vm.box = "bento/ubuntu-22.04"
    config.vm.network "private_network", ip: "192.168.33.11"
  end
  config.vm.define "server3" do |server3|
    config.vm.box = "bento/ubuntu-22.04"
    config.vm.network "private_network", ip: "192.168.33.12"
  end

  # Disable the default share of the current code directory. Doing this
  # to ensure/prove that all file sync operations are occuring over network
  # connections *only*
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Copy host SSH key to the VMs on setup
  ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
  config.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false
end
