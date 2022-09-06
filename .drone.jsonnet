local name = "rocketchat";
local rocketchat_version = "5.1.0";
local node_version = "14.19.3-slim";
local mongo_version = "5.0.11";
local browser = "firefox";

local build(arch, test_ui) = [{
    kind: "pipeline",
    type: "docker",
    name: arch,
    platform: {
        os: "linux",
        arch: arch
    },
    steps: [
    {
        name: "version",
        image: "debian:buster-slim",
        commands: [
            "echo $DRONE_BUILD_NUMBER > version"
        ]
    },
    {
        name: "download",
        image: "debian:buster-slim",
        commands: [
            "./download.sh " + name
        ]
    },
    {
        name: "build",
        image: "debian:buster-slim",
        commands: [
            "./node/build.sh " + node_version + " " + rocketchat_version
        ],
        volumes: [
            {
                name: "docker",
                path: "/usr/bin/docker"
            },
            {
               name: "docker.sock",
               path: "/var/run/docker.sock"
            }
        ]
    },
    {
        name: "package mongo",
        image: "debian:buster-slim",
        commands: [
            "./mongo/build.sh " + mongo_version
        ],
        volumes: [
            {
                name: "docker",
                path: "/usr/bin/docker"
            },
            {
               name: "docker.sock",
               path: "/var/run/docker.sock"
            }
        ]
    },
    {
        name: "package python",
        image: "debian:buster-slim",
        commands: [
            "./python/build.sh"
        ],
        volumes: [
            {
                name: "docker",
                path: "/usr/bin/docker"
            },
            {
                name: "docker.sock",
                path: "/var/run/docker.sock"
            }
        ]
    },
    {
        name: "package",
        image: "debian:buster-slim",
        commands: [
            "VERSION=$(cat version)",
            "./package.sh " + name + " $VERSION " + arch
        ]
    }
    ] + ( if arch == "amd64" then [
    {
        name: "test-integration-jessie",
        image: "python:3.8-slim-buster",
        commands: [
          "APP_ARCHIVE_PATH=$(realpath $(cat package.name))",
          "cd integration",
          "./deps.sh",
          "py.test -x -s verify.py --device-user=testuser --distro=jessie --domain=jessie.com --app-archive-path=$APP_ARCHIVE_PATH --device-host=" + name + ".jessie.com --app=" + name
        ]
    }] else []) + [
    {
        name: "test-integration-buster",
        image: "python:3.8-slim-buster",
        commands: [
          "APP_ARCHIVE_PATH=$(realpath $(cat package.name))",
          "cd integration",
          "./deps.sh",
          "py.test -x -s verify.py --device-user=testuser --distro=buster --domain=buster.com --app-archive-path=$APP_ARCHIVE_PATH --device-host=" + name + ".buster.com --app=" + name + " --arch=" + arch
        ]
    }] + ( if test_ui then [
    {
        name: "selenium-video",
        image: "selenium/video:ffmpeg-4.3.1-20220208",
        detach: true,
        environment: {
            "DISPLAY_CONTAINER_NAME": "selenium",
            "PRESET": "-preset ultrafast -movflags faststart"
        },
        volumes: [
            {
                name: "shm",
                path: "/dev/shm"
            },
           {
                name: "videos",
                path: "/videos"
            }
        ]
    },
    {
        name: "test-ui-desktop-jessie",
        image: "python:3.8-slim-buster",
        commands: [
          "cd integration",
          "./deps.sh",
          "py.test -x -s test-ui.py --device-user=testuser --distro=jessie --ui-mode=desktop --domain=jessie.com --device-host=" + name + ".jessie.com --app=" + name + " --browser=" + browser,
        ],
        volumes: [{
            name: "shm",
            path: "/dev/shm"
        }]
    },
    {
        name: "test-ui-mobile-jessie",
        image: "python:3.8-slim-buster",
        commands: [
          "cd integration",
          "./deps.sh",
          "py.test -x -s test-ui.py --device-user=testuser --distro=jessie --ui-mode=mobile --domain=jessie.com --device-host=" + name + ".jessie.com --app=" + name + " --browser=" + browser,
        ],
        volumes: [{
            name: "shm",
            path: "/dev/shm"
        }]
    },
    {
        name: "test-ui-desktop-buster",
        image: "python:3.8-slim-buster",
        commands: [
          "apt-get update && apt-get install -y sshpass openssh-client libxml2-dev libxslt-dev build-essential libz-dev curl",
          "cd integration",
          "pip install -r requirements.txt",
          "py.test -x -s test-ui.py --device-user=testuser --distro=buster --ui-mode=desktop --domain=buster.com --device-host=" + name + ".buster.com --app=" + name + " --browser=" + browser,
        ]
    },
    {
        name: "test-ui-mobile-buster",
        image: "python:3.8-slim-buster",
        commands: [
          "cd integration",
          "./deps.sh",
          "py.test -x -s test-ui.py --device-user=testuser --distro=buster --ui-mode=mobile --domain=buster.com --device-host=" + name + ".buster.com --app=" + name + " --browser=" + browser,
        ]
    } ] else [] ) +
   ( if arch == "amd64" then [
    {
        name: "test-upgrade",
        image: "python:3.8-slim-buster",
        commands: [
          "APP_ARCHIVE_PATH=$(realpath $(cat package.name))",
          "cd integration",
          "./deps.sh",
          "py.test -x -s test-upgrade.py --device-user=testuser --distro=buster --ui-mode=desktop --domain=buster.com --app-archive-path=$APP_ARCHIVE_PATH --device-host=" + name + ".buster.com --app=" + name + " --browser=" + browser,
        ],
        privileged: true,
        volumes: [{
            name: "videos",
            path: "/videos"
        }]
    } ] else [] ) + [
    {
        name: "upload",
        image: "debian:buster-slim",
        environment: {
            AWS_ACCESS_KEY_ID: {
                from_secret: "AWS_ACCESS_KEY_ID"
            },
            AWS_SECRET_ACCESS_KEY: {
                from_secret: "AWS_SECRET_ACCESS_KEY"
            }
        },
        commands: [
          "PACKAGE=$(cat package.name)",
          "apt update && apt install -y wget",
          "wget https://github.com/syncloud/snapd/releases/download/1/syncloud-release-" + arch,
          "chmod +x syncloud-release-*",
          "./syncloud-release-* publish -f $PACKAGE -b $DRONE_BRANCH"
         ],
        when: {
            branch: ["stable", "master"]
        }
    },
    {
        name: "artifact",
        image: "appleboy/drone-scp:1.6.2",
        settings: {
            host: {
                from_secret: "artifact_host"
            },
            username: "artifact",
            key: {
                from_secret: "artifact_key"
            },
            timeout: "2m",
            command_timeout: "2m",
            target: "/home/artifact/repo/" + name + "/${DRONE_BUILD_NUMBER}-" + arch,
            source: [
                "artifact/*"
            ],
            privileged: true,
            strip_components: 1,
            volumes: [
               {
                    name: "videos",
                    path: "/drone/src/artifact/videos"
                }
            ]
        },
        when: {
          status: [ "failure", "success" ]
        }
    }
    ],
    trigger: {
      event: [
        "push",
        "pull_request"
      ]
    },
    services: ( if arch == "amd64" then [
        {
            name: name + ".jessie.com",
            image: "syncloud/platform-jessie-" + arch,
            privileged: true,
            volumes: [
                {
                    name: "dbus",
                    path: "/var/run/dbus"
                },
                {
                    name: "dev",
                    path: "/dev"
                }
            ]
        }] else []) + [
        {
            name: name + ".buster.com",
            image: "syncloud/platform-buster-" + arch + ":22.01",
            privileged: true,
            volumes: [
                {
                    name: "dbus",
                    path: "/var/run/dbus"
                },
                {
                    name: "dev",
                    path: "/dev"
                }
            ]
        }
    ] + ( if test_ui then [
        {
            name: "selenium",
            image: "selenium/standalone-" + browser + ":4.1.2-20220208",
            environment: {
                SE_NODE_SESSION_TIMEOUT: "999999"
            },
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        }
    ] else [] ),
    volumes: [
        {
            name: "dbus",
            host: {
                path: "/var/run/dbus"
            }
        },
        {
            name: "dev",
            host: {
                path: "/dev"
            }
        },
        {
            name: "shm",
            temp: {}
        },
        {
            name: "videos",
            temp: {}
        },
        {
            name: "docker",
            host: {
                path: "/usr/bin/docker"
            }
        },
        {
            name: "docker.sock",
            host: {
                path: "/var/run/docker.sock"
            }
        }
    ]
},
{
     kind: "pipeline",
     type: "docker",
     name: "promote-" + arch,
     platform: {
         os: "linux",
         arch: arch
     },
     steps: [
     {
             name: "promote",
             image: "debian:buster-slim",
             environment: {
                 AWS_ACCESS_KEY_ID: {
                     from_secret: "AWS_ACCESS_KEY_ID"
                 },
                 AWS_SECRET_ACCESS_KEY: {
                     from_secret: "AWS_SECRET_ACCESS_KEY"
                 }
             },
             commands: [
               "apt update && apt install -y wget",
               "wget https://github.com/syncloud/snapd/releases/download/1/syncloud-release-" + arch + " -O release --progress=dot:giga",
               "chmod +x release",
               "./release promote -n " + name + " -a $(dpkg --print-architecture)"
             ]
       }
      ],
      trigger: {
       event: [
         "promote"
       ]
     }
 }];

build("amd64", true) + build("arm64", false)





