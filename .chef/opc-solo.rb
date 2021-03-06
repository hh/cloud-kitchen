current_dir = File.dirname(File.realdirpath(__FILE__))
puts "#{current_dir.to_s}"
cookbook_path "#{current_dir}/../cookbooks"
role_path     "#{current_dir}/../roles"
file_cache_path "#{current_dir}/../.cache"
data_bag_path "#{current_dir}/../data_bags"
cache_options({ :path => "#{current_dir}/../.checksums", :skip_expires => true })
knife[:current_dir] = current_dir

solo_json_file = "#{current_dir}/opc-solo.json"
open(solo_json_file,'w+') do |f|
  f.write(
    JSON.pretty_generate({
        "run_list" => [
          "chef-solo-search",
          "role[fog-lab]"
        ],
        'private_chef' => {
          'package_file' => "private-chef_1.4.4-1.ubuntu.11.04_amd64.deb",
          'package_temp_url' => 'http://ask.opscode.com/sales'
        },
        "model_chef" => {
          "lxc" => {"container" => "chef"}
        },
        "ntp" => {
          "servers" => ["time"]
      },
        "resolver" => {
          "search" => "training",
          "nameservers" => ["10.12.13.1"]
        }
      })
    )
end if not ::File.exists? solo_json_file
json_attribs solo_json_file
