#coding: UTF-8

require 'rubygems'
require 'gtk2'

require File.join(File.dirname(__FILE__), "core.rb")
require File.join(File.dirname(__FILE__), "mikutter_like.rb")

# GUI用ネームスペース
module Packaged::GUI
end

# プラグインのインストールダイアログ
module Packaged::GUI::Install
  extend self

  @widgets = {}
  @user_name = ""
  @result = nil

  # カラム定義
  @columns = Packaged::Common::ColumnHelper.new

  @columns.add(:status, {:name => "状態", :visible => true, :type => String})
  @columns.add(:name, {:name => "名前", :visible => true, :type => String})
  @columns.add(:description, {:name => "説明", :visible => true, :type => String})
  @columns.add(:fore_color, {:name => "文字色", :visible => false, :type => String})
  @columns.add(:info, {:name => "情報オブジェクト", :visible => false, :type => Hash})

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
          info = widgets[:list].selection.selected[@columns[:info].index]
          repo_name = info[:repo_name]

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

    @columns.select { |_| _.visible }.each { |column|
      col = Gtk::TreeViewColumn.new(column.name, renderer, :foreground => @columns[:fore_color].index, :text => column.index)
      result[:list].append_column(col)
    }

    result[:store] = create_liststore
    result[:list].set_model(reload_liststore(result[:store]))

    # 選択行が変更された
    result[:list].signal_connect(:cursor_changed) {
      if result[:list].selection.selected
        info = result[:list].selection.selected[@columns[:info].index]

        set_button_state(info[:status] != :installed)
      end
    }

    # 行をダブルクリックした
    result[:list].signal_connect(:row_activated) {
      if result[:list].selection.selected
        info = widgets[:list].selection.selected[@columns[:info].index]
        repo_name = info[:repo_name]

        Packaged::Common::openurl("http://github.com/#{@user_name}/#{repo_name}")
      end
    } 

    result[:scrolled_list] = Gtk::ScrolledWindow.new
    result[:scrolled_list].set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)

    result[:scrolled_list].add(result[:list])

    result
  end

  # リストストアを作る
  def create_liststore
    store = Gtk::ListStore.new(*@columns.map { |_| _.type })
    store.set_sort_column_id(@columns[:name].index)
  end

  # リストビューに表示するデータを更新する
  def reload_liststore(store, user_name = nil)
    status_str = {
      :installed => { :str => "インストール済み", :color => "blue" },
      :not_installed => { :str => "未インストール", :color => "black" },
    }

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
        values = {
          :status => status_str[_[:status]][:str],
          :name => _[:spec]["slug"],
          :description => _[:spec]["description"],
          :info => _,
          :fore_color => status_str[_[:status]][:color],
        }

        item = store.append
        store.set_values(item, @columns.make_values(values))
      }
    end

    store
  rescue => e
    Packaged::GUI::error_box(widgets[:window], "エラー\n#{e.message}\n#{e.backtrace.join("\n")}")
  end
end
