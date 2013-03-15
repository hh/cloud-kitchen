require 'chef/knife'

module KnifePlugins
  class SourceIngredientVagrant < Chef::Knife
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

    banner "knife source ingredient vagrant"

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
      data_bag_name = 'vagrant' # maybe set this via cmdline later
      artifacts = Hash.new
      download_page=Nokogiri::HTML(open('http://downloads.vagrantup.com/'))
      download_page.search('//a[@class="tag"]').map{|n|
        n.attributes['href'].value}.each do |ver_url|
        vagrant_ver = ::File.basename(ver_url)
        semantic_ver = vagrant_ver[1..-1]
        # I only want 1.0.6 or higher
        next if not Chef::VersionConstraint.new(">= 1.0.6").include? semantic_ver

        # get the urls for all links that have a class starting with file
        package_urls = Nokogiri::HTML(open(ver_url)).search(
          '//a[@class]').select{|a|
          a['class'] =~ /^file/}.map{|a|
          a['href']}

        # populate our artifacts hash with info about this artifact source
        package_urls.each do |package_url|
          dbi_safe_ver = vagrant_ver.gsub('.','_')
          # the source files don't have unique names... let's fix that
          package_filename = ::File.basename(package_url).sub(
            'agrant',"agrant-#{vagrant_ver}")

          arch = case ::File.basename(package_url)
                 when /x86_64/
                   'x86_64'
                 when /i686/
                   'i686'
                 when /./
                   ['i686','x86_64']
                 end
          case ::File.basename(package_url).split('.').last
          when 'dmg'
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
          when 'deb'
            dbi_name = "ubuntu_#{arch}_#{dbi_safe_ver}"
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
              ]
            }
          when 'rpm'
            dbi_name = "el_#{arch}_#{dbi_safe_ver}"
            os = {
              'el' => [
                '5',
                '6'
              ],
              "sles" => [
                "11.2",
                "12.2"
              ]
            }
          when 'xz'
            next # skipping for now
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
          artifacts[dbi_name][:version] ||= vagrant_ver
          artifacts[dbi_name][:semantic_version] ||= semantic_ver
          artifacts[dbi_name][:os] ||= os
          artifacts[dbi_name][:desc] ||= "Vagrant"
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
