require 'chef/knife'

module KnifePlugins
  class SourceIngredientVirtualbox < Chef::Knife
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

    banner "knife source ingredient virtualbox"

    def download_file(source,destination)
      puts "Downloading #{source} to #{destination}"
      uri = URI.parse source
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request request do |response|
          if response.response['Location']!=nil
            redirectURL=response.response['Location']
            puts "#{redirectURL}***"
            # need to figure out how to handle redirects
            raise Error
          end
            
          open destination, 'wb' do |io|
            response.read_body do |chunk|
              io.write chunk
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
      data_bag_name = 'virtualbox' # maybe set this via cmdline later
      artifacts = Hash.new
      # http://dlc.sun.com.edgesuite.net/virtualbox/4.2.8/SHA256SUMS
      base_url = 'http://dlc.sun.com.edgesuite.net/virtualbox/'
      # this one directs us, and I can't handle 302s yet
      # base_url = 'http://download.virtualbox.org/virtualbox/'
      download_page=Nokogiri::HTML(open(base_url))
      download_page.search(
        '//a/img[contains(@alt,"DIR")]/..').select{|l|
        l['href'] =~ /\d+\.\d+\.\d+\/$/}.map{|v| v['href']}.each do |ver_url|
        virtualbox_ver = ::File.basename(ver_url.sub('/',''))
        semantic_ver = virtualbox_ver
        # I only want 4.2.8 or higher
        next if not Chef::VersionConstraint.new(">= 4.2.8").include? semantic_ver

        # we wants rhel 6, osx, windows, and recent ubuntus, the guest additions and extpack
        wants = %w{ el6 OSX Win precise quantal VBoxGuestAdditions Pack }
        # The formats we want... note lack of i386, i686, openSUSE, sles, fedora, SunOS
        # generic Linux, src SDK 
        formats = %w{ amd64 x86_64 exe iso dmg}
        formats << "#{virtualbox_ver}\\.vbox"
        # get the urls for all links that have a class starting with file
        package_urls = Nokogiri::HTML(open(base_url + ver_url)).search('//a'
          ).select do |l|
          l['href'] =~ /(#{wants.join('|')}).*(#{formats.join('|')})/
        end.map{ |l| l['href']}
        # populate our artifacts hash with info about this artifact source
        package_urls.each do |package_url|
          dbi_safe_ver = virtualbox_ver.gsub('.','_')
          package_filename = package_url
          package_url = base_url + ver_url + package_filename
          desc = 'VirtualBox'
          arch = case ::File.basename(package_filename)
                 when /(x86_64|amd64)/
                   'x86_64'
                 when /(i686|i586|i386)/
                   'i686'
                 else
                   ['i686','x86_64']
                 end
          case package_filename
          when %r{
                   (?<package_ver> \d+\.\d+\.\d+ ){0}
                   (?<build_num> \d+ ){0}
                   VirtualBox-\g<package_ver>-\g<build_num>-OSX\.dmg
                 }x
            package_ver = $1
            build_num = $2
            os = {
              'mac_os_x' => [
                '10.7',
                '10.8'
              ]
            }
            dbi_name = "osx_#{dbi_safe_ver}"
          when %r{
                   (?<package_ver> \d+\.\d+\.\d+ ){0}
                   (?<build_num> \d+ ){0}
                   VirtualBox-\g<package_ver>-\g<build_num>-Win\.exe
                 }x
            package_ver = $1
            build_num = $2
            os = {
              'windows' => [
                '2008r2',
                '2012',
                '7',
                '8'
              ]
            }
            dbi_name = "windows_#{dbi_safe_ver}"
          when %r{
                   (?<package_ver> \d+\.\d+\.\d+ ){0}
                   VBoxGuestAdditions_\g<package_ver>\.iso
                 }x
            os = {}
            dbi_name = "guestadditions_#{dbi_safe_ver}_iso"
            desc = 'VirtualBox Guest Additions ISO'
          when %r{
                   (?<package_ver> \d+\.\d+\.\d+ ){0}
                   Oracle_VM_VirtualBox_Extension_Pack-\g<package_ver>\.vbox-extpack
                 }x
            os = {}
            dbi_name = "extensionpack_#{dbi_safe_ver}"
            desc = 'VirtualBox Extension Pack'
          when %r{
                   (?<parch> (x86_64|i386) ){0}
                   (?<pver> \d+\.\d+\.\d+ ){0}
                   (?<distname> \w+ ){0}
                   (?<distrelease> \d+ ){0}
                   (?<build_num> \d+ ){0}
                   (?<osrev> \d+ ){0}
                 VirtualBox-\d+\.\d+-\g<pver>_\g<build_num>_\g<distname>\g<distrelease>-\g<osrev>\.\g<parch>\.rpm
                 }x
            distname = $3
            distrelease = $4
            osrev = $6
            os = {}
            os = {
              distname =>
              [
                distrelease
              ]
            }
            dbi_name = "#{distname}#{distrelease}_#{osrev}_#{arch}_#{dbi_safe_ver}"
          when %r{
                   (?<parch> (amd64|i386) ){0}
                   (?<pver> \d+\.\d+\.\d+ ){0}
                   (?<distname> \w+ ){0}
                   (?<build_num> \d+ ){0}
                 virtualbox-\d+\.\d+_\g<pver>-\g<build_num>~Ubuntu~\g<distname>_\g<parch>\.deb
                 }x
            pver = $1
            build_num = $2
            distname = $3
            os = {
              'ubuntu' =>
              [
                case distname
                when /precise/
                  '12.04'
                when /quantal/
                  '12.10'
                end
              ]
            }
            dbi_name = "ubuntu_#{distname}_#{arch}_#{dbi_safe_ver}_iso"
          else
            puts "XXX #{package_filename} not process"
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
          artifacts[dbi_name][:version] ||= virtualbox_ver
          artifacts[dbi_name][:semantic_version] ||= semantic_ver
          artifacts[dbi_name][:os] ||= os
          artifacts[dbi_name][:desc] ||= desc
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
