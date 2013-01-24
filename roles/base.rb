name "base"
description "Applied most VM roles"
run_list(
  "recipe[apt::cacher-client]",
  "recipe[apt]",
  "recipe[ntp]",
  "recipe[resolver]"
)

default_attributes(
  "ntp" => {
    "servers" => ["time"]
  },
  "resolver" => {
    "search" => "foglab",
    "nameservers" => ["10.12.13.1"]
  }
)
