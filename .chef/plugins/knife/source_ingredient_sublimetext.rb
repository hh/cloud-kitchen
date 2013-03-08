require 'chef/knife'

module KnifePlugins
  class SourceIngredientSublimetext < Chef::Knife
    include Chef::Mixin::Checksum

    deps do
      require 'chef/version_constraint'
      require 'chef/exceptions'
      require 'chef/search/query'
      require 'chef/shef/ext'
      require 'chef/mixin/checksum'
      require 'json'
      require 'open-uri'
      require 'net/https'
      require 'uri'
      require 'nokogiri'
      require 'fileutils'
    end

    banner "knife source ingredient sublimetext"

    def download_file(source,destination)
      puts "Downloading #{source} to #{destination}"
      uri = URI.parse source
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.class.to_s =~ /HTTPS/
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.start do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request request do |response|
          if response.response['Location']!=nil
            redirectURL=response.response['Location']
            puts "Redirect To: #{redirectURL}"
            download_file(redirectURL,destination)
          else
            open destination, 'wb' do |io|
              response.read_body do |chunk|
                io.write chunk
              end
            end
          end
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
      data_bag_name = 'sublimetext' # maybe set this via cmdline later
      artifacts = Hash.new
      # http://dlc.sun.com.edgesuite.net/sublimetext/4.2.8/SHA256SUMS
      base_url = 'http://www.sublimetext.com/2'
      # this one directs us, and I can't handle 302s yet
      # base_url = 'http://download.sublimetext.org/sublimetext/'
      download_page=Nokogiri::HTML(open(base_url))
      download_page.search('//a/@href').map(&:value).select{|h|
        h =~ /Sublime/ && h !~ /zip$/}.each do |package_url|
        package_filename = ::File.basename(package_url)
        sublimetext_ver = package_filename.match(/(\d+)\.(\d+)\.(\d+)/).captures.join('.')
        semantic_ver = sublimetext_ver
        # only get newer
        next if not Chef::VersionConstraint.new(">= 2.0.1").include? semantic_ver
        #next if package_filename =~ /(exe|bz2)/ && package_filename !~ /x64/
        dbi_safe_ver = sublimetext_ver.gsub('.','_')
        arch = 'x86_64'
        if package_filename =~ /(exe|bz2)/ && package_filename !~ /x64/
          arch = 'i386'
        end
        case package_filename[-3..-1]
        when 'dmg'
          osvers = {'osx' => [
              '10.6',
              '10.7',
              '10.8'
            ]}
          dbi_name = "osx_#{arch}_#{dbi_safe_ver}"
        when 'exe'
          osvers = {'windows' => ['2008r2','2012','7','8']}
          dbi_name = "windows_#{arch}_#{dbi_safe_ver}"
        else 'bz2'
          osvers = {
            "debian" => ["6"],
            "el" => ["5","6"],
            "sles" => ["11.2","12.1"],
            "ubuntu" => ["10.04","10.10","11.04","11.10","12.04","12.10"]
          }
          dbi_name = "linux_#{arch}_#{dbi_safe_ver}"
        end
        # Let's put the files in our cache... might be useful later 8)
        cached_packagefile = ::File.join(
          Chef::Config[:file_cache_path],package_filename)
        if not ::File.exists? cached_packagefile
          # we should probably try to compare to SHA256 or something
          download_file(package_url,cached_packagefile)
        end
        
        # New we have all the artifact details
        artifacts[dbi_name] ||= Hash.new
        artifacts[dbi_name][:source] ||= package_url
        artifacts[dbi_name][:filename] ||= package_filename
        artifacts[dbi_name][:arch] ||= arch
        artifacts[dbi_name][:checksum] ||= checksum(cached_packagefile)
        artifacts[dbi_name][:version] ||= sublimetext_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= osvers
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
