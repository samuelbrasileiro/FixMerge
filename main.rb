require_relative 'FixDuplication/BCStatementDuplication'
require_relative 'FixDuplication/FixStatementDuplication'
require_relative 'FixDuplication/StatementDuplicationExtractor'
require_relative 'FixUnavailableSymbolMethod/BCUnavailableSymbol'
require_relative 'FixUnavailableSymbolMethod/FixUnavailableSymbol'
require_relative 'FixUnavailableSymbolMethod/UnavailableSymbolExtractor'
require_relative 'FixUnimplementedMethod/BCUnimplementedMethod'
require_relative 'FixUnimplementedMethod/FixUnimplementedMethod'
require_relative 'FixUnimplementedMethod/UnimplementedMethodExtractor'
require_relative 'GitProject.rb'

if ARGV.length < 1
  puts "invalid args, valid args example: "
  puts "grumTreePath projectPath"
  puts "projectPath is an optional param"
  return
end


# Pre setup
puts "Entry your password"
password = STDIN.noecho(&:gets)

gumTree = ARGV[0]

if ARGV.length > 1
  Dir.chdir(ARGV[1])
end
projectPath = Dir.getwd

repLog = `#{"git config --get remote.origin.url"}`
if repLog == ""
  puts "invalid repository"
  return
end

projectName = repLog.split("//")[1]
projectName = projectName.split("github.com/").last.gsub("\n","").gsub(".git", "")
commitHash = `#{"git rev-parse --verify HEAD"}`
commitHash = commitHash.gsub("\n", "")
print "\n"
# Init  Analysis
gitProject = GitProject.new(projectName, projectPath, "samuelbrasileiro", "00780708")
conflictResult = gitProject.conflictScenario(commitHash) #aqui vamos pegar o parentMerge
#ESTRUTURA CR: [bool, [commits]]
gitProject.deleteProject()

conflictParents = conflictResult[1]

travisLog = gitProject.getTravisLog(commitHash)#pegar a log do nosso commit


statementDuplicationExtractor = StatementDuplicationExtractor.new()
unavailableResult = statementDuplicationExtractor.extractionFilesInfo(travisLog)

if unavailableResult[0] == "statementDuplication"
  puts "cause = #{unavailableResult[0]}"

  conflictCauses = unavailableResult[1]

  ocurrences = unavailableResult[2]

  bcstatementDuplication = BCStatementDuplication.new(gumTree, projectName, projectPath, commitHash, conflictParents, conflictCauses)
  bcStDuplicationResult = bcstatementDuplication.getGumTreeAnalysis()


  if bcStDuplicationResult[0] == true

    methodName = conflictCauses[0][3]
    conflictFile = conflictCauses[0][1]
    conflictFilePath = unavailableResult[3]
    fileToChange = conflictFilePath.gsub(/\/home\/travis\/build\/[^\/]+\/[^\/]+\//, "")
    conflictLine = unavailableResult[4]
    baseCommit = conflictResult[1][2]

    puts ">>>>>>>>>>>>>>>file "
    puts conflictFile
    puts ">>>>>>>>>>>>>>>fileToChange "
    puts fileToChange
    puts ">>>>>>>>>>>>>>>method"
    puts methodName
    puts ">>>>>>>>>>>>>>>line"
    puts conflictLine
    puts ">>>>>>>>>>>>>>>base"
    puts baseCommit
    puts "A build Conflict was detect, the conflict type is " + unavailableResult[0] + "."
    puts "Do you want fix it? y or n"
    resp = STDIN.gets()

    if resp != "n" && resp != "N"
      fixer = FixStatementDuplication.new(projectName, fileToChange, conflictLine, methodName)
      fixer.fixDuplication
    end

  end
end

unavailableSymbolMethodExtractor = UnavailableSymbolExtractor.new()
unavailableResult = unavailableSymbolMethodExtractor.extractionFilesInfo(travisLog)
if unavailableResult != nil && unavailableResult[0] == "unavailableSymbolMethod"
  conflictCauses = unavailableResult[1]
  ocurrences = unavailableResult[2]
  puts "cause = #{unavailableResult[0]}"

  bcUnavailableSymbol = BCUnavailableSymbol.new( gumTree, projectName, projectPath,  commitHash, conflictParents, conflictCauses)
  bcUnSymbolResult = bcUnavailableSymbol.getGumTreeAnalysis()

  if bcUnSymbolResult[0] != ""
    baseCommit = bcUnSymbolResult[1]
    cause = bcUnSymbolResult[0][0]
    substituter = bcUnSymbolResult[0][1]#metodo identificado pelo log da gumtree
    className = conflictCauses[0][0]
    callClassName = conflictCauses[0][2]
    methodNameByTravis = conflictCauses[0][1]#travis
    conflictFile = conflictCauses[0][3].tr(":","")
    fileToChange = conflictFile.gsub(/\/home\/travis\/build\/[^\/]+\/[^\/]+\//, "")
    conflictLine = Integer(conflictCauses[0][4].gsub("[","").gsub("]","").split(",")[0])

    if cause == methodNameByTravis
      puts "A build Conflict was detect, the conflict type is " + unavailableResult[0] + "."
      puts "Do you want fix it? Y or n"
      resp = STDIN.gets()
      # resp = "n"

      puts ">>>>>>>>>>>>>>>class"
      puts className
      puts ">>>>>>>>>>>>>>>method"
      puts methodNameByTravis
      puts ">>>>>>>>>>>>>>>substituter"
      puts substituter
      if resp != "n" && resp != "N"
        fixer = FixUnavailableSymbol.new(projectName, projectPath, baseCommit, fileToChange, cause, conflictLine, substituter)
        fixer.fixMethod
      end
    end
  end
end

unimplementedMethodExtractor = UnimplementedMethodExtractor.new()
unavailableResult = unimplementedMethodExtractor.extractionFilesInfo(travisLog)
if unavailableResult[0] == "unimplementedMethod"
  puts "cause = #{unavailableResult[0]}"
  conflictCauses = unavailableResult[1]
  ocurrences = unavailableResult[2]
  interfacePath = unavailableResult[3] + ".java"

  bcUnimplementedMethod = BCUnimplementedMethod.new(gumTree, projectName, projectPath, commitHash,
                                                    conflictParents, conflictCauses)
  bcUnSymbolResult = bcUnimplementedMethod.getGumTreeAnalysis()
  baseCommit = bcUnSymbolResult[1]
  className = conflictCauses[0][1]
  interfaceName = conflictCauses[0][2] + ".java"
  methodNameByTravis = conflictCauses[0][3]

  puts "A build Conflict was detect, the conflict type is " + unavailableResult[0] + "."
  puts "Do you want fix it? Y or n"
  resp = STDIN.gets()
  # resp = "n"

  puts ">>>>>>>>>>>>>>>Interface to change"
  puts interfacePath
  puts ">>>>>>>>>>>>>>>Conflict Called File"
  puts interfaceName
  puts ">>>>>>>>>>>>>>>Unimplemented Method"
  puts methodNameByTravis
  puts ">>>>>>>>>>>>>>>Class"
  puts className
  %x()
  if !resp.match(/(n|N)/)
    fixer = FixUnimplementedMethod.new( projectPath, interfacePath, methodNameByTravis)
    fixer.fix(interfaceName)
  end
end


puts "FINISHED!"
