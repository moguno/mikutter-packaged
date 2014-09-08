#coding: UTF-8

module Packaged::GUI
  extend self

  # リストビューのカラムを使いやすくするクラス
  class ColumnHelper

    # コンストラクタ
    def initialize
      @columns = {}
      @index = 0
    end

    # カラム情報を登録
    def add(symbol, data)
      struct = OpenStruct.new(data)
      struct.index = @index
      struct.freeze

      @columns[symbol] = struct

      @index += 1
    end

    # カラム情報を参照
    def [](symbol)
      @columns[symbol]
    end

    # 値をカラム順に格納したファイルを作る
    def make_values(hash)
      values = @columns.map { |_| "" }

      hash.each { |k, v|
        values[@columns[k].index] = v
      }

      values
    end

     # Enumerable用
    def each(&block)
      @columns.values.each { |_| block.call(_) }
    end

    include Enumerable
  end

  # エラー用メッセージボックス
  def error_box(parent, message)
    dialog = Gtk::MessageDialog.new(parent, Gtk::Dialog::DESTROY_WITH_PARENT, Gtk::MessageDialog::ERROR, Gtk::MessageDialog::BUTTONS_OK, message)
    dialog.run
    dialog.destroy
  end
end
