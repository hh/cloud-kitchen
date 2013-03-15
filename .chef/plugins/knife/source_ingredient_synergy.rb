require 'chef/knife'

module KnifePlugins
  class SourceIngredientSynergy < Chef::Knife
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

    banner "knife source ingredient synergy"

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
        puts "Set data_bag_path and file_cache_path in knife.rb to somewhere writable"
        exit 1
      end
      data_bag_name = 'synergy' # maybe set this via cmdline later
      artifacts = Hash.new
      base_url = 'https://code.google.com/p/synergy/downloads/list'
      # this one directs us, and I can't handle 302s yet
      # base_url = 'http://download.Synergy.org/Synergy/'
      download_page=Nokogiri::HTML(open(base_url,:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
      # I'm only grabbing 64 bit versions
      download_page.search(
        '//a[contains(text(),"64")]/@href').map(&:value).map{|f|
        f =~ /=(.*)&can/ ; $1}.each do |package_filename|
        arch = 'x86_64'
        package_filename =~ /(\d+\.\d+\.\d+)/
        synergy_ver = $1
        semantic_ver = synergy_ver

        case package_filename
        when /Windows/
          os = {
            'windows' => [
              '2008r2',
              '2012',
              '7',
              '8'
            ]
          }
          flavor = 'windows'
        when /MacOSX(\d+)/
          os_ver = "#{$1[0..1]}.#{$1[2]}"
          os = {'osx' => [os_ver]}
          flavor = "osx_#{$1}"
        when /Linux.*rpm/
          os = {
            "el" => ["5","6"],
            "sles" => ["11.2","12.1"]
          }
          flavor = 'linux_rpm'
        when /Linux.*deb/
          os = {
            "debian" => ["6"],
            "ubuntu" => ["10.04","10.10","11.04","11.10","12.04","12.10"]
          }
          flavor = 'linux_deb'
        end

        next if not Chef::VersionConstraint.new(">= 1.4.10").include? semantic_ver

        package_url = 'https://synergy.googlecode.com/files/' + package_filename
        dbi_safe_ver = synergy_ver.gsub('.','_')
        dbi_name = "synergy_#{dbi_safe_ver}_#{flavor}_#{arch}"
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
        artifacts[dbi_name][:version] ||= synergy_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= os
        artifacts[dbi_name][:desc] ||= 'Synergy'
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
