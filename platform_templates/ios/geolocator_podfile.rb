# Add inside the existing `installer.pods_project.targets.each do |target|` block
# in ios/Podfile, after flutter_additional_ios_build_settings(target).
if target.name == 'geolocator_apple'
  target.build_configurations.each do |config|
    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
      '$(inherited)',
      'BYPASS_PERMISSION_LOCATION_ALWAYS=1'
    ]
  end
end
