class FixUnavailableSymbol

  def initialize(projectName, projectPath, baseCommit, filePath, missingMethod, line, declaredMethod)
    @projectPath = projectPath
    @baseCommit = baseCommit
    @filePath = filePath
    @missingMethod = missingMethod
    @projectName = projectName
    @declaredMethod = declaredMethod

    @line = line
    @initialPath = ""
  end

  def deleteClone()
    Dir.chdir(@initialPath)
    %x(rm -rf baseCommitClone/)
  end


  def fixMethod()


    fileDirectory = Dir.getwd + "/" + @filePath
    puts fileDirectory
    #armazenar o conteudo do arquivo que esta faltando o metodo
    baseFileContent = File.read(fileDirectory)
    puts "missing = " + @missingMethod
    puts "declared = "+ @declaredMethod
    #substituir o metodo que mudou o nome para o que foi declarado
    array = baseFileContent.split("\n")
    array[@line - 1].gsub!(@missingMethod, @declaredMethod)
    baseFileContent = array.join("\n")
    #escrever no arquivo
    e = File.open(fileDirectory, 'w')
    e.write(baseFileContent)
    e.close
    c = %x(mvn clean install)
    puts c
    puts Dir.getwd
    if(!c.to_s.match(/\[INFO\] BUILD FAILURE/))
      puts "Do you want to commit? Y or n"
      resp = STDIN.gets()
      if !resp.match(/(n|N)/)
        makeCommit
      end
    else
      puts "Your project has non-merge's compilation errors "
    end
  end



  def makeCommit()
    #Dir.chdir(@projectPath)
    commitMesssage = "Build Conflict resolved automatically, removed " << @declaredMethod << " declaration in line " << @line << " of file " << @filePath
    %x(git add -u)
    %x(git commit -m "#{commitMesssage}")

  end

end