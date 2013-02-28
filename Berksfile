site :opscode

current_dir = File.dirname(File.realdirpath(__FILE__))
if File.exists?(File.join(current_dir,'..','..','Readme.dev.md'))
    # We are in our dev super-repo
    cookbooks_dir = File.join(current_dir,'../../cookbooks')
    cookbook 'ii-usb', path: "#{cookbooks_dir}/ii-usb"
    cookbook 'ii-ubiquity', path: "#{cookbooks_dir}/ii-ubiquity"
    cookbook 'ii-lxc', path: "#{cookbooks_dir}/ii-lxc"
    cookbook 'ii-knife-workstation', path: "#{cookbooks_dir}/ii-knife-workstation"
    cookbook 'ii-chef-server', path: "#{cookbooks_dir}/ii-chef-server"
    cookbook 'ii-fileserver', path: "#{cookbooks_dir}/ii-fileserver"
    cookbook 'debmirror', path: "#{cookbooks_dir}/debmirror"
else
    cookbook 'ii-usb', github: 'ii-cookbooks/ii-usb', ref: 'master'
    cookbook 'ii-ubiquity', github: 'ii-cookbooks/ii-ubiquity', ref: 'master'
    cookbook 'ii-lxc', github: 'ii-cookbooks/ii-lxc', ref: 'master'
    cookbook 'ii-knife-workstation', github: 'ii-cookbooks/ii-knife-workstation', ref: 'master'
    cookbook 'ii-chef-server', github: 'ii-cookbooks/ii-chef-server', ref: 'master'
    cookbook 'ii-fileserver', github: 'ii-cookbooks/ii-fileserver', ref: 'master'
    cookbook 'debmirror', github: 'hh-cookbooks/debmirror', ref: 'master'
    cookbook 'cd-tools', github: 'easybake-cookbooks/cd-tools', ref: 'master'
end

cookbook 'chef-solo-search', github: 'edelight/chef-solo-search', ref: 'master'

# we need to search local data bags!
cookbook 'apache2'
cookbook 'apt'
cookbook 'bluepill'
cookbook 'build-essential'
cookbook 'daemontools'
cookbook 'hosts'
cookbook 'ntp'
cookbook 'jenkins'
cookbook 'resolver'
cookbook 'runit'
cookbook 'ucspi-tcp'



# specifically for easybake.cd

cookbook '7-zip'
cookbook 'windows'
cookbook 'java'
cookbook 'gerrit'
cookbook 'foodcritic'
cookbook 'nodejs'
cookbook 'maven'
cookbook 'sqlite'
cookbook 'redisio'
cookbook 'metarepo'
