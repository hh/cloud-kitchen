name "workstation"
description "Used to identify 'knife' workstations, and set them up"
run_list(
  "role[base]",
  "recipe[ii-knife-workstation]"
)
default_attributes(
  workstation: {
    username: 'opscode',
    password: 'opscode'
    # if you want to increase size from default of 1024x768
    # geometry: '1280x1024' 
  }
)
