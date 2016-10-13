require 'nokogiri'
require 'pp'

class MatrixAuthorizationNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "authorization {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'permission'
        if i.text.include? ":"
          p, u = i.text.split(":")
          puts " " * currentDepth + "permission(perm = '#{p}', user = '#{u}')"
        else
          pp i
        end
      else
        pp i
      end
    end 
    puts " " * depth + "}"
  end
end

class RebuildNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "rebuild {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'autoRebuild'
        puts " " * currentDepth + "autoRebuild(autorebuild = #{i.text})"
      when 'rebuildDisabled'
        puts " " * currentDepth + "rebuildDisabled(rebuilddisabled = #{i.text})"
      else
        pp i
      end
    end 
    puts " " * depth + "}"
  end
end

class WorkflowDiscarderNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    node.elements.each do |i|
     if i.attribute('class').value == 'hudson.tasks.LogRotator'
       puts " " * depth + "logRotator {"
       currentDepth = depth + indent
       i.elements.each do |p|
         case p.name
         when 'daysToKeep'
            puts " " * currentDepth + "daysToKeep(daystokeep = #{p.text})"
         when 'numToKeep'
            puts " " * currentDepth + "numToKeep(numtokeep = #{p.text})"
         when 'artifactDaysToKeep'
            puts " " * currentDepth + "artifactDaysToKeep(artifactdaystokeep = #{p.text})"
         when 'artifactNumToKeep'
            puts " " * currentDepth + "artifactNumToKeep(artifactnumtokeep = #{p.text})"
         else
           pp p
         end
       end
       puts " " * depth + "}"
     end
    end
  end
end

class ParametersNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "parameters {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'hudson.model.StringParameterDefinition'
        name = ""
        value = "null"
        description = "null"
        i.elements.each do |p|
          case p.name
          when "name"
            name = "#{p.text}"
          when "description"
            if "#{p.text}" != "null"
              description = "'#{p.text}'"
            else
              description = "null"
            end
          when "defaultValue"
            value = "#{p.text}"
            if "#{p.text}" != "null"
              value = "'#{p.text}'"
            else
              value = "null"
            end
          else
            pp p
          end
        end
        puts " " * currentDepth + "stringParam(parametername = '#{name}', defaultvalue = #{value}, description = #{description})" 
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class PropertiesNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "properties {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'com.sonyericsson.rebuild.RebuildSettings'
        RebuildNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.security.AuthorizationMatrixProperty'
        MatrixAuthorizationNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'org.jenkinsci.plugins.workflow.job.properties.BuildDiscarderProperty'
        WorkflowDiscarderNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.model.ParametersDefinitionProperty'
        i.elements.each do |p|
          case p.name
          when 'parameterDefinitions'
            ParametersNodeHandler.new(p).process(job_name, currentDepth, indent)
          else
            pp p
          end
        end
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class RemoteGitScmNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "remote {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'url'
        puts " " * currentDepth + "url('#{i.text}')"
      when 'credentialsId'
        puts " " * currentDepth + "credentials('#{i.text}')"
      else
        pp i.name
      end
    end 
    puts " " * depth + "}"
  end
end

class GitScmExtensionsNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "extensions {"
    currentDepth = depth + indent
    puts " " * depth + "}"
  end
end

class GitScmDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "git {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'configVersion'
      when 'userRemoteConfigs'
        i.elements.each do |j|
          case j.name
          when 'hudson.plugins.git.UserRemoteConfig'
            RemoteGitScmNodeHandler.new(j).process(job_name, currentDepth, indent)
          else
            pp j
          end
        end
      when 'branches'
        i.elements.each do |j|
          case j.name
          when 'hudson.plugins.git.BranchSpec'
            branches = "["
            j.elements.each do |b|
              branches += "'#{b.text}',"
            end
            branches[-1] = "]"
            puts " " * currentDepth + "branches(#{branches})"
          else
          end
        end
      when 'doGenerateSubmoduleConfigurations'
      when 'submoduleCfg'
      when 'extensions'
        GitScmExtensionsNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end 
    puts " " * depth + "}"
  end
end

class ScmDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "scm {"
    currentDepth = depth + indent
    if node.attribute('class').value == 'hudson.plugins.git.GitSCM'
      GitScmDefinitionNodeHandler.new(node).process(job_name, currentDepth, indent)
    else
      pp node
    end
    puts " " * depth + "}"
  end
end

class CpsScmDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "cpsScm {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'scm'
        ScmDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'scriptPath'
        puts " " * currentDepth + "scriptPath(scriptpath = '#{i.text}')"
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end



class DefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "definition {"
    currentDepth = depth + indent
    if node.attribute('class').value == 'org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition'
      CpsScmDefinitionNodeHandler.new(node).process(job_name, currentDepth, indent)
    else
      pp node
    end
    puts " " * depth + "}"
  end
end

class TriggerDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "triggers {"
    currentDepth = depth + indent
    puts " " * depth + "}"
  end
end

class FlowDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts "pipelineJob('#{job_name}') {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'actions'
      when 'description'
        puts " " * currentDepth + "description(desc = '#{i.text}')"
      when 'keepDependencies'
        puts " " * currentDepth + "keepDependencies(keep = #{i.text})"
      when 'properties'
        PropertiesNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'definition'
        DefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'triggers'
        TriggerDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'authToken'
        puts " " * currentDepth + "authenticationToken(token = '#{i.text}')"
      when 'concurrentBuild'
        puts " " * currentDepth + "concurrentBuild(allowconcurrentbuild = #{i.text})"
      else
        pp i
      end
    end
    puts "}"
  end
end

f = ARGV.shift
if !File.file?(f)
  exit 1
end
f = File.absolute_path(f)
d = File.dirname(f)
job = d.split("/")[-1]
depth = 0
indent = 4
Nokogiri::XML::Reader(File.open(f)).each do |node|
  if node.name == 'flow-definition' && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    FlowDefinitionNodeHandler.new(
      Nokogiri::XML(node.outer_xml).at('./flow-definition')
    ).process(job, depth, indent)
  end
  #pp node.name
end

