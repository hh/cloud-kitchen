name "fog-lab"
description "The machine that will run virtualization of everything else"

run_list(
  "recipe[apt]",
  "recipe[apt::cacher-ng]",
  "recipe[ntp]",
  "role[fileserver]",
  "recipe[ii-lxc]",
  "recipe[ii-chef-server::within-lxc]",
  "recipe[knife-workstation::firefox]", 
  "recipe[knife-workstation::packages]" # needed for mechanize used in create-training-containers
)


default_attributes(
  "ntp" => {
    "is_server" => true
  },
  "virtualization" => {
    "lxc" => {
      "network_link" => "lxcbr0"
    },
    "qemu" => {
      "vnc_listen" => "0.0.0.0"
    }
  }
)
