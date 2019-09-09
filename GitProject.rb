require 'octokit'
require 'date'
require 'travis'

class GitProject

	def initialize(project, localClone, login, password)
		@projectAvailable = isProjectAvailable(project, login, password)
		if(getProjectAvailable() == true)
			@projetcName = project
			@login = login
			@password = password
			@mainLocalClonePath = localClone
			@travisRepository = getRepositoryTravisByProject()
			@localProjectPath = cloneProject("mainProject")
		end
	end

	def getFirstBuild()
		@firstBuild
	end

	def getLogin()
		@login
	end

	def getPassword()
		@password
	end

	def getProjectAvailable()
		@projectAvailable
	end

	def getProjectName()
		@projetcName
	end

	def getMainLocalPath()
		@mainLocalClonePath << "mainProject"
	end

	def isProjectAvailable(projectName, login, password)
		Octokit.auto_paginate = true
		client = Octokit::Client.new \
	  		:login    => login,
	  		:password => password
		begin
			return true
		rescue Exception => e  
			puts "PROJECT NOT FOUND"
		end
		return false
	end

	def cloneProject(nameFolder)
		Dir.chdir @mainLocalClonePath
		clone = %x(git clone https://github.com/#{getProjectName()} #{nameFolder})
		Dir.chdir nameFolder
		return Dir.pwd
	end

	def deleteProject()
		Dir.chdir @mainLocalClonePath
		%x(rm -rf mainProject)
	end

	def getRepositoryTravisByProject()
		begin
			@travisRepository = Travis::Repository.find(getProjectName())
		rescue Exception => e  
			puts "UNAVAILABLE PROJECT"
		end
	end

	def getParentsMergeIfTrue(mergeCommit)
		parentsCommit = []
		Dir.chdir @localProjectPath
		commitType = %x(git cat-file -p #{mergeCommit})
		commitType.each_line do |line|
			if(line.include?('author'))
				break
			end
			if(line.include?('parent'))
				commitSHA = line.partition('parent ').last.gsub("\n","").gsub(' ','').gsub('\r','')
				parentsCommit.push(commitSHA)
			end
		end

		if (parentsCommit.size > 1)
			baseCommit = checkIfFastFoward(parentsCommit[0], parentsCommit[1])
			if (baseCommit != "")
				parentsCommit.push(baseCommit)
				return parentsCommit
			else
				return nil
			end
		else
			return nil
		end
	end

  def checkIfFastFoward(parentOne, parentTwo)
		baseCommit = %x(git merge-base #{parentOne} #{parentTwo}).gsub("\n","")
		if (baseCommit == parentOne or baseCommit == parentTwo)
			return ""
		else
			return baseCommit
		end
	end

	def getTravisLog(hashCommit)#COLETAR A LOG DO TRAVIS DO COMMIT FILHO
		projectBuilds = loadAllBuildsProject()
		buildId = projectBuilds.fetch(hashCommit)[1]

		if (@travisRepository != nil)
			@travisRepository.each_build do |build|
				if (!build.pull_request)
					if build.commit.sha == hashCommit
						return (build.jobs.collect {|x| x.log.body }).join("\n")
					end
				end
			end
		end

		return log
	end

	def conflictScenario(mergeCommit)

		parentsMerge = getParentsMergeIfTrue(mergeCommit) #[pai1,pai2,filho]

		parentOne = nil
		parentTwo = nil

		if (parentsMerge != nil and parentsMerge.size > 1)
			projectBuilds = loadAllBuildsProject()#carregar todas as builds

			if projectBuilds[parentsMerge[0]] != nil and projectBuilds[parentsMerge[1]] != nil #se os pais encontrados existem na build
				if projectBuilds[parentsMerge[0]][0] == "passed" or projectBuilds[parentsMerge[0]][0] == "failed" #se pai1 não for errored
					parentOne = true #existe pai1 PASSED
				end

				if (projectBuilds[parentsMerge[1]][0]=="passed" or projectBuilds[parentsMerge[1]][0]=="failed")#se pai2 não for errored
					parentTwo = true #existe pai2 PASSED
				end

				if (parentOne==true and parentTwo==true and parentsMerge.size > 2)
					return true, parentsMerge
				end
			end
		end	
		
		return true, parentsMerge
	end

	def loadAllBuildsProject()
		allBuilds = Hash.new()
		if @travisRepository != nil
			@travisRepository.each_build do |build|
				if !build.pull_request
					if allBuilds[build.commit.sha] == nil
						allBuilds[build.commit.sha] = [build.state, build.id, build.number]
					elsif (allBuilds[build.commit.sha][0] != build.state)
						if (allBuilds[build.commit.sha][0] == "canceled" or build.state == 'canceled')
							allBuilds.delete(build.commit.sha)
							allBuilds[build.commit.sha] = ["canceled", build.id, build.number]
						elsif (allBuilds[build.commit.sha][0] == "passed")
							allBuilds.delete(build.commit.sha)
							allBuilds[build.commit.sha] = [build.state, build.id, build.number]
						elsif (allBuilds[build.commit.sha][0] == "errored" or build.state == 'errored')
							allBuilds.delete(build.commit.sha)
							allBuilds[build.commit.sha] = ["errored", build.id, build.number]
						else
							allBuilds.delete(build.commit.sha)
							allBuilds[build.commit.sha] == ["failed", build.id, build.number]
						end
					end
				end
			end
		else
			print "PROJECT BUILD FROM TRAVIS REPOSITORY IS NULL"
		end
		return allBuilds
	end
end

# gitProject = GitProject.new("square/okhttp", "/home/leuson/Documentos/UFPE/Doutorado/Disciplinas/TAES/Artur", "login", "senha")
#print gitProject.conflictScenario("9dfeda5")
# Retorno: [true, ["ef370dcc80839eb8a22674252d2b8f058a37c1ac", "6ad4d9856a7bfcea81d39c900eafaa226ece4bf7", "dce4bb2c1390a59ca1c3e1cb21add1aff90a3647"]]
# Primeiro elemento do array referencia se trata-se de um merge scenario valido (true or false)
# O segundo elemento informa os parents do merge scenario
#gitProject.deleteProject()