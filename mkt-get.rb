
require File.join(File.dirname(__FILE__), "core.rb")

# プラグイン一覧
def list(argv)
  user_name = argv[0]

  get_maybe_mikutter_repos(user_name).map { |_| 
    get_remote_spec(user_name, _["name"])
  }.compact.each { |_|
    puts _["slug"].to_s + " " + _["description"].to_s
  }
end

# プラグインのインストール
def install(argv)
  user_name = argv[0]
  repo_name = argv[1]

  spec = get_remote_spec(user_name, repo_name)

  tgz = get_repo_tarball(user_name, repo_name, "master")

  install_plugin_by_tgz(tgz, PLUGIN_DIR)
end


# えんとりぽいんと
begin
  send(ARGV[0].to_sym, ARGV[1, ARGV.length - 1])
rescue => e
  puts e
  puts e.backtrace
  puts "error"
end
