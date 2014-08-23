require 'net/https'
require 'yaml'

# クエリー
def query(url_str)
  str = Net::HTTP.get(URI.parse(url_str))
  YAML.load(str)
end

# GitHubからリポジトリの一覧を得る
def get_repos(user_name)
  query("https://api.github.com/users/#{user_name}/repos")
end

# GitHubのタグを得る
def get_tags(user_name, repo_name)
  query("https://api.github.com/repos/#{user_name}/#{repo_name}/tags")
end

# HTTPでファイルを取得する
def get_file(user_name, repo_name, tag, path)
  url = URI.parse("https://raw.githubusercontent.com/#{user_name}/#{repo_name}/#{tag}/#{path}")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  get = Net::HTTP::Get.new(url.path)

  response = http.request(get)

  if response.code == "200"
    response.body
  else
    nil
  end
end

# SPECファイルを取得する
def get_spec(user_name, repo_name)
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

# 多分mikutterプラグインのリポジトリを選別する
def get_maybe_mikutter_repos(user_name)
  repos = get_repos(user_name)

  repos.select { |_| _["name"] =~ /mikutter/i }
end


if __FILE__ == $0
  get_maybe_mikutter_repos("moguno").map { |_| 
    get_spec("moguno", _["name"])
  }.compact.each { |_|
    puts _["slug"].to_s + " " + _["description"].to_s
  }
end
