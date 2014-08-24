#! /usr/bin/env ruby
#coding: UTF-8

require File.join(File.dirname(__FILE__), "core.rb")

# リモートのプラグイン一覧
def list(argv)
  user_name = argv[0]

  Packaged::Remote::get_maybe_mikutter_repos(user_name).map { |_| 
    Packaged::Remote::get_spec(user_name, _["name"])
  }.compact.each { |_|
    puts _["slug"].to_s + " " + _["description"].to_s
  }
end

# ローカルのプラグイン一覧
def local_list(argv)
  Packaged::Local::get_plugins.select { |_| _[:status] != :unmanaged  }.each { |info|
    puts "[#{info[:status].to_s}] #{info[:spec]["author"]}::#{info[:spec]["slug"]} #{info[:spec]["description"]}"
  }
end

# プラグインのインストール
def install(argv)
  user_name = argv[0]
  repo_name = argv[1]

  if Packaged::Local::get_plugins.find { |_| _[:spec] && (_[:spec]["slug"] == repo_name.to_sym) }
    raise "既にインストールされています"
  end

  spec = Packaged::Remote::get_spec(user_name, repo_name)

  tgz = Packaged::Remote::get_repo_tarball(user_name, repo_name, "master")

  Packaged::Local::install_plugin_by_tgz(tgz, PLUGIN_DIR)
end

# プラグインの無効化
def disable(argv)
  slug = argv[0]

  Packaged::Local::disable_plugin(slug)
end

# プラグインの有効化
def enable(argv)
  slug = argv[0]

  Packaged::Local::enable_plugin(slug)
end

# えんとりぽいんと
begin
  send(ARGV[0].to_sym, ARGV[1, ARGV.length - 1])
rescue => e
  puts e
  puts e.backtrace
  puts "error"
end
