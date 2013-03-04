current_dir = ::File.dirname(::File.absolute_path(__FILE__))
cookbook_path "#{current_dir}/../cookbooks" #, "#{current_dir}/cookbooks"
role_path "#{current_dir}/../roles"
data_bag_path "#{current_dir}/../data_bags"

cache_type               'BasicFile'
file_cache_path "#{current_dir}/cache"
file_backup_path "#{ENV['HOME']}/.chef/backup"
cache_options( :path => "#{ENV['HOME']}/.chef/checksums")
verbose_logging false

solo_json_file = "#{current_dir}/create-usb-solo.json"
open(solo_json_file,'w+') do |f|
  f.write(
    {
      "run_list" => [
        "recipe[chef-solo-search]",
        "recipe[ii-chef-server::cache-files]",
        "recipe[ii-fileserver::cache-files]",
        "recipe[ii-usb::create-usb-solo]"
        ],
      'ii-usb' => {
        'src-chef-repo' => "#{current_dir}/..", # for now we'll just copy ourselves... I need to figure out caching
        'target-device' => ENV['TARGETUSB'], # We do this to force setting it at runtime
        'partition-size'=> '6000' 
      },
      'private_chef' => {
        'package_file' => "private-chef_1.4.4-1.ubuntu.11.04_amd64.deb",
        'package_temp_url' => 'ask opscode sales'
      }
    }.to_json
    )
end
json_attribs solo_json_file

