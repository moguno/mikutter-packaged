
require File.join(File.dirname(__FILE__), "core.rb")




def list(argv)
  user_name = argv[0]

  get_maybe_mikutter_repos(user_name).map { |_| 
    get_spec(user_name, _["name"])
  }.compact.each { |_|
    puts _["slug"].to_s + " " + _["description"].to_s
  }
end

def install(argv)
  user_name = argv[0]
  repo_name = argv[1]

  spec = get_spec(user_name, repo_name)

  dir = File.join(PLUGIN_DIR, spec["name"])
  FileUtils.mkdir_p(dir)

  tgz = get_repo_tarball(user_name, repo_name, "master")

  extract_tgz(tgz, dir)
end

begin
  send(ARGV[0].to_sym, ARGV[1, ARGV.length - 1])
rescue => e
  puts e
  puts e.backtrace
  puts "error"
end
