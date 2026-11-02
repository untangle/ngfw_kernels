def supportedArchitectures = ['amd64', 'arm64']

def repositories = ['bullseye']

def jobs = [:] // dynamically populated later on

def credentialsId = 'buildbot'

def packageServerIp = '172.30.0.60'

void buildKernel(String repository, String architecture, String upload, String buildDir, String packageServerIp, String credentialsId) {
  sshagent (credentials:[credentialsId]) {
    sh "docker pull untangleinc/ngfw:${repository}-build-multiarch"
    sh "PKGTOOLS_COMMIT=origin/${env.BRANCH_NAME} docker-compose -f ${buildDir}/docker-compose.build.yml run pkgtools"
    sh "REPOSITORY=${repository} ARCHITECTURE=${architecture} PACKAGE_SERVER_IP=${packageServerIp} VERBOSE=1 UPLOAD=${upload} docker-compose -f ${buildDir}/docker-compose.build.yml run build"
  }
}

pipeline {
  agent none

  parameters {
    string(name: 'NODE_LABEL', defaultValue: 'aws-build-03', description: 'Jenkins node label to run kernel builds on')
    choice(name: 'ARCHITECTURE', choices: ['both', 'amd64', 'arm64'], description: 'Architecture(s) to build')
  }

  stages {
    stage('Build') {
      steps {
        script {
          def selectedArchitecture = params.ARCHITECTURE ?: 'both'
          def architectures = selectedArchitecture == 'both' ? supportedArchitectures : [selectedArchitecture]

          for (repository in repositories) {
            for (architecture in architectures) {
              def arch = "${architecture}" // FIXME: cmon now
              def repo = "${repository}" // FIXME: cmon now
	      def name = "${arch}/${repo}"

              jobs[name] = {
                node(env.NODE_LABEL ?: 'aws-build-03') {
		  stage(name) {
                    def upload = "scp"
                    def buildDir = "${env.HOME}/build-ngfw_kernels-${env.BRANCH_NAME}-${arch}-${env.BUILD_NUMBER}"

                    dir(buildDir) {
                      checkout scm

                      buildKernel(repo, arch, upload, buildDir, packageServerIp, credentialsId)
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
