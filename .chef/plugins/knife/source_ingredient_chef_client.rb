require 'chef/knife'

module KnifePlugins
  class SourceIngredientChefClient < Chef::Knife
    include Chef::Mixin::Checksum

    deps do
      require 'json'
      require 'open-uri'
      require 'chef/version_constraint'
      require 'chef/mixin/checksum'
      require 'chef/exceptions'
      require 'net/https'
      require 'uri'
      require 'fileutils'
    end

    banner "knife source ingredient chef client"

    def download_file(source,destination)
      # cross platform SSL cert stuff on ruby gives me gas
      rootCA = '/etc/ssl/certs' # On ubuntu anyhow
      url = URI.parse source
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      if (File.directory?(rootCA) && http.use_ssl?)
        http.ca_path = rootCA
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_depth = 5
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
      end
      if not File.exists? destination
        puts "Downloading #{source} to #{destination}"
        open(destination,'wb') do |f|
          req = http.request_get(source)
          if req.code != '200'
            puts "Error downloading file: #{req.code} #{req.body}"
            exit 1
          end
          f.write(req.body)
          f.close
        end
      end
    end

    def run
      begin
        FileUtils.touch(File.join(Chef::Config[:data_bag_path],'.writeable'))
        FileUtils.touch(File.join(Chef::Config[:file_cache_path],'.writeable'))
      rescue
        puts "Set role_path and file_cache_path in knife.rb to somewhere writable"
        exit 1
      end
      data_bag_name = 'chef' # maybe set this via cmdline later
      chef_client_json_url = 'http://www.opscode.com/chef/full_list'
      base_url='https://opscode-omnitruck-release.s3.amazonaws.com'

      j=JSON.parse(open(chef_client_json_url).read)
      artifacts = Hash.new
      
      j.each do |os,val|
        val.each do |os_ver,val|
          val.each do |arch, val|
            val.each do |chef_ver, chef_url|
              # We could do this for all versions, but I only want newer stuff
              dotted_ver=chef_ver.split('-').first.split('.')
              next if dotted_ver[3] =~ /alpha/
              semantic_ver = dotted_ver[0..2].join('.')
              filename=File.basename(chef_url)
              if semantic_ver.start_with? '11'
                next if not Chef::VersionConstraint.new(">= 11.4.0").include? semantic_ver
              else
                next # I'm wanting to totally skip 10.X now
                next if not Chef::VersionConstraint.new(">= 10.24.0").include? semantic_ver
              end
              # I'm not interested in 32bit or sparc for now
              next if ['i686','i386','sparc'].include? arch

              # Let's put the files in our cache... might be useful later 8)
              cached_file = ::File.join(
                Chef::Config[:file_cache_path],filename)
              download_file(base_url+chef_url,cached_file)
              
              (fos,fosver,farch) = chef_url.split('/')[1..3]
              chef_dbver = chef_ver.gsub(/(\.|-)/,'_') 
              os_dbver = fosver.gsub(/(\.|-)/,'_') 
              dbi_name = "#{fos}_#{os_dbver}_#{farch}_#{chef_dbver}"
              artifacts[dbi_name] ||= Hash.new
              artifacts[dbi_name][:source] ||= base_url + chef_url
              artifacts[dbi_name][:filename] ||= filename
              artifacts[dbi_name][:arch] ||= arch
              artifacts[dbi_name][:checksum] ||= checksum(cached_file)
              artifacts[dbi_name][:version] ||= chef_ver
              artifacts[dbi_name][:desc] ||= "Chef Omnibus Client"
              artifacts[dbi_name][:os] ||= {os => [os_ver]}
              if not artifacts[dbi_name][:os].include? os
                artifacts[dbi_name][:os][os] = [os_ver]
              end
              if not artifacts[dbi_name][:os][os].include? os_ver
                artifacts[dbi_name][:os][os] << os_ver
              end
            end
          end
        end
      end
      
      #puts JSON.pretty_generate(artifacts)
      # Write out all data bag json
      data_bag_item_dir = ::File.join(Chef::Config[:data_bag_path],data_bag_name)
      Dir.mkdir data_bag_item_dir  unless File.exists? data_bag_item_dir
      artifacts.each do |dbi,data|
        open(::File.join(data_bag_item_dir,dbi+'.json'),'w') do |f|
            f.write JSON.pretty_generate({id: dbi}.merge(data))
            f.close
        end
      end
    end
  end
end
