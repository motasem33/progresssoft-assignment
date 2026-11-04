Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "tomcat9-ubuntu2404"
  config.vm.network "forwarded_port", guest: 7070, host: 9090, protocol: "tcp"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

  config.vm.provision "shell", path: "provision-tomcat.sh"
end
