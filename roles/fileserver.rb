name "fileserver"
description "Fileserver for Chef installer packages, Sublime Text 2 and more"

run_list "recipe[fileserver]"#, "recipe[debmirror::precise]"

default_attributes(
  "fileserver" => {
    "sublime" => {
      'osx' => {
        'filename' => "Sublime\ Text\ 2.0.1.dmg",
        'checksum' => "2fd9e50f1dd43813c9aaa1089f50690f3fe733bc5069339db01ebcaf18c6b736",
        'url' => "http://c758482.r82.cf2.rackcdn.com/Sublime%20Text%202.0.1.dmg"
      },
      'win32' => {
        'filename' => "Sublime\ Text\ 2.0.1\ Setup.exe",
        'checksum' => "6437659c4f3a533e87b2e29e75c22c4e223932e2b73145d1c493dbd32f2bdb72",
        'url' => "http://c758482.r82.cf2.rackcdn.com/Sublime%20Text%202.0.1%20Setup.exe"
      },
      'win64' => {
        'filename' => "Sublime\ Text\ 2.0.1\ x64\ Setup.exe",
        'checksum' => "2120732bcc511baa2737ff157c063129e7525642e3893fc3dc01041a3b8f9a4e",
        'url' => "http://c758482.r82.cf2.rackcdn.com/Sublime%20Text%202.0.1%20x64%20Setup.exe"
      },
      'linux32' => {
        'filename' => "Sublime\ Text\ 2.0.1.tar.bz2",
        'checksum' => "4e752da357fbaf41b74e45e2caaea5c07813216c273b6f8770abd5621daddbf4",
        'url' => "http://c758482.r82.cf2.rackcdn.com/Sublime%20Text%202.0.1.tar.bz2"
      },
      'linux64' => {
        'filename' => "Sublime\ Text\ 2.0.1\ x64.tar.bz2",
        'checksum' => "858df93325334b7c7ed75daac26c45107e0c7cd194d522b42a6ac69fae6de404",
        'url' => "http://c758482.r82.cf2.rackcdn.com/Sublime%20Text%202.0.1%20x64.tar.bz2"
      }
    },
    "chef_full" => {
      'version' => "10.16.2-1",
      'platforms' => {
        'ubuntu_32' => {
          'platform' => 'ubuntu',
          'platform_version' => '12.04',
          'machine' => 'i686',
          'checksum' => "fb30c261d0a3b09a5c9ed4b7e0c961d66e09b011510cc4d1411156b18eb8d249"
        },
        'ubuntu_64' => {
          'platform' => 'ubuntu',
          'platform_version' => '12.04',
          'machine' => 'x86_64',
          'checksum' => "52a9c858cf11d6d815e419906d7a7debf3460973d3967f9c0ff7a4f9fbac5afd"
        },
        'rhel6_32' => {
          'platform' => 'el',
          'platform_version' => '6',
          'machine' => 'i686',
          'checksum' => "ca4317b4e5e5ec6aae695fc32ca45ffb8e33d12c65aba4e037734ce18002535b"
        },
        'rhel6_64' => {
          'platform' => 'el',
          'platform_version' => '6',
          'machine' => 'x86_64',
          'checksum' => "badeaf57be1fffc367e5ae193544a4a5f1a363953713733e72c247d616d978a1"
        },
        'windows' => {
          'filename' => "chef-client-10.16.2-1.msi",
          'checksum' => "4a23a3dde22bbcc04be70d8592959d24c46a06a4339a74319f6ed7896057cfc5",
          'url' => "http://s3.amazonaws.com/opscode-full-stack/windows/chef-client-10.16.2-1.msi"
        },
        'osx_106' => {
          'platform' => 'mac_os_x',
          'platform_version' => '10.6',
          'machine' => 'x86_64',
          'filename' => "chef-10.16.2_1.mac_os_x.10.6.8.sh",
          'checksum' => "a98848a247d282604b1037c00954ba458e6a08a42a57cec09036072ed025c13a"
        },
        'osx_107' => {
          'platform' => 'mac_os_x',
          'platform_version' => '10.7',
          'machine' => 'x86_64',
          'filename' => "chef-10.16.2_1.mac_os_x.10.7.2.sh",
          'checksum' => "23b6416306c3179577c1e462ccc1ee69ae1c9bf9d032d9fa61f7efb4bf142b6c"
        }
      }
    }
  }
)
