name "workstation"
description "Used to identify 'knife' workstations, and set them up"
run_list(
  "role[base]",
  "recipe[ii-knife-workstation]"
)
