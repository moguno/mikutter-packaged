require 'net/https'
require 'yaml'
require 'zlib'
require 'archive/tar/minitar'

PLUGIN_DIR = File::expand_path("~/.mikutter/plugin")

# 生ファイルを要求する
def query_raw_file(url_str, limit = 3)
  if limit == 0
    return nil
  end

  url = URI.parse(url_str)

  http = Net::HTTP.new(url.host, url.port)

  if url.scheme == "https"
    http.use_ssl = true
  end

  get = Net::HTTP::Get.new(url.path)

  response = http.request(get)

  case response
  # 成功
  when Net::HTTPSuccess
    response.body
  # リダイレクト
  when Net::HTTPRedirection
    query_raw_file(response["location"], limit - 1)
  else
    nil
  end
end

# YAMLを要求する
def query(url_str)
  yaml = query_raw_file(url_str)
  YAML.load(yaml)
end

# GitHubからリポジトリの一覧を得る
def get_repos(user_name)
  query("https://api.github.com/users/#{user_name}/repos")
end

# GitHubのタグを得る
def get_tags(user_name, repo_name)
  query("https://api.github.com/repos/#{user_name}/#{repo_name}/tags")
end

# GitHubからファイルを取得する
def get_file(user_name, repo_name, tag, path)
  query_raw_file("https://raw.githubusercontent.com/#{user_name}/#{repo_name}/#{tag}/#{path}")
end

# リポジトリのtarボールを取得する
def get_repo_tarball(user_name, repo_name, tag)
  query_raw_file("https://api.github.com/repos/#{user_name}/#{repo_name}/tarball/#{tag}")
end

# GitHubからSPECファイルを取得する
def get_remote_spec(user_name, repo_name)
  result = nil

  [".mikutter.yml", "spec"].each { |path|
    tmp = get_file(user_name, repo_name, "master", path)

    if tmp
      result = YAML.load(tmp)
      break
    end
  }

  result
end

# ローカルのファイルシステムからSPECファイルを取得する
def get_local_spec(dir)
  result = nil

  [".mikutter.yml", "spec"].each { |path|
    file = File.join(dir, path)

    if File.exist?(file)
      yaml_str = File.open(file) { |fp|
        fp.read
      }

      result = YAML.load(yaml_str)
      break
    end
  }

  result
end

# 多分mikutterプラグインのリポジトリを選別する
def get_maybe_mikutter_repos(user_name)
  repos = get_repos(user_name)

  repos.select { |_| _["name"].to_s =~ /mikutter/i }
end

# tarボールを展開するぞなもし
def extract_tgz(tgz_string, dest_dir)
  root_dir = nil

  tgz = StringIO.new(tgz_string)

  Zlib::GzipReader.wrap(tgz) { |tar|
    Archive::Tar::Minitar::unpack(tar, dest_dir) { |status, file|
      if !root_dir && (status == :dir)
        root_dir = file
      end
    }
  }

  root_dir
end

# tarボールをプラグインディレクトリにええ感じにインストールする
def install_plugin_by_tgz(tgz_string, plugin_dir = PLUGIN_DIR)
  root_dir = extract_tgz(tgz_string, plugin_dir)

  extracted_dir = File.join(plugin_dir, root_dir)

  spec = get_local_spec(extracted_dir)

  FileUtils.mv(extracted_dir, File.join(plugin_dir, spec["slug"].to_s)) 
end
