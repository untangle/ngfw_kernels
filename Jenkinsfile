void build(String repository, String architecture, String upload, String buildDir) {
  sh "docker pull untangleinc/ngfw:${repository}-build-${architecture}"
  sh "PKGTOOLS_COMMIT=origin/${env.BRANCH_NAME} ${buildDir}/docker-compose -f docker-compose.build.yml run pkgtools"
//  sh "ARCHITECTURE=${architecture} VERBOSE=1 UPLOAD=${upload} docker-compose -f ${buildDir}/docker-compose.build.yml run build"
  sh "ARCHITECTURE=${architecture} TRAVIS_BRANCH=${env.BRANCH_NAME} VERBOSE=1 UPLOAD= docker-compose -f ${buildDir}/docker-compose.build.yml run build"
}

pipeline {
  agent none

  stages {
    stage('Build') {

      parallel {
        stage('amd64') {
	  agent { label 'mfw' }

          environment {
            architecture = "amd64"
	    upload = "ftp"
            buildDir = "${env.HOME}/build-ngfw_kernels-${env.BRANCH_NAME}-${architecture}"
          }

	  stages {
            stage('Prep WS amd64') {
              steps { dir(buildDir) { checkout scm } }
            }

            stage('Build amd64') {
              steps {
                buildMFW("buster", architecture, upload, buildDir)
              }
            }
          }

        }

        stage('i386') {
	  agent { label 'mfw' }

          environment {
            architecture = "i386"
	    upload = "ftp"
            buildDir = "${env.HOME}/build-ngfw_kernels-${env.BRANCH_NAME}-${architecture}"
          }

	  stages {
            stage('Prep WS i386') {
              steps { dir(buildDir) { checkout scm } }
            }

            stage('Build i386') {
              steps {
                buildMFW("buster", architecture, upload, buildDir)
              }
            }
          }

        }

      }
    }
  }
}
