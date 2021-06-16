void buildKernel(String repository, String architecture, String upload, String buildDir) {
  sh "docker pull untangleinc/ngfw:${repository}-build-${architecture}"
  sh "PKGTOOLS_COMMIT=origin/${env.BRANCH_NAME} docker-compose -f ${buildDir}/docker-compose.build.yml run pkgtools"
  sh "ARCHITECTURE=${architecture} VERBOSE=1 UPLOAD=${upload} docker-compose -f ${buildDir}/docker-compose.build.yml run build"
}

pipeline {
  agent none

  stages {
    stage('Build') {

      parallel {
        stage('buster/amd64') {
	  agent { label 'docker && internal' }

          environment {
	    repository = "buster"
            architecture = "amd64"
	    upload = "ftp"
            buildDir = "${env.HOME}/build-ngfw_kernels-${env.BRANCH_NAME}-${architecture}-${env.BUILD_NUMBER}"
          }

	  stages {
            stage('Prep WS buster/amd64') {
              steps { 
                dir(buildDir) { checkout scm } }
            }

            stage('Build amd64') {
              steps {
                buildKernel(repository, architecture, upload, buildDir)
              }
            }
          }
        }

        stage('buster/arm64') {
	  agent { label 'docker && internal' }

          environment {
	    repository = "buster"
            architecture = "arm64"
	    upload = "ftp"
            buildDir = "${env.HOME}/build-ngfw_kernels-${env.BRANCH_NAME}-${architecture}-${env.BUILD_NUMBER}"
          }

	  stages {
            stage('Prep WS buster/arm64') {
              steps {
                dir(buildDir) { checkout scm } }
            }

            stage('Build buster/arm64') {
              steps {
                buildKernel(repository, architecture, upload, buildDir)
              }
            }
          }

        }

      }

    }
  }
}
