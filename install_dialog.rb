#coding: UTF-8

require 'rubygems'
require 'gtk2'

require File.join(File.dirname(__FILE__), "core.rb")

# GUI用ネームスペース
module Packaged::GUI
end

# プラグインのインストールダイアログ
module Packaged::GUI::Install
  extend self

  @widgets = {}
  @user_name = ""
  @result = nil

  # 使ってるウィジェットとかのハッシュを返す
  def widgets
    @widgets
  end

  # ダイアログの結果を返す
  def result
    @result
  end

  # OKボタンの状態を設定する
  def set_button_state(status)
    widgets[:window].set_response_sensitive(Gtk::Dialog::RESPONSE_OK, status)
  end

  # ウインドウを構築する
  def create_window(parent_window)
    widgets[:window] = Gtk::Dialog.new("プラグインのインストール", parent_window, Gtk::Dialog::MODAL)
    widgets[:window].set_default_size(640, 480)

    widgets[:window].add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    widgets[:window].add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)

    # ダイアログが何らかの理由で閉じられるとき
    widgets[:window].signal_connect(:response) { |w, res|
      begin
        case res
        when Gtk::Dialog::RESPONSE_OK
          # プラグインのインストール
          repo_name = widgets[:list].selection.selected[2][:repo_name]

          tgz = Packaged::Remote::get_repo_tarball(@user_name, repo_name, "master")

          Packaged::Local::install_plugin_by_tgz(tgz)
        end

        widgets[:window].destroy

        @result = res

      rescue => e
        Packaged::GUI::error_box(widgets[:window], "エラー\n#{e.message}\n#{e.backtrace.join("\n")}")
      end
    }

    widgets[:box] = widgets[:window].vbox

    widgets[:search_box] = Gtk::HBox.new

    widgets[:user_label] = Gtk::Label.new
    widgets[:user_label].text = "GitHubユーザ名"

    widgets[:user_text] = Gtk::Entry.new
    widgets[:user_text].signal_connect(:activate) {
      widgets[:search_button].clicked
    }

    widgets[:search_button] = Gtk::Button.new
    widgets[:search_button].label = "リポジトリ検索"

    # 検索ボタンクリック
    widgets[:search_button].signal_connect(:clicked) { |w|
      @user_name = widgets[:user_text].buffer.text

      widgets[:search_button].label = "検索中"
      widgets[:search_button].sensitive = false
      widgets[:user_text].sensitive = false

      while(Gtk::events_pending?)
        Gtk::main_iteration
      end

      reload_liststore(widgets[:store], @user_name)

      widgets[:search_button].label = "リポジトリ検索"
      widgets[:search_button].sensitive = true
      widgets[:user_text].sensitive = true
    }

    widgets[:search_box].pack_start(widgets[:user_label], false)
    widgets[:search_box].pack_start(widgets[:user_text], true)
    widgets[:search_box].pack_start(widgets[:search_button], false)

    widgets.merge!(create_listview_box)

    widgets[:window].add(widgets[:box])
    widgets[:box].pack_start(widgets[:search_box], false)
    widgets[:box].pack_start(widgets[:scrolled_list], true)

    set_button_state(false)

    widgets[:box].show_all

    widgets
  end

  # リストビューを構築する
  def create_listview_box
    result = {}

    result[:list] = Gtk::TreeView.new
    result[:list].set_width_request(10)

    renderer = Gtk::CellRendererText.new

    ["名前", "説明" ].each_with_index { |col_name, i|
      col = Gtk::TreeViewColumn.new(col_name, renderer, :text => i)
      result[:list].append_column(col)
    }

    result[:store] = create_liststore
    result[:list].set_model(reload_liststore(result[:store]))

    # 選択行が変更された
    result[:list].signal_connect(:cursor_changed) {
      if result[:list].selection.selected
        slug = result[:list].selection.selected[0]

        info = Packaged::Local::get_plugin_info_by_slug(slug)

        set_button_state(info == nil)
      end
    }

    result[:scrolled_list] = Gtk::ScrolledWindow.new
    result[:scrolled_list].set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)

    result[:scrolled_list].add(result[:list])

    result
  end

  # リストストアを作る
  def create_liststore
    store = Gtk::ListStore.new(String, String, Hash)
    store.set_sort_column_id(0)
  end

  # リストビューに表示するデータを更新する
  def reload_liststore(store, user_name = nil)
    store.clear

    if user_name
      results = []

      Packaged::Remote::get_maybe_mikutter_repos(user_name).map { |_| 
        Thread.start {
          begin
            results << Packaged::Remote::get_plugin_info(user_name, _["name"])
          rescue => e
          end
        }
      }.each { |t|
        t.join
      }

      results.each { |_|
        item = store.append
        store.set_values(item, [_[:spec]["slug"], _[:spec]["description"], _])
      }
    end

    store
  rescue => e
    Packaged::GUI::error_box(widgets[:window], "エラー\n#{e.message}\n#{e.backtrace.join("\n")}")
  end
end
