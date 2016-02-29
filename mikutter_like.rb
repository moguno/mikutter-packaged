#coding: UTF-8

module Packaged::Common
  extend self

  begin
    require 'Win32API'
  rescue LoadError
  end

  # _url_ を設定されているブラウザで開く
  def openurl(url)
    if defined? Win32API
      shellExecuteA = Win32API.new('shell32.dll', 'ShellExecuteA', ["p", "p", "p", "p", "p", "i"],'i')
      shellExecuteA.call(0, 'open', url, 0, 0, 1)
    else
      command = url_open_command

      if(command)
        bg_system(command, url)
      end
    end
  end

  # URLを開くことができるコマンドを返す。
  def url_open_command
    openable_commands = ["xdg-open", "open", "/etc/alternatives/x-www-browser"]
    wellknown_browsers = ["firefox", "chromium", "opera"]

    [openable_commands, wellknown_browsers].map { |list|
      list.find { |o| command_exist?(o) }
    }.find { |_| _ }
  end

  # コマンドをバックグラウンドで起動することを覗いては system() と同じ
  def bg_system(*args)
puts args
    Process.detach(spawn(*args))
  end

  # UNIXコマンド _cmd_ が存在するか否かを返す。
  def command_exist?(cmd)
    system("which #{cmd} > /dev/null")
  end
end
