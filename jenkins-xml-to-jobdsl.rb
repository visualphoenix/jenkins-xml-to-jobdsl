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
    puts " " * depth + "location('#{svnurl}') {"
    node.elements.each do |i|
      case i.name
      when 'remote'
        # do nothing
      when 'credentialsId'
          puts " " * currentDepth + "credentials('#{i.text}')"
      when 'depthOption'
          puts " " * currentDepth + "depth(javaposse.jobdsl.dsl.helpers.scm.SvnDepth.#{i.text.upcase})"
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
          strategy = 'javaposse.jobdsl.dsl.helpers.scm.SvnCheckoutStrategy.'
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
        if (!p.text.to_s.strip.empty? && "#{p.text}" != "null")
          description = "'''#{p.text}'''"
        else
          description = "null"
        end
      when "defaultValue"
        value = "#{p.text}"
        if (!p.text.to_s.strip.empty? && ("#{p.text}" == "true" || "#{p.text}" == "false"))
          value = "#{p.text}"
        elsif (!p.text.to_s.strip.empty? && "#{p.text}" != "null")
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
    param_block = []
    param_block << " " * depth + "parameters {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'com.seitenbau.jenkins.plugins.dynamicparameter.ChoiceParameterDefinition',
           'hudson.plugins.jira.versionparameter.JiraVersionParameterDefinition'
        # these cannot be defined in this scope. Have to be defined on /properties.
      when 'hudson.model.TextParameterDefinition'
        name, value, description = nvd(i)
        param_block << " " * currentDepth + "textParam('#{name}', #{value}, #{description})"
      when 'hudson.model.StringParameterDefinition'
        name, value, description = nvd(i)
        param_block << " " * currentDepth + "stringParam('#{name}', #{value}, #{description})"
      when 'hudson.model.BooleanParameterDefinition'
        name, value, description = nvd(i)
        param_block << " " * currentDepth + "booleanParam('#{name}', #{value}, #{description})"
      when 'hudson.model.ChoiceParameterDefinition'
        name, value, description = nvd(i)
        param_block << " " * currentDepth + "choiceParam('#{name}', #{value}, #{description})"
      else
        param_block << "#{pp i}"
      end
    end
    param_block << " " * depth + "}"
    return param_block
  end
end

class JiraVersionParameterDefinitionHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    innerNode = []
    node.elements.each do |i|
      case i.name
      when 'pattern'
        innerNode << {
          "'#{i.name}'" => i.elements.collect{|e| %W['#{e.name}'('#{Helper.escape e.text}')]}
        }
      else
        innerNode << "'#{i.name}'('#{i.text}')"
      end
    end

    unless innerNode.empty?
      ConfigureBlock.new([{
          "it / #{configurePath} / '#{node.name}'" => innerNode
        }],
        indent: indent
      ).save!
    end
  end

  def configurePath
    node
      .path
      .split('/')[2..4]
      .collect{|n| "'#{n}'"}
      .join ' / '
  end
end

class DynamicParameterHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "configure { project ->"

    currentDepth = depth + indent
    # Even though we are nested into properties already, we have to define it still.
    # The configure {} block in job dsl feels to be buggy and this works.
    puts " " * currentDepth + "project / 'properties' / 'hudson.model.ParametersDefinitionProperty' / 'parameterDefinitions' << '#{node.name}' {"
    node.elements.each do |i|
      case i.name
      when '__uuid', '__localBaseDirectory', '__remoteBaseDirectory'
        # nothing, dynamically created by the plugin.
      when '__remote', 'readonlyInputField'
        puts " " * (currentDepth + indent) + "'#{i.name}'(#{i.text})" unless i.text.empty?
      else
        puts " " * (currentDepth + indent) + "'#{i.name}'('''#{i.text}''')" unless i.text.empty?
      end
    end
    puts " " * currentDepth + "}"

    puts " " * depth + "}"
  end
end

class PropertiesNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    # hack... need to print parameter block outside of property block. :(
    parameter_node_block = nil
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

            # These are not supported in jobdsl so have to be configured via ConfigureBlock
            p.elements.each do |pelement|
              case pelement.name
              when 'com.seitenbau.jenkins.plugins.dynamicparameter.ChoiceParameterDefinition'
                DynamicParameterHandler.new(pelement).process(job_name, currentDepth, indent)
              when 'hudson.plugins.jira.versionparameter.JiraVersionParameterDefinition'
                JiraVersionParameterDefinitionHandler.new(pelement).process(job_name, currentDepth, indent)
              end
            end

            # hack... should really be nested under properties {} but jobdsl doesnt support this yet
            parameter_node_block = ParametersNodeHandler.new(p).process(job_name, depth, indent)
          else
            pp p
          end
        end
      when 'jenkins.model.BuildDiscarderProperty'
        BuildDiscarderNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'com.cloudbees.plugins.JobPrerequisites'
        ConfigureBlock.new([{
            "it / properties / '#{i.name}'" => [
              "'script'('''#{i.at_xpath("//#{i.name}/script")&.text}''')",
              "'interpreter'('#{i.at_xpath("//#{i.name}/interpreter")&.text}')"
            ]
          }],
          indent: indent
        ).save!
      else
        pp i
      end
    end
    puts " " * depth + "}"
    if parameter_node_block
      parameter_node_block.each do |i|
        puts "#{i}"
      end
    end
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
      when 'name', 'refspec'
        puts " " * currentDepth + "#{i.name}('#{i.text}')" unless i.text.empty?
      else
        pp i
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
    configureBlock = ConfigureBlock.new [], indent: indent, indent_times: (currentDepth / indent rescue 1)
    node.elements.each do |i|
      case i.name
      when 'configVersion'
        # nothing, generated by plugin
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
            branches = ""
            j.elements.each do |b|
              branches += "'#{b.text}',"
            end
            branches[-1] = ""
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
      when 'gitTool', 'doGenerateSubmoduleConfigurations'
        configureBlock << "'#{i.name}'('#{i.text}')" unless i.text.empty?
      when'submoduleCfg'
        # todo: not yet implemented
      when 'extensions'
        GitScmExtensionsNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    puts configureBlock
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
        puts " " * currentDepth + "scriptPath('#{i.text}')"
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
        txt = i.text.gsub(/\\/,"\\\\\\").gsub("'''", %q(\\\'\\\'\\\'))
        puts " " * currentDepth + "script('''\\\n#{txt}\n\'''\n)"
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
          puts " " * currentDepth + "#{i.name}('''\\\n#{i.text}\n''')"
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
        puts " " * currentDepth + "authenticationToken('#{i.text}')"
      when 'concurrentBuild'
        puts " " * currentDepth + "concurrentBuild(#{i.text})"
      when 'logRotator'
        LogRotatorNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    ConfigureBlock.print
    puts "}"
  end
end



class TaskPropertiesHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    logText = "#{node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/logTexts/hudson.plugins.postbuildtask.LogProperties/logText')&.text}"
    script = node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/script')&.text
    script = script.gsub(/\\/,"\\\\\\").gsub("'''", %q(\\\'\\\'\\\'))
    escalate = node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/EscalateStatus')&.text
    runIfSuccessful = node.at_xpath('//hudson.plugins.postbuildtask.TaskProperties/RunIfJobSuccessful')&.text
    puts " " * depth + "task('#{logText.to_s.empty? ? ".*" : logText.delete!("\C-M")}','''\\\n#{script.delete!("\C-M")}\n''',#{escalate},#{runIfSuccessful})"
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
    puts " " * depth + "postBuildTask {"
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

class IrcTargetsNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    node.elements.each do |i|
      case i.name
      when 'hudson.plugins.im.GroupChatIMMessageTarget'
        params = i.elements.collect {|e|
          "#{e.name}: #{formatText e.text}"
        }.join ', '
        puts " " * depth + "channel(#{params})"
      else
        pp i
      end
    end
  end

  def formatText(str)
    if str =~ /false|true/
      str == 'true'
    else
      "'#{str}'"
    end
  end
end

class IrcPublisherNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    puts " " * depth + "irc {"
    currentDepth = depth + indent
    # ConfigureBlock has to be used here because jobdsl does not support
    # nesting configure within irc.
    configureBlock = ConfigureBlock.new [], indent: indent
    node.elements.each do |i|
      case i.name
      when 'buildToChatNotifier', 'channels'
        # dynamically created by IRC plugin, or cruft
      when 'targets'
        IrcTargetsNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'strategy'
        puts " " * currentDepth + "#{i.name}('#{i.text}')"
      when 'notifyUpstreamCommitters'
        puts " " * currentDepth + "#{i.name}(#{i.text})"
      when 'notifySuspects'
        puts " " * currentDepth + "notifyScmCommitters(#{i.text})"
      when 'notifyFixers'
        puts " " * currentDepth + "notifyScmFixers(#{i.text})"
      when 'notifyCulprits'
        puts " " * currentDepth + "notifyScmCulprits(#{i.text})"
      when 'notifyOnBuildStart'
        configureBlock << "(ircNode / '#{i.name}').setValue(#{i.text})"
      when 'matrixMultiplier'
        configureBlock << "(ircNode / '#{i.name}').setValue('#{i.text}')"
      else
        pp i
      end
    end

    unless configureBlock.empty?
      configureBlock.unshift "def ircNode = it / publishers / 'hudson.plugins.ircbot.IrcPublisher'"
      configureBlock.save!
    end

    puts " " * depth + "}"
  end
end


class ExtendedEmailNodeHandler < Struct.new(:node)
  def print_trigger_block(j, currentDepth, indent)
    j.elements.each do |k|
      case k.name
      when 'email'
        k.elements.each do |e|
          case e.name
          when 'attachmentsPattern'
            if !(e.text.nil? || e.text.empty?)
              puts " " * (currentDepth + indent * 2) + "attachmentPatterns('#{e.text}')"
            end
          when 'subject', 'recipientList'
            if !(e.text.nil? || e.text.empty?)
              puts " " * (currentDepth + indent * 2) + "#{e.name}('#{e.text}')"
            end
          when 'replyTo'
            puts " " * (currentDepth + indent * 2) + "replyToList('#{e.text}')"
          when 'compressBuildLog', 'attachBuildLog'
            puts " " * (currentDepth + indent * 2) + "#{e.name}(#{e.text})"
          when 'recipientProviders', 'contentType'
            # unsupported
          when 'body'
            puts " " * (currentDepth + indent * 2) + "content('''\\\n#{e.text}\n''')"
          else
            pp e
          end
        end
      when 'failureCount'
        #unsupported
      else
        pp k
      end
    end
  end

  def process(job_name, depth, indent)
    puts " " * depth + "extendedEmail {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'saveOutput'
        puts " " * currentDepth + "saveToWorkspace(#{i.text})"
      when 'replyTo'
        puts " " * currentDepth + "replyToList('#{i.text}')"
      when 'presendScript'
        puts " " * currentDepth + "preSendScript('#{i.text}')"
      when 'recipientList', 'contentType', 'defaultSubject'
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
          when 'hudson.plugins.emailext.plugins.trigger.FixedTrigger'
            puts " " * (currentDepth + indent) + "fixed {"
            print_trigger_block(j, currentDepth, indent)
            puts " " * (currentDepth + indent) + "}"
          when 'hudson.plugins.emailext.plugins.trigger.FirstFailureTrigger'
            puts " " * (currentDepth + indent) + "firstFailure {"
            print_trigger_block(j, currentDepth, indent)
            puts " " * (currentDepth + indent) + "}"
          when 'hudson.plugins.emailext.plugins.trigger.FailureTrigger'
            puts " " * (currentDepth + indent) + "failure {"
            print_trigger_block(j, currentDepth, indent)
            puts " " * (currentDepth + indent) + "}"
          when 'hudson.plugins.emailext.plugins.trigger.SuccessTrigger'
            puts " " * (currentDepth + indent) + "success {"
            print_trigger_block(j, currentDepth, indent)
            puts " " * (currentDepth + indent) + "}"
          when 'hudson.plugins.emailext.plugins.trigger.AlwaysTrigger'
            puts " " * (currentDepth + indent) + "always {"
            print_trigger_block(j, currentDepth, indent)
            puts " " * (currentDepth + indent) + "}"
          when 'hudson.plugins.emailext.plugins.trigger.StillFailingTrigger'
            puts " " * (currentDepth + indent) + "stillFailing {"
            print_trigger_block(j, currentDepth, indent)
            puts " " * (currentDepth + indent) + "}"
          when 'hudson.plugins.emailext.plugins.trigger.StatusChangedTrigger'
            puts " " * (currentDepth + indent) + "statusChanged {"
            print_trigger_block(j, currentDepth, indent)
            puts " " * (currentDepth + indent) + "}"
          when 'hudson.plugins.emailext.plugins.trigger.UnstableTrigger'
            puts " " * (currentDepth + indent) + "unstable {"
            print_trigger_block(j, currentDepth, indent)
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

class TapPublisherHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    innerNode = []
    node.elements.each do |i|
      innerNode << "'#{i.name}'('#{i.text}')" unless i.text.empty?
    end

    unless innerNode.empty?
      ConfigureBlock.new([{
          "it / 'publishers' / '#{node.name}'" => innerNode
        }],
        indent: indent
      ).save!
    end
  end
end

class JUnitResultArchiverHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    innerNode = []

    currentDepth = depth + indent

    node.elements.each do |i|
      case i.name
      when 'testResults'
        # Nothing, pulled out below because is in signature of archiveJunit method.
      when 'keepLongStdio'
        innerNode << ' ' * currentDepth + "retainLongStdout(#{i.text})" unless i.text.empty?
      when 'testDataPublishers'
        # TODO - don't have working example for this yet
      when 'healthScaleFactor'
        innerNode << ' ' * currentDepth + "#{i.name}(#{i.text})" unless i.text.empty?
      else
        pp i
      end
    end

    testResults = node.at_xpath("//publishers/#{node.name}/testResults")&.text
    archiveSig = ' ' * depth + "archiveJunit('#{testResults}')"
    if innerNode.empty?
      puts archiveSig
    else
      puts archiveSig + ' {'
      puts innerNode
      puts ' ' * depth + '}'
    end
  end
end

class MailerHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    recipients = node.at_xpath("//#{node.name}/recipients")&.text
    dontNotifyEveryUnstableBuild = node.at_xpath("//#{node.name}/dontNotifyEveryUnstableBuild")&.text
    sendToIndividuals = node.at_xpath("//#{node.name}/sendToIndividuals")&.text

    unless recipients.empty? || dontNotifyEveryUnstableBuild.empty? || sendToIndividuals.empty?
      puts " " * depth + "mailer('#{recipients}', #{dontNotifyEveryUnstableBuild}, #{sendToIndividuals})"
    end
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
      when 'hudson.plugins.ircbot.IrcPublisher'
        IrcPublisherNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.tasks.BuildTrigger'
        projects = "['#{i.at_xpath('//hudson.tasks.BuildTrigger/childProjects')&.text}']"
        threshold = "'#{i.at_xpath('//hudson.tasks.BuildTrigger/threshold/name')&.text}'"
        puts " " * currentDepth + "downstream(#{projects}, #{threshold})"
      when 'hudson.plugins.performance.PerformancePublisher'
        PerformancePublisherNodeHandler.new(i).process(job_name, currentDepth+indent, indent)
      when 'hudson.plugins.sitemonitor.SiteMonitorRecorder'
        SiteMonitorRecorderHandler.new(i).process(job_name, currentDepth, indent)
      when 'org.tap4j.plugin.TapPublisher'
        TapPublisherHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.tasks.junit.JUnitResultArchiver'
        JUnitResultArchiverHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.tasks.Mailer'
        MailerHandler.new(i).process(job_name, currentDepth, indent)
      when 'hudson.plugins.rubyMetrics.rcov.RcovPublisher'
        RcovPublisherHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end
end

class RcovPublisherHandler < Struct.new(:node)

  def process(job_name, depth, indent)
    puts " " * depth + "rcov {"
    currentDepth = depth + indent
    node.elements.each do |i|
      case i.name
      when 'reportDir'
        puts " " * currentDepth + "reportDirectory('#{i.text}')"
      when 'targets'
        handleTargets i, currentDepth
      else
        pp i
      end
    end
    puts " " * depth + "}"
  end

  def handleTargets(i, depth)
    i.elements.each do |target|
      case target.name
      when 'hudson.plugins.rubyMetrics.rcov.model.MetricTarget'
        handleMetricTarget target, depth
      else
        pp target
      end
    end
  end

  def handleMetricTarget(i, depth)
    meth = ''
    signature = []

    i.elements.each do |target|
      case target.name
      when 'metric'
        case target.text
        when 'TOTAL_COVERAGE'
          meth = 'totalCoverage'
        when 'CODE_COVERAGE'
          meth = 'codeCoverage'
        else
          pp target
        end
      when 'healthy'
        signature[0] = target.text || 0
      when 'unhealthy'
        signature[1] = target.text || 0
      when 'unstable'
        signature[2] = target.text || 0
      else
        pp target
      end
    end

    unless meth.empty? && signature.empty?
      puts ' ' * depth + "#{meth}(#{signature.join ', '})"
    end
  end

end

class SiteMonitorRecorderHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    configureBlock = ConfigureBlock.new [], indent: indent
    node.elements.each do |i|
      case i.name
      when 'mSites'
        configureBlock << "def mSitesNode = it / publishers / '#{node.name}' / 'mSites'"
        i.elements.each do |mSite|
          innerNode = []
          mSite.elements.each do |s|
            case s.name
            when 'mUrl'
              innerNode << "'#{s.name}'('#{s.text}')"
            when 'timeout'
              innerNode << "'#{s.name}'(#{s.text})"
            when 'successResponseCodes'
              srcsInnerNode = []
              s.elements.each do |sInner|
                case sInner.name
                when 'int'
                  srcsInnerNode << "'#{sInner.name}'(#{sInner.text})"
                else
                  pp sInner
                end
              end
              innerNode << { "'#{s.name}'" => srcsInnerNode }
            end
          end

          unless innerNode.empty?
            configureBlock << { "mSitesNode << '#{mSite.name}'" => innerNode }
          end
        end
      end
    end
    configureBlock.save!
  end
end

class PerformancePublisherNodeHandler < Struct.new(:node)
  def process(job_name, depth, indent)
    innerNode = []

    node.elements.each do |i|
      case i.name
      when 'errorFailedThreshold', 'errorUnstableThreshold', 'relativeFailedThresholdPositive',
           'relativeFailedThresholdNegative', 'relativeUnstableThresholdPositive', 'relativeUnstableThresholdNegative',
           'nthBuildNumber', 'configType', 'modeOfThreshold', 'compareBuildPrevious', 'modePerformancePerTestCase',
           'errorUnstableResponseTimeThreshold', 'modeRelativeThresholds', 'failBuildIfNoResultFile', 'modeThroughput',
           'modeEvaluation', 'ignoreFailedBuilds', 'ignoreUnstableBuilds', 'persistConstraintLog'
        innerNode << "#{i.name} '#{i.text}'"
      when 'parsers'
        innerParsers = []
        i.elements.each do |inner|
          case inner.name
          when 'hudson.plugins.performance.JMeterParser'
            innerParsers << {
              "'#{inner.name}'" => inner.elements.collect do |ie|
                                     "'#{ie.name}'('#{ie.text}')"
                                   end
            }
          else
            pp i
          end
        end
        innerNode << {"'parsers'" => innerParsers}
      else
        pp i
      end
    end

    unless innerNode.empty?
      ConfigureBlock.new([{
          "it / publishers / '#{node.name}' <<" => innerNode
        }],
        indent: indent
      ).save!
    end
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
      when 'buildStepFailureThreshold'
        puts " " * currentDepth + "buildStepFailure('#{i.at_xpath('//buildStepFailureThreshold/name')&.text}')"
      when 'unstableThreshold'
        puts " " * currentDepth + "unstable('#{i.at_xpath('//unstableThreshold/name')&.text}')"
      when 'failureThreshold'
        puts " " * currentDepth + "failure('#{i.at_xpath('//failureThreshold/name')&.text}')"
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
                #puts " " * currentDepth + "#{k.name}('#{k.text}')"
              when 'triggerWithNoParameters', 'buildAllNodesWithLabel'
                #puts " " * currentDepth + "#{k.name}(#{k.text})"
              when 'block'
                BlockNodeHandler.new(k).process(job_name, currentDepth, indent)
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
        puts " " * currentDepth + "steps {"
        puts " " * (currentDepth + indent) + "downstreamParameterized {"
        TriggerNodeHandler.new(i).process(job_name, currentDepth + indent * 2, indent)
        puts " " * (currentDepth + indent) + "}"
        puts " " * currentDepth + "}"
      when 'hudson.tasks.Shell'
        puts " " * currentDepth + "steps {"
	txt = i.at_xpath('//hudson.tasks.Shell/command')&.text
        txt = txt&.gsub(/\\/,"\\\\\\").gsub("'''", %q(\\\'\\\'\\\'))
        puts " " * (currentDepth + indent) + "shell('''\\\n#{txt}\n''')"
        puts " " * currentDepth + "}"
      when 'org.jvnet.hudson.plugins.SSHBuilder'
        puts " " * currentDepth + "steps {"
        puts " " * (currentDepth + depth) + "remoteShell('#{i.at_xpath("//#{i.name}/siteName")&.text}') {"
        puts " " * (currentDepth + depth + depth) + "command('''#{i.at_xpath("//#{i.name}/command")&.text}''')"
        puts " " * (currentDepth + depth) + "}"
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
        if !(i.text.nil? || i.text.empty?)
          puts " " * currentDepth + "#{i.name}('''\\\n#{i.text}\n''')"
        end
      when 'properties'
        PropertiesNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'definition'
        DefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'triggers'
        TriggerDefinitionNodeHandler.new(i).process(job_name, currentDepth, indent)
      when 'authToken'
        puts " " * currentDepth + "authenticationToken(token = '#{i.text}')"
      when 'mavenOpts'
        puts " " * currentDepth + "#{i.name}('#{i.text}')"
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
        # todo: is this necessary?
      when 'rootModule'
        # todo: is this necessary?
      when 'runPostStepsIfResult'
        puts " " * currentDepth + "postBuildSteps('#{i.at_xpath('//runPostStepsIfResult/name')&.text}') {"
        puts " " * currentDepth + "}"
      else
        pp i
      end
    end
    ConfigureBlock.print
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
        if !(i.text.nil? || i.text.empty?)
          puts " " * currentDepth + "#{i.name}('''\\\n#{i.text}\n''')"
        end
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
      when 'logRotator'
        LogRotatorNodeHandler.new(i).process(job_name, currentDepth, indent)
      else
        pp i
      end
    end
    ConfigureBlock.print
    puts "}"
  end
end

# Used to implement JobDSL's `configure {...}` type syntax. This class
# approaches this problem as if the configure block is an array of lines and
# each line can be either String, Hash, or Array. This is implemented this
# way due to the way that JobDSL's configure block works and its flexibility.
#
# See their docs for details on this:
# https://github.com/jenkinsci/job-dsl-plugin/wiki/The-Configure-Block
#
# This can be used like:
#
#   configureBlock = ConfigureBlock.new [], indent: 4
#   configureBlock << '// this would be the very first line within the configure block'
#   configureBlock << 'it / "this is the groovy reserved `it` to indicate the node we are on'
#   configureBlock << {'it / "can use a hash as well to describe inner blocks" <<' => ["'inner'('element')]}
#
#   configureBlock.save! #this will write `self` into the class constant that #print can use
#   ConfigureBlock.print #this will print all ConfigureBlock's that have been #save!'d
#
# Another way to do this is like:
#
#   arr = [
#     "def foo = it / 'inner' / 'xml'",
#     "(foo / 'bar').setValue('bazz')",
#     {
#       "it / 'using' / 'block' <<" => [
#         "'inner'('element')",
#         "'another'('element')",
#       ]
#     },
#     {
#       "it / 'another' / 'using' / 'block'" => [
#         {"'further'" => ["'nested'('element')"]},
#       ]
#     }
#   ]
#
#   configureBlock = ConfigureBlock.new arr, indent: 4
#   configureBlock.save!
#   ConfigureBlock.print
#
# You can also define multiple configure blocks just by instantiating a new one
# and calling #save! on that object.
class ConfigureBlock
  NOT_SO_CONSTANT_CONFIGURE_BLOCKS = []

  def self.print
    return if NOT_SO_CONSTANT_CONFIGURE_BLOCKS.empty?
    NOT_SO_CONSTANT_CONFIGURE_BLOCKS.each do |configureBlock|
      puts configureBlock
    end
  end

  def initialize arr = [], opts = {}
    @lines = arr
    @indent = opts[:indent] || 4
    @indent_times = opts[:indent_times] || 1
  end

  def << e
    @lines << e
  end

  def unshift e
    @lines.unshift e
  end

  def empty?
    @lines.empty?
  end

  def save!
    NOT_SO_CONSTANT_CONFIGURE_BLOCKS.push self
  end

  def to_s
    first = format 'configure {'
    middle = @lines.inject('') do |ret, line|
      ret = format line, @indent_times + 1
      ret
    end
    last = format '}'
    "#{first}#{middle}#{last}"
  end

  def format line, indent_times = @indent_times
    case line
    when String
      indention line, indent_times
    when Hash
      first = line.keys.first + ' {'
      indention first, indent_times
      format line.values.first, indent_times + 1
      indention '}', indent_times
    when Array
      line.each do |l|
        format l, indent_times
      end
    end
  end

  def indention line, indent_times = 1
    puts ' ' * @indent * indent_times + "#{line}\n"
  end

end

# Bucket to dump any helpers multiple classes may need.
class Helper

  # Escape Strings that are not valid groovy syntax.
  def self.escape str
    str.gsub(/\\/,"\\\\\\").gsub("'''", %q(\\\'\\\'\\\'))
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

