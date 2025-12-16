#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'CampusLink.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Files to add
files_to_add = [
  {
    path: 'CampusLink/Core/Models/PendingTransactionModels.swift',
    group_path: ['CampusLink', 'Core', 'Models']
  },
  {
    path: 'CampusLink/Features/Wallet/Views/AllPendingTransactionsView.swift',
    group_path: ['CampusLink', 'Features', 'Wallet', 'Views']
  },
  {
    path: 'CampusLink/Features/Wallet/Views/PendingTransactionDetailView.swift',
    group_path: ['CampusLink', 'Features', 'Wallet', 'Views']
  }
]

files_to_add.each do |file_info|
  file_path = file_info[:path]
  group_path = file_info[:group_path]
  
  # Find or create the group
  group = project.main_group
  group_path.each do |group_name|
    group = group.children.find { |g| g.display_name == group_name } || group.new_group(group_name)
  end
  
  # Add the file if it doesn't already exist
  unless group.children.any? { |child| child.path == File.basename(file_path) }
    file_ref = group.new_reference(file_path)
    target.add_file_references([file_ref])
    puts "Added #{file_path}"
  else
    puts "File #{file_path} already exists in project"
  end
end

project.save
puts "Project updated successfully!"
