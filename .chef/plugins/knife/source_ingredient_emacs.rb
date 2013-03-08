require 'chef/knife'

module KnifePlugins
  class SourceIngredientEmacs < Chef::Knife
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

    banner "knife source ingredient emacs"

    def download_file(source,destination)
      puts "Downloading #{source} to #{destination}"
      uri = URI.parse source
      Net::HTTP.start(uri.host, uri.port) do |http|
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
      data_bag_name = 'emacs' # maybe set this via cmdline later
      artifacts = Hash.new
      # http://dlc.sun.com.edgesuite.net/emacs/4.2.8/SHA256SUMS
      base_url = 'http://mirrors.kernel.org/gnu/emacs/windows/'
      # this one directs us, and I can't handle 302s yet
      # base_url = 'http://download.emacs.org/emacs/'
      download_page=Nokogiri::HTML(open(base_url))
      download_page.search(
        '//a[contains(text(),"-bin-i386.zip")]/@href').map(&:value).select{|l|
        l !~ /sig/}.each do |package_filename|
        emacs_ver = package_filename.match(/(\d+\.\d+)/).captures.first
        semantic_ver = emacs_ver + '.0' # not really semantic so for
        # I only want 24.2 or higher
        next if not Chef::VersionConstraint.new(">= 24.2.0").include? semantic_ver
        dbi_safe_ver = emacs_ver.gsub('.','_')
        package_url = base_url + package_filename
        arch = 'i386'
        os = {
          'windows' => [
            '2008r2',
            '2012',
            '7',
            '8'
          ]
        }
        dbi_name = "windows_#{dbi_safe_ver}"
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
        artifacts[dbi_name][:version] ||= emacs_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= os
      end
      
      base_url = 'http://emacsformacosx.com'
      # this one directs us, and I can't handle 302s yet
      # base_url = 'http://download.emacs.org/emacs/'
      download_page=Nokogiri::HTML(open(base_url + '/builds'))
      download_page.search('//a').select{|a|
        a['href'] =~ /Emacs-\d+\.\d+-/}
        .map{|a|a['href']}.each do |package_url|
        package_url = base_url + package_url
        package_filename = ::File.basename(package_url)
        emacs_ver = package_filename.match(/(\d+\.\d+)/).captures.first
        semantic_ver = emacs_ver + '.0' # not really semantic so for
        # I only want 24.2 or higher
        next if not Chef::VersionConstraint.new(">= 24.2.0").include? semantic_ver
        dbi_safe_ver = emacs_ver.gsub('.','_')
        arch = ['x86_64','i386']
        os = {
          'osx' => [
            '10.6',
            '10.7',
            '10.8'          ]
        }
        dbi_name = "osx_#{dbi_safe_ver}"
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
        artifacts[dbi_name][:version] ||= emacs_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= os
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
