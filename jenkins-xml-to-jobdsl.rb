require 'nokogiri'
require 'pp'
require 'optparse'

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

class LogRotatorNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "logRotator {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'daysToKeep', 'numToKeep', 'artifactDaysToKeep', 'artifactNumToKeep'
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
    currentDepth = depth
    node.elements.each do |i|
     if i.attribute('class')&.value == 'hudson.tasks.LogRotator'
       LogRotatorNodeHandler.new(i).process(job_name, currentDepth, indent)
     else
       pp i
     end
    end
  end
end

class ParametersNodeHandler < Struct.new(:node)
  def nvd(i)
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
      when 'choices'
        if p.attribute('class').value == 'java.util.Arrays$ArrayList'
          value = "["
          p.elements.each do |k|
            case k.name
            when 'a'
              if k.attribute('class').value == 'string-array'
                k.elements.each do |s|
                  value += "'#{s.text}',"
                end
                value.chomp!(',')
              end
            else
              pp k
            end
          end
          value += "]"
        else
          pp p
        end
      else
        pp p
      end
    end
    return name, value, description
  end

  def process(job_name, depth, indent)
    puts " " * depth + "parameters {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'hudson.model.StringParameterDefinition'
        name, value, description = nvd(i)
        puts " " * currentDepth + "stringParam('#{name}', #{value}, #{description})"
      when 'hudson.model.BooleanParameterDefinition'
        name, value, description = nvd(i)
        puts " " * currentDepth + "booleanParam('#{name}', #{value}, #{description})"
      when 'hudson.model.ChoiceParameterDefinition'
        name, value, description = nvd(i)
        puts " " * currentDepth + "choiceParam('#{name}', #{value}, #{description})"
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
      when 'browser'
        puts " " * currentDepth + "browser {"
        if i.attribute('class').value == 'hudson.plugins.git.browser.Stash'
          puts " " * (currentDepth + indent) + "stash('#{i.at_xpath('//browser/url')&.text}')"
        else
          pp i
        end
        puts " " * currentDepth + "}"
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
    elsif node.attribute('class').value == 'hudson.scm.NullSCM'
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
        puts " " * currentDepth + "scriptPath(scriptpath = \"\"\"\\\n#{i.text}\n\"\"\"\n)"
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
        if !(i.text.nil? || i.text.empty?)
          puts " " * currentDepth + "#{i.name}('#{i.text}')"
        end
      when 'keepDependencies', 'quietPeriod'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
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
      when 'logRotator'
        LogRotatorNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    puts "}"
  end
end



class TaskPropertiesHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    logText = node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/logTexts/hudson.plugins.postbuildtask.LogProperties/logText')&.text
    script = node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/script')&.text
    escalate = node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/EscalateStatus')&.text
    runIfSuccessful = node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/RunIfJobSuccessful')&.text
    puts " " * depth + "task('#{logText}',\"\"\"\\\n#{script}\n\"\"\",#{escalate},#{runIfSuccessful})"
  end
end

class TasksNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    currentDepth = depth
    node.elements.each do |i|
      case i.name
      when 'hudson.plugins.postbuildtask.TaskProperties'
        TaskPropertiesHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
  end
end

class PostBuildTaskNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "postbuildtask {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'tasks'
        TasksNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class ArchiverNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "archiveArtifacts {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'artifacts'
        puts " " * currentDepth + "pattern('#{i.text}')"
      when 'allowEmptyArchive'
        puts " " * currentDepth + "allowEmpty(#{i.text})"
      when 'onlyIfSuccessful', 'fingerprint', 'defaultExcludes'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
      when 'caseSensitive'
        #unsupported
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class SonarNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "sonar {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'branch'
        puts " " * currentDepth + "#{i.name}('#{i.text}')"
      when 'mavenOpts', 'jobAdditionalProperties', 'settings', 'globalSettings', 'usePrivateRepository'
        # unsupported
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class ExtendedEmailNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "extendedEmail {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'saveOutput'
        puts " " * currentDepth + "saveToWorkspace(#{i.text})"
      when 'replyTo'
        puts " " * currentDepth + "replyToList('#{i.text}')"
      when 'recipientList', 'contentType', 'defaultSubject', 'presendScript'
        puts " " * currentDepth + "#{i.name}('#{i.text}')"
      when 'defaultContent'
        puts " " * currentDepth + "#{i.name}('''\\\n#{i.text}\n''')"
      when 'attachBuildLog', 'compressBuildLog', 'disabled'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
      when 'attachmentsPattern'
        # unsupported
      when 'configuredTriggers'
        puts " " * currentDepth + "triggers {"
        i.elements.each do |j|
          case j.name
          when 'hudson.plugins.emailext.plugins.trigger.SuccessTrigger'
            puts " " * (currentDepth + indent) + "success {"
            j.elements.each do |k|
              case k.name
              when 'email'
                k.elements.each do |e|
                  case e.name
                  when 'attachmentsPattern'
                    puts " " * (currentDepth + indent * 2) + "attachmentPattern('#{e.text}')"
                  when 'subject', 'recipientList', 'contentType'
                    puts " " * (currentDepth + indent * 2) + "#{e.name}('#{e.text}')"
                  when 'replyTo'
                    puts " " * (currentDepth + indent * 2) + "replyToList('#{e.text}')"
                  when 'compressBuildLog', 'attachBuildLog'
                    puts " " * (currentDepth + indent * 2) + "#{e.name}(#{e.text})"
                  when 'recipientProviders'
                    # unsupported
                  when 'body'
                    puts " " * (currentDepth + indent * 2) + "content('''\\\n#{e.text}\n''')"
                  else
                    pp e
                  end
                end
              else
                pp k
              end
            end
            puts " " * (currentDepth + indent) + "}"
          else
            pp j
          end
        end
        puts " " * currentDepth + "}"
      else
        pp i
      end
    end
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
      when 'hudson.tasks.ArtifactArchiver'
        ArchiverNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'org.jenkinsci.plugins.stashNotifier.StashNotifier'
        puts " " * currentDepth + "stashNotifier()"
      when 'hudson.plugins.sonar.SonarPublisher'
        SonarNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.plugins.emailext.ExtendedEmailPublisher'
        ExtendedEmailNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.tasks.BuildTrigger'
        projects = "['#{i.at_xpath('//hudson.tasks.BuildTrigger/childProjects')&.text}']"
        threshold = "'#{i.at_xpath('//hudson.tasks.BuildTrigger/threshold/name')&.text}'"
        puts " " * currentDepth + "downstream(#{projects}, #{threshold})"
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

class BlockNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "block {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'buildStepFailureThreshold', 'unstableThreshold', 'failureThreshold'
        puts " " * currentDepth + "#{i.name} {"
        i.elements.each do |j|
          case j.name
          when 'name', 'color'
            puts " " * (currentDepth + indent) + "#{j.name}('#{j.text}')"
          when 'ordinal', 'completeBuild'
            puts " " * (currentDepth + indent) + "#{j.name}(#{j.text})"
          else
              pp j
          end
        end
        puts " " * currentDepth + "}"
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class TriggerNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    projects = node.at_xpath('//configs/*/projects')&.text.split(',').map{|s|"'#{s}'"}.join(',')
    puts " " * depth + "trigger([#{projects}]) {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'configs'
        i.elements.each do |j|
          case j.name
          when 'hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig'
            j.elements.each do |k|
              case k.name
              when 'configs', 'projects'
                # intentionally ignored
              when 'condition'
                puts " " * currentDepth + "#{k.name}('#{k.text}')"
              when 'triggerWithNoParameters', 'buildAllNodesWithLabel'
                puts " " * currentDepth + "#{k.name}(#{k.text})"
              when 'block'
                puts " " * currentDepth + "configs {"
                BlockNodeHandler.new(k).process(job_name, currentDepth + indent, indent)
                puts " " * currentDepth + "}"
              else
                pp k
              end
            end
          else
            pp j.name
          end
        end
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class BuildersNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    currentDepth = depth
    node.elements.each do |i|
      case i.name
      when 'hudson.plugins.parameterizedtrigger.TriggerBuilder'
        TriggerNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.tasks.Shell'
        puts " " * currentDepth + "step {"
        puts " " * (currentDepth + indent) + "shell('''\\\n#{i.at_xpath('//hudson.tasks.Shell/command')&.text}\n''')"
        puts " " * currentDepth + "}"
      else
        pp i
      end
    end
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
        puts " " * currentDepth + "#{i.name}('#{i.text}')"
      when 'properties'
        PropertiesNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'definition'
        DefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'triggers'
        TriggerDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'authToken'
        puts " " * currentDepth + "authenticationToken(token = '#{i.text}')"
      when 'keepDependencies', 'concurrentBuild', 'disabled', 'fingerprintingDisabled',
           'runHeadless', 'resolveDependencies', 'siteArchivingDisabled', 'archivingDisabled',
           'incrementalBuild', 'quietPeriod'
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
      when 'runPostStepsIfResult'
        puts " " * currentDepth + "postBuildSteps('#{i.at_xpath('//runPostStepsIfResult/name')&.text}') {"
        puts " " * currentDepth + "}"
      else
        pp i
      end
    end
    puts "}"
  end
