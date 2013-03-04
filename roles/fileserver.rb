name "fileserver"
description "Fileserver for Chef installer packages, Sublime Text 2 and more"

run_list "recipe[ii-fileserver]"#, "recipe[debmirror::precise]"

default_attributes(
)
