# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# Set this to the amount of RAM for the node
SYSTEM_RAM = "1024"

count = 0
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.synced_folder ".",
    "/workspace/pshaw"

  config.vm.network :private_network, ip: "192.168.3.99"
  config.vm.box = "puppetlabs/centos-6.5-64-puppet"
  config.vm.hostname = "pshawtest.local"
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", SYSTEM_RAM]
  end
end
