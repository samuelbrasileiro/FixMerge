class StatementDuplicationExtractor

  def initialize()

  end

  def extractionFilesInfo(buildLog)
    #buildLog = build.match(/[\s\S]* BUILD FAILURE/)
    filesInformation = []
    numberOccurrences = buildLog.scan(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\(\)\s\<\>]* is already defined in [a-zA-Z0-9\/\-\.\:\[\]\,\_]* [a-zA-Z0-9]*/).size
    begin
      information = buildLog.to_enum(:scan, /\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\(\)\s\<\>]* is already defined in [a-zA-Z0-9\/\-\.\:\[\]\,\_]* [a-zA-Z0-9]*/).map { Regexp.last_match }
      count = 0
      classFilePath = ""
      methodLine = ""
      while(count < information.size)
        classFilePath = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\s\<\>]*.java/)
        classFilePath = classFilePath.to_s.gsub(/\[ERROR\] /, '')
        classFile = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\s\<\>]*.java:/)[0].split("/").last.gsub('.java:','')
        methodLine = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\s\<\>]*.java:\[[0-9]*/).to_s
        methodLine = Integer(methodLine.gsub(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\s\<\>]*.java:\[/,''))
        variableName = ""
        if (information[count].to_s.match(/variable/) and information[count].to_s.match(/defined in method/))
          variableName = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\,]*\]\s[a-zA-Z0-9\/\-\_]* [a-zA-Z0-9]*/)[0].split(" ").last
        else
          variableName = "method"
        end
        methodName = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\,\]\s\_]*/)[0].split(" ").last
        count += 1
        if (!methodName.include? ".")
          filesInformation.push(["statementDuplication", classFile, variableName, methodName])
        end
      end
      if filesInformation.size == 0
        return "", [], 0
      end
      return "statementDuplication", filesInformation, information.size, classFilePath, methodLine
    rescue StandardError => e
      puts "error = #{e}"
      return "", [], 0
    end
  end

end
