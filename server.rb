#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'

set :bind, '0.0.0.0'

# Handle GET-request (Show the upload form)
get "/" do
  haml :upload
end

# Handle POST-request (Receive and save the uploaded file)
post "/" do
  unless (jobname  = params[:name]) &&
         (tempfile = params[:file][:tempfile]) &&
         (filename = params[:file][:filename])
    halt 422, JSON({
      message: "Validation failed",
      errors: "parameters missing. file and name parameters required."
    })
  end
  time = Time.now.strftime("%Y%m%d%H%M%S")
  dir = "/var/www/uploads/#{time}/#{jobname}"
  filepath = dir + "/#{filename}"
  FileUtils.mkdir_p(dir)
  FileUtils.cp(tempfile.path, filepath)
  output = `ruby jenkins-xml-to-jobdsl.rb #{filepath}`
  "#{output}"
end
