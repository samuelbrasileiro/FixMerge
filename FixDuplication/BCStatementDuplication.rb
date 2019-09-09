require 'io/console'
require 'fileutils'
require 'open-uri'
require 'rest-client'
require 'net/http'
require 'json'
require 'uri'
require 'nokogiri'

class BCStatementDuplication

  def initialize(gumTreePath, projectName, localClone, mergeCommit, parentsMerge, conflictCauses)
    @mergeCommit = mergeCommit
    @projectName = projectName
    @pathLocalClone = localClone
    @gumTreePath = gumTreePath
    @parentsMerge = parentsMerge
    @conflictCauses = conflictCauses
  end

  def getProjectName()
    @projectName
  end

  def getPathLocalClone()
    @pathLocalClone
  end

  def getGumTreePath()
    @gumTreePath
  end

  def getParentsMFDiff()
    @parentMSDiff
  end

  def getMergeCommit()
    @mergeCommit
  end

  def getConflictCauses()
    @conflictCauses
  end

  def getCopyProjectDirectories()
    @copyProjectDirectories
  end

  def getGumTreeAnalysis()
    actualPath = Dir.pwd
    pathCopies = createCopyProject()
    #print "pathed"
    #  		   					result 		  left 			right 			MergeCommit 	parent1 		parent2 	problemas
    out = gumTreeDiffByBranch(pathCopies[1], pathCopies[2], pathCopies[3], pathCopies[4], getPathLocalClone(), getPathLocalClone())

    deleteProjectCopies(pathCopies)
    Dir.chdir actualPath
    return out, pathCopies[5]
  end

  def gumTreeDiffByBranch(result, left, right, base, pathProject, cloneProject)
    baseLeft = runAllDiff(base, left)
    baseRight = runAllDiff(base, right)
    leftResult = runAllDiff(left, result)
    rightResult = runAllDiff(right, result)
    return verifyBuildConflict(baseLeft, leftResult, baseRight, rightResult, getConflictCauses()[0])
  end

  def runAllDiff(firstBranch, secondBranch)
    Dir.chdir getGumTreePath()
    mainDiff = nil
    modifiedFilesDiff = []
    addedFiles = []
    deletedFiles = []

    begin
      kill = %x(pkill -f gumtree)
      sleep(10)
      print "aqui1"
      thr = Thread.new { diff = system "bash", "-c", "exec -a gumtree ./gumtree webdiff #{firstBranch.gsub("\n","")} #{secondBranch.gsub("\n","")}" }
      sleep(15)
      mainDiff = %x(wget http://127.0.0.1:4567/ -q -O -)
      modifiedFilesDiff = getDiffByModification(mainDiff[/Modified files <span class="badge">(.*?)<\/span>/m, 1])
      addedFiles = getDiffByAddedFile(mainDiff[/Added files <span class="badge">(.*?)<\/span>/m, 1])
      deletedFiles = getDiffByDeletedFile(mainDiff[/Deleted files <span class="badge">(.*?)<\/span>/m, 1])

      print "aqui2"

      kill = %x(pkill -f gumtree)
      sleep(5)
    rescue StandardError => e
      puts e
      puts "GumTree Failed"
    end
    return modifiedFilesDiff, addedFiles, deletedFiles
  end

  def getDiffByModification(numberOcorrences)
    index = 0
    result = Hash.new()
    while(index < numberOcorrences.to_i)
      begin
        gumTreePage = Nokogiri::HTML(RestClient.get("http://127.0.0.1:4567/script/#{index}"))
        file = gumTreePage.css('div.col-lg-12 h3 small').text[/(.*?) \-\>/m, 1].gsub(".java", "")
        script = gumTreePage.css('div.col-lg-12 pre').text
        result[file.to_s] = script.gsub('"', "\"")
      rescue StandardError => e
        print e
      end

      index += 1
    end
    return result
  end

  def getDiffByDeletedFile(numberOcorrences)
    #index = 0
    result = Array.new
    #while(index < numberOcorrences.to_i)
    begin
      gumTreePage = Nokogiri::HTML(RestClient.get("http://127.0.0.1:4567/"))
      tableDeleted = gumTreePage.to_s.match(/Deleted files[\s\S]*Added files/)[0].match(/<table [\s\S]*<\/table>/)
      Nokogiri::HTML(tableDeleted[0]).css('table tr td').each do |element|
        result.push(element.text)
      end
    rescue

    end
    #index += 1
    #end
    return result
  end

  def getDiffByAddedFile(numberOcorrences)
    #index = 0
    result = Array.new
    #while(index < numberOcorrences.to_i)
    begin
      gumTreePage = Nokogiri::HTML(RestClient.get("http://127.0.0.1:4567/"))
      tableDeleted = gumTreePage.to_s.match(/Added files[\s\S]*<\/table>/)[0].match(/<table [\s\S]*<\/table>/)
      Nokogiri::HTML(tableDeleted[0]).css('table tr td').each do |element|
        result.push(element.text)
      end
    rescue

    end
    #index += 1
    #end
    return result
  end

  def createDirectories()
    copyBranch = []
    Dir.chdir @pathLocalClone
    Dir.chdir ".."
    FileUtils::mkdir_p 'Copies/Result'
    FileUtils::mkdir_p 'Copies/Left'
    FileUtils::mkdir_p 'Copies/Right'
    FileUtils::mkdir_p 'Copies/Base'
    Dir.chdir "Copies"
    copyBranch.push(Dir.pwd)
    Dir.chdir "Result"
    copyBranch.push(Dir.pwd)
    Dir.chdir copyBranch[0]
    Dir.chdir "Left"
    copyBranch.push(Dir.pwd)
    Dir.chdir copyBranch[0]
    Dir.chdir "Right"
    copyBranch.push(Dir.pwd)
    Dir.chdir copyBranch[0]
    Dir.chdir "Base"
    copyBranch.push(Dir.pwd)
    return copyBranch
  end

  def createCopyProject()

    copyBranch = createDirectories()

    Dir.chdir @pathLocalClone
    puts "git checkout"
    currentBranch = getMergeCommit()
    checkout = %x(git checkout #{currentBranch} > /dev/null 2>&1)
    base = %x(git merge-base --all #{@parentsMerge[0]} #{@parentsMerge[1]})
    checkout = %x(git checkout #{base} > /dev/null 2>&1)
    clone = %x(cp -R #{@pathLocalClone} #{copyBranch[4]})
    invalidFiles = %x(find #{copyBranch[4]} -type f -regextype posix-extended -iregex '.*\.(sh|vm|md|yaml|yml|conf|scala|properties|less|txt|gitignore|sql|html|gradle|stg|lex|classpath|jsp|form|sql|stg|sql.stg|py|groovy|generator|jade|coffee|hbs|in|am|mk|ac|ico|md5|adoc|xsd)$' -delete)

    invalidFiles = %x(find #{copyBranch[4]} -type f  ! -name "*.?*" -delete)
    checkout = %x(git checkout #{@mergeCommit} > /dev/null 2>&1)
    clone = %x(cp -R #{@pathLocalClone} #{copyBranch[1]})
    invalidFiles = %x(find #{copyBranch[1]} -type f -regextype posix-extended -iregex '.*\.(sh|vm|md|yaml|yml|conf|scala|properties|less|txt|gitignore|sql|html|gradle|stg|lex|classpath|jsp|form|sql|stg|sql.stg|py|groovy|generator|jade|coffee|hbs|in|am|mk|ac|ico|md5|adoc|xsd)$' -delete)
    invalidFiles = %x(find #{copyBranch[1]} -type f  ! -name "*.?*" -delete)

    index = 0
    while(index < @parentsMerge.size)
      checkout = %x(git checkout #{@parentsMerge[index]} > /dev/null 2>&1)
      clone = %x(cp -R #{@pathLocalClone} #{copyBranch[index+2]} > /dev/null 2>&1)
      invalidFiles = %x(find #{copyBranch[index+2]} -type f -regextype posix-extended -iregex '.*\.(sh|vm|md|yaml|yml|conf|scala|properties|less|txt|gitignore|sql|html|gradle|stg|lex|classpath|jsp|form|sql|stg|sql.stg|py|groovy|generator|jade|coffee|hbs|in|am|mk|ac|ico|md5|adoc|xsd)$' -delete)
      invalidFiles = %x(find #{copyBranch[index+2]} -type f  ! -name "*.?*" -delete)
      checkout = %x(git checkout #{currentBranch} > /dev/null 2>&1)
      index += 1
    end

    return copyBranch[0], copyBranch[1], copyBranch[2], copyBranch[3], copyBranch[4], base
    #      copies         result 			left 		right 			base			mergeCommit
  end

  def deleteProjectCopies(pathCopies)

    delete = %x(rm -rf #{pathCopies[0]})
  end






  def verifyBuildConflict(baseLeft, leftResult, baseRight, rightResult, filesConflicting)
    count = 0

    while(count < filesConflicting.size)
      begin
        if (filesConflicting[2] != "method")

          if(baseRight[0][filesConflicting[1]] != nil and baseRight[0][filesConflicting[1]].to_s.match(/Insert SimpleName: #{filesConflicting[2]}[0-9\(\)]* into [a-zA-Z\:\= 0-9\(\)]* on Method #{filesConflicting[3]}/))
            if (baseLeft[0][filesConflicting[1]] != nil and baseLeft[0][filesConflicting[1]].to_s.match(/Insert SimpleName: #{filesConflicting[2]}[0-9\(\)]* into [a-zA-Z\:\= 0-9\(\)]* on Method #{filesConflicting[3]}/))
              return true
            end
          end
          if(baseLeft[0][filesConflicting[1]] != nil and baseLeft[0][filesConflicting[1]].to_s.match(/Insert SimpleName: #{filesConflicting[2]}[0-9\(\)]* into [a-zA-Z\:\= 0-9\(\)]* on Method #{filesConflicting[3]}/))
            if (baseRight[0][filesConflicting[1]] != nil and baseRight[0][filesConflicting[1]].to_s.match(/Insert SimpleName: #{filesConflicting[2]}[0-9\(\)]* into [a-zA-Z\:\= 0-9\(\)]* on Method #{filesConflicting[3]}/))
              return true
            end
          end
        else
          begin
            if(baseLeft[0][filesConflicting[1]] != nil and baseLeft[0][filesConflicting[1]].to_s.match(/Insert SimpleName: #{filesConflicting[3]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/) and baseRight[0][filesConflicting[1]] != nil and baseRight[0][filesConflicting[1]].to_s.match(/Insert SimpleName: #{filesConflicting[3]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/))
              return true
            end
          rescue
            print "EMPTY INFO FROM GUMTREE"
          end
        end
      rescue StandardError => e
        puts e
      end
      count += 1
    end
    return false
  end

end
