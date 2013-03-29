require 'chef/knife'

module KnifePlugins
  class SourceIngredientAzure < Chef::Knife
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

    banner "knife source ingredient azure"

    def download_file(source,destination)
      url = URI.parse source
      http = Net::HTTP.new(url.host, url.port)
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
        puts "Set data_bag_path and file_cache_path in knife.rb to somewhere writable"
        exit 1
      end
      data_bag_name = 'azure' # maybe set this via cmdline later
      artifacts = Hash.new
      @semantic_ver = '0.0.0' # this should be updated the firest time we process the msi or pkg
      download_page=Nokogiri::HTML(open('http://www.windowsazure.com/en-us/downloads/'))
      download_page.search(
        # just under cmd-line-tools, just above getting started, is the initial_url
        "//a[@id='cmd-line-tools']/../div/a[contains(text(),'Get started')]/preceding::a[1]/@href"
        ).map(&:value).each do |initial_url|

        # values.map{|u| Net::HTTP.get_response(URI(u)).header['location']} => [
        # "http://az412849.vo.msecnd.net/downloads01/azuresdk-cli-v0.6.13.msi", 
        # "http://az412849.vo.msecnd.net/downloads01/azuresdk-v0.6.13.pkg",
        # "http://az412849.vo.msecnd.net/downloads01/azure-2013-03.tar.gz"]     # Why no SEMVER here?

        package_url = Net::HTTP.get_response(URI(initial_url)).header['location']

        package_url =~ /(\d+\.\d+\.\d+)\.?(\d?)/
        if $1
          @semantic_ver = $1
        end
        
        package_filename = ::File.basename(package_url)
        azure_ver = semantic_ver = @semantic_ver
        next if not Chef::VersionConstraint.new(">= 0.6.13").include? semantic_ver

        dbi_safe_ver = azure_ver.gsub('.','_')
        # the source files don't have unique names... let's fix that
        # package_filename = ::File.basename(package_url).sub(
        #     'agrant',"agrant-#{azure_ver}")

        arch = 'x86_64'
        
        case ::File.basename(package_url).split('.').last
        when 'pkg'
          dbi_name = "osx_#{dbi_safe_ver}"
          os = {
              'mac_os_x' => [
              '10.7',
              '10.8'
            ]
          }
        when 'msi'
          dbi_name = "windows_#{dbi_safe_ver}"
          os = {
            'windows' => [
                '2008r2',
              '2012',
              '7',
              '8'
            ]
          }
        when 'gz'
          dbi_name = "linx_#{arch}_#{dbi_safe_ver}"
          os = {
            'ubuntu' => [
              '10.04',
              '10.10',
              "11.04",
              "11.10",
              "12.04",
              "12.10"
            ],
            "debian" => [
              "6"
            ],
            'el' => [
              '5',
              '6'
            ],
            "sles" => [
              "11.2",
              "12.2"
            ]
            
          }
        else
          next # skip for now
        end

        # Let's put the files in our cache... might be useful later 8)
        cached_packagefile = ::File.join(
          Chef::Config[:file_cache_path],package_filename)
        download_file(package_url,cached_packagefile)
        
        # New we have all the artifact details
        artifacts[dbi_name] ||= Hash.new
        artifacts[dbi_name][:source] ||= package_url
        artifacts[dbi_name][:filename] ||= package_filename
        artifacts[dbi_name][:arch] ||= arch
        artifacts[dbi_name][:checksum] ||= checksum(cached_packagefile)
        artifacts[dbi_name][:version] ||= azure_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= os
        artifacts[dbi_name][:desc] ||= "Azure"
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

