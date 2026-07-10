# -*- mode: ruby -*-
# vi: set ft=ruby :

# ==============================================================================
# DevOps Lab: 4 machines (no provisioning — just base VMs)
#   db          -> 192.168.56.10
#   nginx       -> 192.168.56.11
#   node-app    -> 192.168.56.12
#   react-app   -> 192.168.56.13
# ==============================================================================

Vagrant.configure("2") do |config|

  config.vm.box = "alvistack/centos-10-stream"

  config.vm.define "db" do |db|
    db.vm.hostname = "db"
    db.vm.network "private_network", ip: "192.168.56.10"
    db.vm.provider :libvirt do |lv|
      lv.memory = 1024
    end
  end

  config.vm.define "nginx" do |nginx|
    nginx.vm.hostname = "nginx"
    nginx.vm.network "private_network", ip: "192.168.56.11"
    nginx.vm.network "forwarded_port", guest: 80, host: 8080
    nginx.vm.provider :libvirt do |lv|
      lv.memory = 512
    end
  end

  config.vm.define "node-app" do |node|
    node.vm.hostname = "node-app"
    node.vm.network "private_network", ip: "192.168.56.12"
    node.vm.provider :libvirt do |lv|
      lv.memory = 1024
    end
  end

  config.vm.define "react-app" do |react|
    react.vm.hostname = "react-app"
    react.vm.network "private_network", ip: "192.168.56.13"
    react.vm.provider :libvirt do |lv|
      lv.memory = 2048
    end
  end

end
