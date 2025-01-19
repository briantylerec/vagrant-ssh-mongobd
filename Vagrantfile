Vagrant.configure("2") do |config|
  
  # OS configs
  config.vm.box = "ubuntu/xenial64"
  config.vm.hostname = "ubuntu16-vm"

  # Network configs
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "private_network", ip: "192.168.33.10"

  # Memory and cpu
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end

  config.vm.provision "shell", inline: <<-SHELL
    cd ../../vagrant
    sed -i 's/\r$//' mongodb.sh # Fixing line endings
    sed -i 's/\r//g' config.ini
    sed -i 's/[ \t]*$//' config.ini
    chmod +x mongodb.sh
    chmod +x config.ini
    # sudo ./mongodb.sh -f config.ini
    # sudo ./practica.sh -u administrador -p password [-n 27017]
  SHELL
end
