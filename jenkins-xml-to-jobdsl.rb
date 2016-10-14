require 'nokogiri'
require 'pp'



class SvnScmLocationNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    currentDepth = depth + indent
    svnurl=''
    node.elements.each do |i|
      case i.name
      when 'credentialsId', 'depthOption', 'local', 'ignoreExternalsOption'
        # do nothing
      when 'remote'
        svnurl = "#{i.text}"
      else
        pp i
      end
    end
    puts " " * depth + "locations('#{svnurl}') {"
    node.elements.each do |i|
      case i.name
      when 'remote'
        # do nothing
      when 'credentialsId'
          puts " " * currentDepth + "credentials('#{i.text}')"
      when 'depthOption'
          puts " " * currentDepth + "depth(javaposse.jobdsl.dsl.helpers.scm.#{i.text.upcase})"
      when 'local'
          puts " " * currentDepth + "directory('#{i.text}')"
      when 'ignoreExternalsOption'
          puts " " * currentDepth + "ignoreExternals(#{i.text})"
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end



class SvnScmDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "svn {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'locations'
        i.elements.each do |j|
          case j.name
          when 'hudson.scm.SubversionSCM_-ModuleLocation'
            SvnScmLocationNodeHandler.new(j).process(job_name, currentDepth, indent)
          else
            pp j
          end
        end
      when 'excludedRegions', 'includedRegions', 'excludedUsers', 'excludedCommitMessages'
          if i.elements.any?
            patterns = "["
            i.elements.each do |p|
              patterns += "'#{p.text}',"
            end
            patterns[-1] = "]"
            puts " " * currentDepth + "#{i.name}(#{patterns})"
          end
      when 'excludedRevprop'
          puts " " * currentDepth + "excludedRevisionProperty('#{i.text}')"
      when 'workspaceUpdater'
          strategy = 'javaposse.jobdsl.dsl.helpers.scm.'
          case i.attribute('class').value
          when 'hudson.scm.subversion.UpdateUpdater'
            strategy += 'UPDATE'
          when 'hudson.scm.subversion.CheckoutUpdater'
            strategy += 'CHECKOUT'
          when 'hudson.scm.subversion.UpdateWithCleanUpdater'
            strategy += 'UPDATE_WITH_CLEAN'
          when 'hudson.scm.subversion.UpdateWithRevertUpdater'
            strategy += 'UPDATE_WITH_REVERT'
          else
            pp i
          end
          puts " " * currentDepth + "checkoutStrategy(#{strategy})"
      when 'ignoreDirPropChanges', 'filterChangelog'
          # todo: figure out how to merge these into a configure {} block, since they aren't full supported yet
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end



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
      when 'autoRebuild', 'rebuildDisabled'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class BuildDiscarderNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    node.elements.each do |i|
     if i.attribute('class').value == 'hudson.tasks.LogRotator'
       puts " " * depth + "logRotator {"
       currentDepth = depth + indent
       i.elements.each do |p|
         case p.name
         when 'daysToKeep', 'numToKeep', 'artifactDaysToKeep', 'artifactNumToKeep'
            puts " " * currentDepth + "#{p.name}(#{p.text})"
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
        BuildDiscarderNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.model.ParametersDefinitionProperty'
        i.elements.each do |p|
          case p.name
          when 'parameterDefinitions'
            ParametersNodeHandler.new(p).process(job_name, currentDepth, indent)
          else
            pp p
          end
        end
      when 'jenkins.model.BuildDiscarderProperty'
        BuildDiscarderNodeHandler.new(i).process(job_name, currentDepth, indent)
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
      when 'doGenerateSubmoduleConfigurations', 'submoduleCfg', 'configVersion'
        # todo: not yet implemented
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
    elsif node.attribute('class').value == 'hudson.scm.SubversionSCM'
      SvnScmDefinitionNodeHandler.new(node).process(job_name, currentDepth, indent)
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

class CpsDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "cps {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'script'
        puts " " * currentDepth + "scriptPath(scriptpath = \"\"\"\n#{i.text}\n\"\"\"\n)"
      when 'sandbox'
        puts " " * currentDepth + "sandbox(#{i.text})"
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
    elsif node.attribute('class').value == 'org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition'
      CpsDefinitionNodeHandler.new(node).process(job_name, currentDepth, indent)
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

class PostBuildTaskNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "postBuildTask {"
    currentDepth = depth + indent
    pp node
    puts " " * depth + "}"
  end
end

class PublishersNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "publishers {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'hudson.plugins.postbuildtask.PostbuildTask'
        PostBuildTaskNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class GoalsNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    node.children.each do |i|
      puts " " * depth + "goals('#{i.text}')"
    end
  end
end

class ArtifactNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "artifact {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'groupId', 'artifactId'
        puts " " * currentDepth + "#{i.name}('#{i.text}')"
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class MavenDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts "mavenJob('#{job_name}') {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'actions', 'reporters', 'buildWrappers', 'prebuilders', 'postbuilders',
           'aggregatorStyleBuild', 'ignoreUpstremChanges', 'processPlugins', 'mavenValidationLevel'
        # todo: not yet implemented
      when 'description'
        puts " " * currentDepth + "description(desc = '#{i.text}')"
      when 'properties'
        PropertiesNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'definition'
        DefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'triggers'
        TriggerDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'authToken'
        puts " " * currentDepth + "authenticationToken(token = '#{i.text}')"
      when 'concurrentBuild', 'disabled', 'fingerprintingDisabled', 'keepDependencies', 'runHeadless',
           'resolveDependencies', 'siteArchivingDisabled', 'archivingDisabled', 'incrementalBuild'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
      when 'goals'
        GoalsNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'publishers'
        PublishersNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'scm'
        ScmDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'canRoam', 'assignedNode'
        if i.name == 'canRoam' and i.text == 'true'
          puts " " * currentDepth + "label()"
        elsif i.name == 'assignedNode'
          puts " " * currentDepth + "label('#{i.text}')"
        end
      when 'blockBuildWhenDownstreamBuilding'
        if i.text == 'true'
          puts " " * currentDepth + "blockOnDownstreamProjects()"
        end
      when 'blockBuildWhenUpstreamBuilding'
        if i.text == 'true'
          puts " " * currentDepth + "blockOnUpstreamProjects()"
        end
      when 'disableTriggerDownstreamProjects'
        puts " " * currentDepth + "disableDownstreamTrigger(#{i.text})"
      when 'blockTriggerWhenBuilding'
        # todo: do this when jobdsl supports it
      when 'settings', 'globalSettings'
        puts " " * currentDepth + "#{i.name}(class: '#{i.attribute('class').value}')"
      when 'rootModule'
        ArtifactNodeHandler.new(i).process(job_name, currentDepth, indent)
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
  elsif node.name == 'maven2-moduleset' && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    MavenDefinitionNodeHandler.new(
      Nokogiri::XML(node.outer_xml).at('./maven2-moduleset')
    ).process(job, depth, indent)
  end
  #pp node.name
end

