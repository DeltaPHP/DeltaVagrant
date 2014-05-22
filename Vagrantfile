# -*- mode: ruby -*-
# vi: set ft=ruby :

dir = Dir.pwd
vagrant_dir = File.expand_path(File.dirname(__FILE__))

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Configurations from 1.0.x can be placed in Vagrant 1.1.x specs like the following.
  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--memory", 512]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # Forward Agent
  #
  # Enable agent forwarding on vagrant ssh commands. This allows you to use identities
  # established on the host machine inside the guest. See the manual for ssh-add
  config.ssh.forward_agent = true

  # Debian Box
  # please download this box from
  config.vm.box = "wheezy64"

  config.vm.hostname = "deltaphp"  

  # Default Box IP Address
  #
  # This is the IP address that your host will communicate to the guest through. In the
  # case of the default `192.168.50.4` that we've provided, VirtualBox will setup another
  # network adapter on your host machine with the IP `192.168.50.1` as a gateway.
  #
  # If you are already on a network using the 192.168.50.x subnet, this should be changed.
  # If you are running more than one VM through VirtualBox, different subnets should be used
  # for those as well. This includes other Vagrant boxes.
  config.vm.network :private_network, ip: "192.168.50.10"

  # Drive mapping
  #
  # The following config.vm.synced_folder settings will map directories in your Vagrant
  # virtual machine to directories on your local machine. Once these are mapped, any
  # changes made to the files in these directories will affect both the local and virtual
  # machine versions. Think of it as two different ways to access the same file. When the
  # virtual machine is destroyed with `vagrant destroy`, your files will remain in your local
  # environment.

  # /srv/config/
  #
  # If a server-conf directory exists in the same directory as your Vagrantfile,
  # a mapped directory inside the VM will be created that contains these files.
  # This directory is currently used to maintain various config files for php and
  # nginx as well as any pre-existing database files.
  config.vm.synced_folder "config/", "/srv/config"

  # /srv/www/
  #
  # If a www directory exists in the same directory as your Vagrantfile, a mapped directory
  # inside the VM will be created that acts as the default location for nginx sites. Put all
  # of your project files here that you want to access through the web server
  config.vm.synced_folder "www/", "/srv/www/", :owner => "www-data", :mount_options => [ "dmode=775", "fmode=774" ]
 
  # Provisioning
  #
  # Process one or more provisioning scripts depending on the existence of custom files.
  config.vm.provision :shell, :path => File.join( "provision", "provision.sh" )

  #provisioning for special env

  config.vm.synced_folder "database/", "/srv/database"

  if ENV['DV_MYSQL'] == 'yes'
    config.vm.provision :shell, :path => File.join( "provision", "mysql.sh" )
  end

  if ENV['DV_POSTGRES'] == 'yes'
    config.vm.provision :shell, :path => File.join( "provision", "postgres.sh" )
  end
    
end
