###################################
#
# EVM Automate Method: HPOM_MIQ_Server_Alert
#
# This method is used to send HPOM Alerts based on EVM Server
#
###################################
begin
  @method = 'HPOM_MIQ_Server_Alert'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true


  ###################################
  #
  # Method: buildDetails
  #
  # Notes: Build email subject and body which map to opcmsg_msg_grp and opcmsg_msg_text
  #
  # Returns: options Hash
  #
  ###################################
  def buildDetails(miq_server)

    # Build options Hash
    options = {}

    options[:object] = "EVM Server - #{miq_server.name}"

    # Set alert to alert description
    options[:alert] = $evm.root['miq_alert_description']

    # Get Appliance name from model unless specified below
    appliance = nil
    #appliance ||= $evm.object['appliance']
    appliance ||= $evm.root['miq_server'].ipaddress

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Build Email Subject
    subject = "#{options[:alert]} | EVM Server: [#{miq_server.name}]"
    options[:subject] = subject

    # Build Email Body
    body = "Attention,"
    body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
    body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
    body += "<br>Alert: #{options[:alert]}"
    body += "<br><br>"

    body += "<br>EVM Server <b>#{miq_server.name}</b> Properties:"
    body += "<br>EVM Server URL: <a href='https://#{miq_server.ipaddress}'>https://#{miq_server.ipaddress}</a>"
    body += "<br>Hostname: #{miq_server.hostname}"
    body += "<br>IP Address: #{miq_server.ipaddress}"
    body += "<br>MAC Address: #{miq_server.mac_address}"
    body += "<br>Last Heartbeat: #{miq_server.last_heartbeat}"
    body += "<br>Master: #{miq_server.is_master}"
    body += "<br>Status: #{miq_server.status}"
    body += "<br>Started On: #{miq_server.started_on}"
    body += "<br>Stopped On: #{miq_server.stopped_on}"
    body += "<br>Version: #{miq_server.version}"
    body += "<br>Zone: #{miq_server.zone}"
    body += "<br>Id: #{miq_server.id}"
    body += "<br><br>"

    body += "<br>Details:"
    body += "<br>Memory Percentage: #{miq_server.percent_memory}"
    body += "<br>Memory Usage: #{miq_server.memory_usage}"
    body += "<br>Memory Size: #{miq_server.memory_size}"
    body += "<br>CPU Percent: #{miq_server.percent_cpu}"
    body += "<br>CPU Time: #{miq_server.cpu_time}"
    body += "<br>Capabilities: #{miq_server.capabilities.inspect}"
    body += "<br><br>"

    body += "<br>Regards,"
    body += "<br>#{signature}"
    options[:body] = body

    # Return options Hash with subject, body, alert
    return options
  end


  ###################################
  #
  # Method: boolean
  # Returns: true/false
  #
  ###################################
  def boolean(string)
    return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
    return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)

    # Return false if string does not match any of the above
    $evm.log("info","#{@method} - Invalid boolean string:<#{string}> detected. Returning false") if @debug
    return false
  end


  ###################################
  #
  # Method: emailStorageAlert
  #
  # Build Alert email
  #
  ###################################
  def emailAlert(options )
    # Get to_email_address from model unless specified below
    to = nil
    to  ||= $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get subject from options Hash
    subject = options[:subject]

    # Get body from options Hash
    body = options[:body]

    $evm.log("info", "#{@method} - Sending email To:<#{to}> From:<#{from}> subject:<#{subject}>") if @debug
    $evm.execute(:send_email, to, from, subject, body)
  end


  ###################################
  #
  # Method: call_opcmsg
  #
  # Notes: Run opcmsg to send an event to HP Operations Manager
  #
  ###################################
  def call_opcmsg(options)
    opcmsg_path = "/opt/OV/bin/opcmsg"
    raise "#{@method} - File '#{opcmsg_path}' does not exist" unless File.exist?(opcmsg_path)
    $evm.log("info","#{@method} - Found opcmsg_path:<#{opcmsg_path}>") if @debug

    cmd  = "#{opcmsg_path}"
    cmd += " application=\"#{$evm.object['opcmsg_application']}\""
    cmd += " object=\"#{options[:object]}\""
    cmd += " msg_text=\"#{options[:body]}\""
    cmd += " severity=\"#{$evm.object['opcmsg_severity']}\""
    cmd += " msg_grp=\"#{options[:alert]}\""

    $evm.log("info","#{@method} - Calling:<#{cmd}>") if @debug
    require 'open4'
    pid = nil
    stderr = nil
    results = Open4.popen4(cmd) do |pid, stdin, stdout, stderr|
      stderr.each_line { |msg| $evm.log("error","#{@method} - Method STDERR:<#{msg.strip}>") }
      stdout.each_line { |msg| $evm.log("info","#{@method} - Method STDOUT:<#{msg.strip}>") }
    end
    $evm.log("info","#{@method} - Inspecting Results:<#{results.inspect}>") if @debug
  end


  miq_server = $evm.root['miq_server']

  unless miq_server.nil?
    $evm.log("info", "#{@method} - Detected EVM Server:<#{miq_server.name}>") if @debug

    # If email is set to true in the model
    options = buildDetails(miq_server)

    # Get email from model
    email = $evm.object['email']

    if boolean(email)
      emailAlert(options)
    end

    call_opcmsg(options)
  end


  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end