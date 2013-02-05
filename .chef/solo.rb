current_dir = File.dirname(File.realdirpath(__FILE__))
puts "#{current_dir.to_s}"
json_attribs  "#{current_dir}/solo.json"
cookbook_path "#{current_dir}/../cookbooks"
role_path     "#{current_dir}/../roles"
file_cache_path "#{current_dir}/../.cache"
data_bag_path "#{current_dir}/../data_bags"
cache_options({ :path => "#{current_dir}/../.checksums", :skip_expires => true })
knife[:current_dir] = current_dir
