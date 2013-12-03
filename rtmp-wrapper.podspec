Pod::Spec.new do |s|
  s.name     = 'rtmp-wrapper'
  s.version  = '1.0.0'
  s.license  = 'MIT'
  s.summary  = 'librtmp wrapper library for IOS'
  s.homepage = 'https://github.com/ifactorylab/rtmp-wrapper'
  s.authors  = { 'Min Kim' => 'minsikzzang@gmail.com' }
  s.source   = { :git => 'git@github.com:ifactorylab/rtmp-wrapper.git', :tag => "1.0.0", :submodules => true }
  s.requires_arc = false
  
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'

  s.public_header_files = 'rtmp-wrapper/RtmpWrapper.h' 
  s.source_files = 'rtmp-wrapper/{*}.{h,m}'
  
  s.dependency = 'librtmp-iOS'
end