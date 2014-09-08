#coding: UTF-8

module Packaged::Remote
  extend self

  # 例外
  class RemoteException < StandardError
    attr_reader :obj

    def initialize(obj)
      @obj = obj
    end

    def message
      if @obj.respond_to?(:inspect)
        @obj.inspect
      else
        @obj.to_s
      end
    end
  end

  # 生ファイルを要求する
  def query_raw_file(url_str, limit = 3)
    puts url_str

    if limit == 0
      raise RemoteException.new("redirect limit exceeded")
    end

    response = Net::HTTP::get_response(URI.parse(url_str))

    case response
    # 成功
    when Net::HTTPSuccess
      response.body
    # リダイレクト
    when Net::HTTPRedirection
      query_raw_file(response["location"], limit - 1)
    else
      raise RemoteException.new(response)
    end
  end

  # YAMLを要求する
  def query(url_str)
    yaml = query_raw_file(url_str)

    if yaml
      YAML.load(yaml)
    else
      nil
    end
  end

  # GitHubからリポジトリの一覧を得る
  def get_repos(user_name)
    query("https://api.github.com/users/#{user_name}/repos?per_page=100")
  end

  # 多分mikutterプラグインのリポジトリを選別する
  def get_maybe_mikutter_repos(user_name)
    repos = get_repos(user_name)

    if repos
      repos.select { |_| _["name"].to_s =~ /mikutter/i }
    else
      []
    end
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

  # プラグインの情報を得る
  def get_plugin_info(user_name, repo_name)
    result = {}

    result[:repo_name] = repo_name
    result[:spec] = Packaged::Remote::get_spec(user_name, repo_name)

    local_info = Packaged::Local::get_plugin_info_by_slug(result[:spec]["slug"])

    result[:status] = if local_info
      :installed
    else
      :not_installed
    end

    result
  end

  # GitHubからSPECファイルを取得する
  def get_spec(user_name, repo_name)
    result = nil

    [".mikutter.yml", "spec"].each { |path|
      begin
        result = Packaged::Common::spec_normalization(get_file(user_name, repo_name, "master", path))
        break
      rescue
        # 例外は無視
      end
    }

    if !result
      raise RemoteException.new("spec file is not found")
    end

    result
  end
end