end

class FreestyleDefinitionNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts "freeStyleJob('#{job_name}') {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'actions', 'buildWrappers'
        # todo: not yet implemented
      when 'description'
        puts " " * currentDepth + "#{i.name}('#{i.text}')"
      when 'keepDependencies', 'quietPeriod'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
      when 'properties'
        PropertiesNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'scm'
        ScmDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'canRoam', 'assignedNode'
        if i.name == 'canRoam' and i.text == 'true'
          puts " " * currentDepth + "label()"
        elsif i.name == 'assignedNode'
          puts " " * currentDepth + "label('#{i.text}')"
        end
#      when 'keepDependencies', 'concurrentBuild', 'disabled', 'fingerprintingDisabled',
#     'runHeadless', 'resolveDependencies', 'siteArchivingDisabled', 'archivingDisabled', 'incrementalBuild'
      when 'disabled', 'concurrentBuild'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
      when 'blockBuildWhenDownstreamBuilding'
        if i.text == 'true'
          puts " " * currentDepth + "blockOnDownstreamProjects()"
        end
      when 'blockBuildWhenUpstreamBuilding'
        if i.text == 'true'
          puts " " * currentDepth + "blockOnUpstreamProjects()"
        end
      when 'triggers'
        TriggerDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'publishers'
        PublishersNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'builders'
        BuildersNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    puts "}"
  end
end

depth = 0
indent = 4

OptionParser.new do |opts|
  opts.banner = "Usage: ruby jenkins-xml-to-jobdsl.rb [OPTIONS] path/to/config.xml"

  opts.on(
    "-i indentation_level",
    "--indent=indentation_level",
    "Indentation level (default 4)",
  ) do |indentation_level|
    indent = indentation_level.to_i || 4
  end
end.parse!

f = ARGV.shift
if !File.file?(f)
  exit 1
end

f = File.absolute_path(f)
d = File.dirname(f)
job = d.split("/")[-1]
Nokogiri::XML::Reader(File.open(f)).each do |node|
  if node.name == 'flow-definition' && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    FlowDefinitionNodeHandler.new(
      Nokogiri::XML(node.outer_xml).at('./flow-definition')
    ).process(job, depth, indent)
  elsif node.name == 'maven2-moduleset' && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    MavenDefinitionNodeHandler.new(
      Nokogiri::XML(node.outer_xml).at('./maven2-moduleset')
    ).process(job, depth, indent)
  elsif node.name == 'project' && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    FreestyleDefinitionNodeHandler.new(
      Nokogiri::XML(node.outer_xml).at('./project')
    ).process(job, depth, indent)
  else
    #pp node
  end
end

