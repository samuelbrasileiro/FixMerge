class UnimplementedMethodExtractor

  def initialize()

  end

  def extractionFilesInfo(buildLog)

    begin
      return getInfoDefaultCase(buildLog)
    rescue
      return "", [], 0
    end
  end

  def extractionFilesInfoSecond (buildLog)
    begin
      return getInfoSecondCase(buildLog)
    rescue
      return "unimplementedMethodSuperType", [], 0
    end
  end

  def getInfoDefaultCase(buildLog)
    unimpFilePath = ""
    interfaceFilePath = ""
    stringErro = "ERROR"
    stringNoOverride = "does not override (abstract|or implement a)? method"
    filesInformation = []
    numberOccurrences = buildLog.scan(/\[#{stringErro}\][\s\S]*#{stringNoOverride}[\s\S]*(\[INFO\])?/).size
    classFiles = ""

    if (buildLog.match(/\[ERROR\] [a-zA-Z0-9\/\-]*\.java/).to_s.match(/[0-9a-zA-Z]+\.java/)[0].to_s)
      classFiles = buildLog.to_enum(:scan, /\[ERROR\] [a-zA-Z0-9\/\-]*\.java/).map { Regexp.last_match }
    elsif (buildLog.match(/error: [a-zA-Z0-9\/\-]* is not abstract/))
      classFiles = buildLog.to_enum(:scan, /error: [a-zA-Z0-9\/\-]* is not abstract/).map { Regexp.last_match }
    end

    interfaceFiles = buildLog.to_enum(:scan, /#{stringNoOverride} [0-9a-zA-Z\(\)\<\>\.\,]* in [a-zA-Z\.]*[^\n]+/).map { Regexp.last_match }
    methodInterfaces = buildLog.to_enum(:scan, /#{stringNoOverride} [0-9a-zA-Z\(\)\.\,\<\>]* in/).map { Regexp.last_match }
    count = 0

    while(count < interfaceFiles.size)
      classFile = ""
      methodInterface = ""
      #TODO:- FALTA FAZER ISSO
      # aqui tb
      filePath = ""
      if (buildLog.match(/\[ERROR\] [0-9a-zA-Z\/\-]*\.java/).to_s.match(/[a-zA-Z]+\.java/)[0].to_s)

        filePath = buildLog.match(/\[ERROR\] [0-9a-zA-Z\/\-]*\.java/).to_s.gsub(/\[ERROR\] /).to_s
        #unimpFilePath = buildLog.match(/\[ERROR\] [0-9a-zA-Z\/\-]*\.java/).to_s
        #unimpFilePath.gsub!(/\[ERROR\] /, "")
        classFile = classFiles[count].to_s.match(/[a-zA-Z]+\.java/)[0].to_s.gsub(".java", "")
      elsif (buildLog.match(/error: [0-9a-zA-Z\/\-]* is not abstract/))

        classFile = classFiles[count].to_s.match(/error: [a-zA-Z\/\-]*/).gsub("error: ","").to_s.gsub(".java", "")
        filePath = buildLog.match(/error [0-9a-zA-Z\/\-]*\.java/).to_s.gsub(/error /)
        #unimpFilePath = buildLog.match(/error: [0-9a-zA-Z\/\-]*\.java/).to_s
        #unimpFilePath.gsub!(/error: /, "")
      end
      interfaceFile = interfaceFiles[count].to_s.split(".").last.gsub("\r", "").to_s
      if (methodInterfaces[count].to_s.match(/does not override abstract method[\s\S]*\(/))

        # does not override abstract method getValueTypeDesc() in com.fasterxml.jackson.databind.deser.ValueInstantiator
				unimpFilePath = buildLog.match(/does not override abstract method[\s\S]*\([\s\S]*\) in [\s\S]* /).to_s
				unimpFilePath.gsub!(/does not override abstract method[\s\S]*\([\s\S]*\) in /, "")
				unimpFilePath.gsub!(/(\r|\n|\[)[\s\S]*/, "")
				array = unimpFilePath.split(".")
				unimpFilePath = array.join("/")
        methodInterface = methodInterfaces[count].to_s.match(/does not override abstract method[\s\S]*\(/).to_s.gsub(/does not override abstract method /,"").to_s.gsub("\(","")
        interfaceFilePath = methodInterfaces[count].to_s.match(/does not override abstract method[\s\S]*\(/).to_s
        interfaceFilePath.gsub!(/does not override abstract method /,"")
        interfaceFilePath.gsub!(/\(/,"")
      else
        methodInterface = methodInterfaces[count].to_s.match(/[a-zA-Z\(\)]* in/).to_s.gsub(" in","").to_s
      end
      if (methodInterface == "")
        methodInterface = interfaceFiles[count].to_s.match(/does not override abstract method [a-zA-Z\<\> ]*/).to_s.split("\>").last
      end

      filesInformation.push(["unimplementedMethod", classFile, interfaceFile, methodInterface])
      count += 1
    end
    if filesInformation.size == 0
      return "",[],0,""
    end
    return "unimplementedMethod", filesInformation, interfaceFiles.size, unimpFilePath
  end

  def getInfoSecondCase(buildLog)
    filesInformation = []
    #classFiles = buildLog.to_enum(:scan, /\[ERROR\] [a-zA-Z\/\-\.\:\,\[\]0-9 ]*cannot find symbol/).map { Regexp.last_match }
    classFiles = buildLog.to_enum(:scan, /\[ERROR\] [a-zA-Z0-9\/\-]*\.java/).map { Regexp.last_match }
    #methodInterfaces = buildLog.to_enum(:scan, /symbol[ \t\r\n\f]*:[ \t\r\n\f]*(method|variable|class|constructor|static)[ \t\r\n\f]*[a-zA-Z0-9\_]*/).map { Regexp.last_match }
    count = 0
    while(count < classFiles.size)
      classFile = classFiles[count].to_s.match(/[a-z0-9A-Z]+\.java/)[0].to_s.gsub(".java","")
      #methodInterface = methodInterfaces[count].to_s.match(/symbol[ \t\r\n\f]*:[ \t\r\n\f]*(method|variable|class|constructor|static)[ \t\r\n\f]*[a-zA-Z0-9\_]*/)[0].split(" ").last
      #methodInterface = methodInterfaces[count].to_s.match(/symbol[ \t\r\n\f]*:[ \t\r\n\f]*(method|variable|class|constructor|static)[ \t\r\n\f]*[a-zA-Z0-9\_]*/)[0].split(" ").last
      filesInformation.push(["unimplementedMethodSuperType", classFile, classFile, classFile])
      count += 1
    end
    return "unimplementedMethodSuperType", filesInformation, filesInformation.size
  end

end