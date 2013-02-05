current_dir = ::File.dirname(::File.absolute_path(__FILE__))
cookbook_path "#{current_dir}/../cookbooks" #, "#{current_dir}/cookbooks"
role_path "#{current_dir}/../roles"

solo_json_file = "#{current_dir}/create-usb-solo.json"
open(solo_json_file,'w+') do |f|
  f.write(
    {
      "run_list" => [
        "recipe[ii-usb::create-usb-solo]"
        ],
      'ii-usb' => {
        'src-chef-repo' => "#{current_dir}/..", # for now we'll just copy ourselves... I need to figure out caching
        'target-device' => ENV['TARGETUSB'] # We do this to force setting it at runtime
      }
    }.to_json
    )
end
json_attribs solo_json_file

cache_type               'BasicFile'
file_cache_path "#{current_dir}/cache"
file_backup_path "#{ENV['HOME']}/.chef/backup"
cache_options( :path => "#{ENV['HOME']}/.chef/checksums")
verbose_logging false
