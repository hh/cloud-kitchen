require 'chef/knife'

module KnifePlugins
  class SourceIngredientVim < Chef::Knife
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

    banner "knife source ingredient vim"

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
      data_bag_name = 'vim' # maybe set this via cmdline later
      artifacts = Hash.new
      # http://dlc.sun.com.edgesuite.net/vim/4.2.8/SHA256SUMS
      base_url = 'http://ftp.vim.org/pub/vim/pc/'
      # this one directs us, and I can't handle 302s yet
      # base_url = 'http://download.vim.org/vim/'
      download_page=Nokogiri::HTML(open(base_url))
      download_page.search(
        '//a[contains(text(),"exe")]/@href').map(&:value).select{|l|
        l !~ /sig/}.each do |package_filename|
        major_ver = package_filename.match(/(\d)(\d)/).captures.join('.')
        if package_filename.match(/_(\d+)\.exe/)
          minor_capture = $1
          minor_ver = minor_capture ? '.'+minor_capture : '' 
          vim_ver = major_ver +  minor_ver
          semantic_ver = vim_ver
        else
          vim_ver = major_ver
          semantic_ver = vim_ver + '.0'
        end
        # I only want 7.3.46 or higher
        next if not Chef::VersionConstraint.new(">= 7.3.46").include? semantic_ver
        dbi_safe_ver = vim_ver.gsub('.','_')
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
        artifacts[dbi_name][:version] ||= vim_ver
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= os
      end
      
      base_url = 'https://code.google.com/p/macvim/downloads/list'
      # an alternative version:
      #base_url = 'http://sourceforge.net/projects/macosxvim/files/current/'
      download_page=Nokogiri::HTML(open(base_url,:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
      download_page.search('//a[contains(text(),"MacVim-snapshot")]/@href').map(
        &:value).map{|f| f =~ /=(.*)&can/ ; $1}.each do |package_filename|
        package_url = 'https://macvim.googlecode.com/files/' + package_filename
        # the filenames are lame, which makes the versions lame
        # its just a snapshot, maybe we will look inside the repos 
        # at some point, just not now
        vim_ver = '0.0.' + package_filename.match(/(\d+)/).captures.first
        semantic_ver = vim_ver
        next if not Chef::VersionConstraint.new(">= 0.0.66").include? semantic_ver
        dbi_safe_ver = vim_ver.gsub('.','_')
        arch = ['x86_64','i386']
        os = {
          'osx' => [
            case package_filename
            when /Snow-Leopard/
              '10.6'
            when /Lion/
              '10.7'
            else
              '10.8'
            end
          ]
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
        artifacts[dbi_name][:version] ||= vim_ver
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
