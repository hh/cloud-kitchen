name "fileserver"
description "Fileserver for Chef installer packages, Sublime Text 2 and more"

run_list "recipe[ii-fileserver]"#, "recipe[debmirror::precise]"

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
    }
  }
  )
