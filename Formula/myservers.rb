class Myservers < Formula
  version "1.0"
  url "file:///dev/null"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  DEPENDENT_SERVICES = [
    "mariadb",
    "nginx",
    "php",
  ]

  DEPENDENT_SERVICES.each { |service| depends_on service }

  def install
    starters = DEPENDENT_SERVICES.map do |service|
      "brew services start #{service}"
    end

    stoppers = DEPENDENT_SERVICES.map do |service|
      [
        "launchctl bootout system #{Formula[service].plist_path}",
        "launchctl bootout gui/$(id -u) #{Formula[service].plist_path}",
      ].join(" || ")
    end

    (bin/name).write <<~EOS
      #!/bin/bash

      function log {
        printf '[%s] %s\\n' "$(date '+%F %X')" "$1" >&2
      }

      function __cleanup {
        log 'Stopping #{plist_name}'
        trap '' EXIT INT HUP TERM
        #{ stoppers.join("; ") }
        log 'Cleaning up'
        brew services cleanup
        log 'All services stopped'
        trap - EXIT INT HUP TERM
        exit
      }

      trap __cleanup EXIT INT HUP TERM
      log 'Starting #{plist_name}'
      export HOME=~
      #{ starters.join("; ") }
      log "Sleeping"
      while true; do
        sleep 60 & wait
      done
    EOS
  end

  plist_options(:startup => true)

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>EnvironmentVariables</key>
        <dict>
          <key>PATH</key>
          <string>/usr/bin:/bin:/usr/sbin:/sbin:#{HOMEBREW_PREFIX}/bin</string>
        </dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{bin/name}</string>
        <key>RunAtLoad</key>
        <true/>
        <key>ExitTimeOut</key>
        <integer>#{(DEPENDENT_SERVICES.size + 1) * 30}</integer>
        <key>StandardErrorPath</key>
        <string>#{var}/log/#{name}/#{name}.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/#{name}/#{name}.log</string>
      </dict>
    </plist>
    EOS
  end
end
