require 'chef/knife'

module KnifePlugins
  class SourceIngredientUbuntu < Chef::Knife
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

    banner "knife source ingredient ubuntu"

    def download_file(source,destination)
      uri = URI.parse source
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri.request_uri
        
        puts "Downloading #{source} to #{destination}"
        http.request request do |response|
          open destination, 'wb' do |io|
            response.read_body do |chunk|
              io.write chunk
            end
          end
        end
      end if not File.exists? destination
    end

    def run
      begin
        FileUtils.touch(File.join(Chef::Config[:data_bag_path],'.writeable'))
        FileUtils.touch(File.join(Chef::Config[:file_cache_path],'.writeable'))
      rescue
        puts "Set role_path and file_cache_path in knife.rb to somewhere writable"
        exit 1
      end
      # getting the following gets us urls
      # updating this with list of mirrors would be good... any takers?
      
      
      
      base_url = 'http://mirror.anl.gov/pub/ubuntu-iso/CDs/'
      data_bag_name = 'ubuntu' # maybe set this via cmdline later
      artifacts = Hash.new
      index_page=Nokogiri::HTML(open(base_url))
      index_page.search(
        '//a[contains(text(),"Ubuntu ")]').each do |dist_link|
        dist_link.text =~ /Ubuntu (\d+\.\d+\.?\d?)/
        version = $1
        if version.split('.').length == 2
          semantic_ver = version + '.0'
        else
          semantic_ver = version
        end
        lts = dist_link.text =~ /LTS/
        next if not Chef::VersionConstraint.new(">= 12.04.0").include? semantic_ver

        release_page=Nokogiri::HTML(open(base_url + dist_link['href']))
        release_page.search(
          # grabbing only 64bit
          '//a[contains(text(),"AMD64")]').select do |l|
          next if l.text =~ /alternate/
          # only grab mac compatible isos after 12.10
          if Chef::VersionConstraint.new(">= 12.10").include? semantic_ver
            next if l.text !~ /Mac/
          end
          h=l['href']
          # grabbing only .iso
          h[-3..-1] == 'iso'
        end.map do |l|
          #artifacts[l['href']]=true
          iso_url = l['href']
          iso_filename = ::File.basename iso_url
          cached_isofile = ::File.join(
            Chef::Config[:file_cache_path],iso_filename)
          download_file(base_url + dist_link['href'] + iso_url,cached_isofile)
          flavor = iso_filename =~ /server/ ? 'server' : 'desktop'
          dbi_name = "ubuntu_#{flavor}_#{semantic_ver.gsub('.','_')}"
          arch = case iso_filename
                 when /amd64/
                   'x86_64'
                 else
                   'i686'
                 end
          artifacts[dbi_name] ||= Hash.new
          artifacts[dbi_name][:source] ||= iso_url
          artifacts[dbi_name][:filename] ||= iso_filename
          artifacts[dbi_name][:arch] ||= arch
          artifacts[dbi_name][:checksum] ||= checksum(cached_isofile)
          artifacts[dbi_name][:version] ||= version
          artifacts[dbi_name][:semantic_version] ||= semantic_ver
          artifacts[dbi_name][:os] ||= {ubuntu: version, flavor: flavor}
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
