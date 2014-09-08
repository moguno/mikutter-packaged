#coding: UTF-8

module Packaged::Common
  extend self

  # specファイルの内容について、扱いやすいように値を加工する
  def spec_normalization(spec)
    spec = YAML.load(spec) if spec.is_a? String
    spec["slug".freeze] = spec["slug".freeze].to_sym
    spec
  end
end
