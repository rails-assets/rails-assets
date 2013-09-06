# http://cbpowell.wordpress.com/2013/08/09/beautiful-logging-for-ruby-on-rails-4/
class ActiveSupport::Logger::SimpleFormatter
  SEVERITY_TO_TAG_MAP     = {'DEBUG'=>'meh', 'INFO'=>'fyi', 'WARN'=>'hmm', 'ERROR'=>'wtf', 'FATAL'=>'omg', 'UNKNOWN'=>'???'}
  SEVERITY_TO_COLOR_MAP   = {'DEBUG'=>'0;37', 'INFO'=>'32', 'WARN'=>'33', 'ERROR'=>'31', 'FATAL'=>'31', 'UNKNOWN'=>'37'}

  def call(severity, time, progname, msg)
    formatted_severity = sprintf("%-3s",SEVERITY_TO_TAG_MAP[severity])
    color = SEVERITY_TO_COLOR_MAP[severity]

    "[\033[#{color}m#{formatted_severity}\033[0m] #{msg.strip}\n"
  end
end
