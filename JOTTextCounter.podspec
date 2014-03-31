Pod::Spec.new do |s|
  s.name             = "JOTTextCounter"
  s.version          = "1.0.0"
  s.summary          = "JOTTextCounter is an NSString-based text counter designed for use with UITextView/NSTextStorage on iOS."
  s.description      = <<-DESC
                        JOTTextCounter is an NSString-based text counter designed for use with UITextView/NSTextStorage on iOS.
                       DESC
  s.homepage         = "http://github.com/boscojwho/JOTTextCounter"
  s.license          = 'MIT'
  s.author           = { "J.w. Bosco Ho" => "boscojwho@gmail.com" }
  s.source           = { :git => "https://github.com/boscojwho/JOTTextCounter.git", :tag => "v1.0.0" }
  s.social_media_url = 'https://twitter.com/boscojwho'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'JOTTextCounter/*'

  s.ios.exclude_files = 'Classes/osx'
  s.osx.exclude_files = 'Classes/ios'
end