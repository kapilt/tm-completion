#!/usr/bin/env ruby -wKU

require File.dirname(__FILE__) + "/../lib/db"

ProjectPath = ARGV[0] + ((ARGV[0][-1] == ?/) ? '' : '/')
DbPath      = ProjectPath + DatabaseFilename
ParserPath  = File.dirname($0) + '/parsers/'

def update_database(path, items)
  # Functions
  run_query "DELETE FROM functions WHERE file = '#{e_sql path}';"
  items[:functions].each do |function|
    run_query "INSERT INTO functions (name, class, prototype, file) VALUES ('#{e_sql function['name']}', '#{e_sql function['class']}', '#{e_sql function['prototype']}', '#{e_sql path}');"
  end
  # Classes
  run_query "DELETE FROM classes WHERE file = '#{e_sql path}';"
  items[:classes].each do |klass|
    run_query "INSERT INTO classes (name, file) VALUES ('#{e_sql klass['name']}', '#{e_sql path}');"
  end
  # Variables
  run_query "DELETE FROM variables WHERE file = '#{e_sql path}';"
  items[:variables].each do |var|
    run_query "INSERT INTO variables (name, class, file) VALUES ('#{e_sql var['name']}', '#{e_sql var['class']}', '#{e_sql path}');"
  end
end

def create_schema
  run_query <<-SQL
    CREATE TABLE classes ('name' TEXT, 'file' TEXT);
    CREATE TABLE functions ('name' TEXT, 'class' TEXT, 'prototype' TEXT, 'file' TEXT);
    CREATE TABLE variables ('name' TEXT, 'class' TEXT, 'file' TEXT);
  SQL
end

create_schema unless database_exists?

Dir.chdir ProjectPath

@language_associations = {
  'php' => [/\.php$/, /\.inc$/],
}

def language_for(file)
  @language_associations.each_pair do |name, patterns|
    return name if patterns.find { |p| file =~ p }
  end
  nil
end

if ARGV[1] # Single file
  file_path = ARGV[1].project_relative_path
  if language = language_for(file_path)
    update_database file_path, parse_file(file_path, language)
    puts "Done!"
  else
    puts "Unknown file type"
  end
else
  require ENV['TM_SUPPORT_PATH'] + '/lib/progress'

  files = Dir['**/*']

  TextMate.call_with_progress(:title =>'Scanning…', :summary => 'Scanning Project Files...', :indeterminate => false, :cancel => lambda {puts "Canceled!"; exit 0} ) do |dialog|
    step = 100.0 / files.size.to_f
    progress = 0
    files.each do |script|
      dialog.parameters = {'summary' => "Parsing #{script}", 'progressValue' => progress}
      update_database script, parse_file(script)
      progress += step
    end
  end
end
