#
# Be sure to run `pod lib lint JWTextView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'JWTextView'
  s.version          = '0.1.0'
  s.summary          = 'JWTextView is a UIView support text & image'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
refrence:
 #http://blog.devtang.com/2015/06/26/using-coretext-2/
 #http://blog.devtang.com/2015/06/26/using-coretext-1/
 If I have seen further, it is by standing on the shoulders of giants.
                       DESC

  s.homepage         = 'https://github.com/J0hnngWong/JWTextView'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'J0hnngWong' => 'wangjianing90@gmail.com' }
  s.source           = { :git => 'git@github.com:J0hnngWong/JWTextView.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'JWTextView/Classes/**/*'
  
  # s.resource_bundles = {
  #   'JWTextView' => ['JWTextView/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
