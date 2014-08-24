#coding: UTF-8

require "gtk2"

require File.join(File.dirname(__FILE__), "core.rb")

# GUI用ネームスペース
module Packaged::GUI
end

# プラグインのインストールダイアログ
module Packaged::GUI::Install
  module_function

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
      case res
      when Gtk::Dialog::RESPONSE_OK
        # プラグインのインストール
        repo_name = widgets[:list].selection.selected[0]

        tgz = Packaged::Remote::get_repo_tarball(@user_name, repo_name, "master")

        Packaged::Local::install_plugin_by_tgz(tgz)
      end

      widgets[:window].destroy

      @result = res
    }

    widgets[:box] = widgets[:window].vbox

    widgets[:search_box] = Gtk::HBox.new

    widgets[:user_label] = Gtk::Label.new
    widgets[:user_label].text = "GitHubユーザ名"

    widgets[:user_text] = Gtk::Entry.new

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
    store = Gtk::ListStore.new(String, String)
    store.set_sort_column_id(1)
  end

  # リストビューに表示するデータを更新する
  def reload_liststore(store, user_name = nil)
    store.clear

    if user_name
      Packaged::Remote::get_maybe_mikutter_repos(user_name).map { |_| 
        Packaged::Remote::get_spec(user_name, _["name"])
      }.compact.each { |_|
        item = store.append
        store.set_values(item, [_["slug"], _["description"]])
      }
    end

    store
  end
end

# メインウインドウ
module Packaged::GUI::Main
  module_function

  @widgets = {}

  # 使ってるウィジェットとかのハッシュを返す
  def widgets
    @widgets
  end

  # インストールボタン押下
  def menu_install(actiongroup, action)
    Packaged::GUI::Install.create_window(widgets[:window])

    Packaged::GUI::Install::widgets[:window].run

    if Packaged::GUI::Install::result == Gtk::Dialog::RESPONSE_OK
      reload_liststore(widgets[:store])
    end
  end

  # アンインストールボタン押下
  def menu_uninstall(actiongroup, action)
  end

  # 有効化ボタン押下
  def menu_enable(actiongroup, action)
    slug = widgets[:list].selection.selected[2]

    Packaged::Local::enable_plugin(slug)

    reload_liststore(widgets[:store])
  end

  # 無効化ボタン押下
  def menu_disable(actiongroup, action)
    slug = widgets[:list].selection.selected[2]

    Packaged::Local::disable_plugin(slug)

    reload_liststore(widgets[:store])
  end

  # ツールバー構築用XML
  TOOLBAR = <<EOF
<ui>
  <toolbar name="Toolbar">
    <toolitem action="install" />
    <separator />
<!---
    <toolitem action="uninstall" />
--->
    <toolitem action="enable" />
    <toolitem action="disable" />
  </toolbar>
</ui>
EOF

  # ツールバーを構築する
  def create_toolbar
    result = {}

    result[:action_group] = Gtk::ActionGroup.new("main")

    items = [
      [ "install", nil, "インストール", nil, nil, method(:menu_install) ],
      [ "uninstall", nil, "アンインストール", nil, nil, method(:menu_uninstall) ],
      [ "enable", nil, "有効化", nil, nil, method(:menu_enable) ],
      [ "disable", nil, "無効化", nil, nil, method(:menu_disable) ],
    ]

    result[:action_group].add_actions(items)

    result[:ui_manager] = Gtk::UIManager.new

    result[:ui_manager].insert_action_group(result[:action_group], 0)
    result[:ui_manager].add_ui(TOOLBAR)

    result[:toolbar] = result[:ui_manager].get_widget("/Toolbar")

    result
  end

  def create_window
    widgets[:window] = Gtk::Window.new("mikutterプラグインマネージャ \"Packaged\"")
    widgets[:window].set_default_size(640, 480)

    widgets[:window].signal_connect(:destroy) {
      Gtk::main_quit
    }

    widgets[:box] = Gtk::VBox.new

    widgets.merge!(create_toolbar)

    widgets.merge!(create_listview_box)

    widgets[:window].add(widgets[:box])
    widgets[:box].pack_start(widgets[:toolbar], false)
    widgets[:box].pack_start(widgets[:scrolled_list], true)

    set_toolbar_state(:unmanaged)

    widgets
  end

  def set_toolbar_state(status)
    uninstall = widgets[:action_group].get_action("uninstall")
    enable = widgets[:action_group].get_action("enable")
    disable = widgets[:action_group].get_action("disable")

    case status
    when :unmanaged
      uninstall.sensitive = false
      enable.sensitive = false
      disable.sensitive = false
    when :enabled
      uninstall.sensitive = true
      enable.sensitive = false
      disable.sensitive = true
    when :disabled
      uninstall.sensitive = true
      enable.sensitive = true
      disable.sensitive = false
    end
  end

  def create_listview_box
    result = {}

    result[:list] = Gtk::TreeView.new
    result[:list].set_width_request(10)

    renderer = Gtk::CellRendererText.new

    ["状態", "作者", "名前", "説明" ].each_with_index { |col_name, i|
      col = Gtk::TreeViewColumn.new(col_name, renderer, :text => i)
      result[:list].append_column(col)
    }

    result[:store] = create_liststore
    result[:list].set_model(reload_liststore(result[:store]))

    result[:list].signal_connect(:cursor_changed) {
      if result[:list].selection.selected
        slug = result[:list].selection.selected[2]

        info = Packaged::Local::get_plugin_info_by_slug(slug)

        set_toolbar_state(info[:status])
      end
    }

    result[:scrolled_list] = Gtk::ScrolledWindow.new
    result[:scrolled_list].set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)

    result[:scrolled_list].add(result[:list])

    result
  end

  def create_liststore
    store = Gtk::ListStore.new(String, String, String, String)
    store.set_sort_column_id(2)
  end

  def reload_liststore(store)
    status_str = {
      :unmanaged => "管理外",
      :enabled => "有効",
      :disabled => "無効"
    }

    store.clear

    Packaged::Local::get_plugins.each { |plugin|
      item = store.append

      case plugin[:status]
      when :unmanaged
        store.set_values(item, [status_str[plugin[:status]], "", plugin[:dir], ""])
      else
        store.set_values(item, [status_str[plugin[:status]], plugin[:spec]["author"], plugin[:spec]["slug"], plugin[:spec]["description"]])
      end
    }

    store
  end
end

Packaged::GUI::Main::create_window
Packaged::GUI::Main::widgets[:window].show_all

Gtk::main
