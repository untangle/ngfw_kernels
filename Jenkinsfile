def architectures = ['amd64',
                     'arm64']

def repositories = ['buster',
                    'bullseye']

def jobs = [:] // dynamically populated later on

void buildKernel(String repository, String architecture, String upload, String buildDir) {
  sh "docker pull untangleinc/ngfw:${repository}-build-multiarch"
  sh "PKGTOOLS_COMMIT=origin/${env.BRANCH_NAME} docker-compose -f ${buildDir}/docker-compose.build.yml run pkgtools"
  sh "REPOSITORY=${repository} ARCHITECTURE=${architecture} VERBOSE=1 UPLOAD=${upload} docker-compose -f ${buildDir}/docker-compose.build.yml run build"
}

pipeline {
  agent none

  stages {
    stage('Build') {
      steps {
        script {
          for (repository in repositories) {
            for (architecture in architectures) {
              def arch = "${architecture}" // FIXME: cmon now
              def repo = "${repository}" // FIXME: cmon now
	      def name = "${arch}/${repo}"

              jobs[name] = {
                stage(name) {
                  agent { label 'docker && internal' }

		  environment {
		    upload = "ftp"
		    buildDir = "${env.HOME}/build-ngfw_kernels-${env.BRANCH_NAME}-${arch}-${env.BUILD_NUMBER}"
		  }

		  stages {
		    stage("Prep WS ${name}") {
		      steps { 
			dir(buildDir) { checkout scm } }
		    }

		    stage("Build ${name}") {
		      steps {
			buildKernel(repo, arch, upload, buildDir)
		      }
		    }
		  }
		}
              }
            }
          }

          parallel jobs
        }
      }
    }
  }
}
