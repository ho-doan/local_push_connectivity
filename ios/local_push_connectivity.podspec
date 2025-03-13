#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint local_push_connectivity.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'local_push_connectivity'
  s.version          = '0.0.4'
  s.summary          = 'a local network Apple Local Push Connectivity'
  s.description      = <<-DESC
a local network Apple Local Push Connectivity use TCP, Secure TCP, WS, WSS
                       DESC
  s.homepage         = 'https://github.com/ho-doan/local_push_connectivity'
  s.license          = { :type => 'BSD-3-Clause', :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'hodoan.it.dev@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'local_push_connectivity/Sources/local_push_connectivity/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'local_push_connectivity_privacy' => ['local_push_connectivity/Sources/local_push_connectivity/PrivacyInfo.xcprivacy']}
end
