require 'chef/knife'

module KnifePlugins
  class SourceIngredientGit < Chef::Knife
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

    banner "knife source ingredient git"

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
      data_bag_name = 'git' # maybe set this via cmdline later
      artifacts = Hash.new
      # http://dlc.sun.com.edgesuite.net/git/4.2.8/SHA256SUMS
      base_url = 'https://code.google.com/p/msysgit/downloads/list?can=2&q=full+installer+official+git'
      # this one directs us, and I can't handle 302s yet
      # base_url = 'http://download.git.org/git/'
      download_page=Nokogiri::HTML(open(base_url,:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
      download_page.search(
        '//a[contains(text(),"exe")]/@href').map(&:value).map{|f|
        f =~ /=(.*)&can/ ; $1}.each do |package_filename|
        package_filename =~ /(\d+\.\d+\.\d+)\.?(\d?)/
        mmp_ver = $1
        if $2
          git_ver = mmp_ver + '.' + $2
          semantic_ver = mmp_ver + $2
        else
          semantic_ver = git_ver = mmp_ver
        end
        next if not Chef::VersionConstraint.new(">= 1.8.1").include? semantic_ver
        package_url = 'https://msysgit.googlecode.com/files/' + package_filename
        dbi_safe_ver = git_ver.gsub('.','_')
        arch = ['i386','x86_64']
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
        artifacts[dbi_name][:version] ||= git_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= os
        artifacts[dbi_name][:desc] ||= 'Git'
      end
      
      base_url = 'https://code.google.com/p/git-osx-installer/downloads/list?can=3&q=OS+X'
      # an alternative version:
      #base_url = 'http://sourceforge.net/projects/macosxgit/files/current/'
      download_page=Nokogiri::HTML(open(base_url,:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
      download_page.search('//a[contains(text(),"dmg")]/@href').map(&:value).map{|f|
        f =~ /=(.*)&can/ ; $1}.each do |package_filename|

        package_url = 'https://git-osx-installer.googlecode.com/files/' + package_filename
        package_filename =~ /(\d+\.\d+\.\d+)\.?(\d?)/
        mmp_ver = $1
        if $2
          git_ver = mmp_ver + '.' + $2
          semantic_ver = mmp_ver + $2
        else
          semantic_ver = git_ver = mmp_ver
        end
        next if not Chef::VersionConstraint.new(">= 1.8.12").include? semantic_ver
        dbi_safe_ver = git_ver.gsub('.','_')
        arch = ['i386','x86_64']
        os = {'osx' => ['10.6','10.7','10.8']}
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
        artifacts[dbi_name][:version] ||= git_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= os
        artifacts[dbi_name][:desc] ||= 'Git'
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
