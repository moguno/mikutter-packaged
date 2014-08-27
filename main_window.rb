#coding: UTF-8

require 'rubygems'
require 'gtk2'

require File.join(File.dirname(__FILE__), "core.rb")
require File.join(File.dirname(__FILE__), "install_dialog.rb")

# メインウインドウ
module Packaged::GUI::Main
  extend self

  @widgets = {}

  # カラム定義
  @columns = Packaged::Common::ColumnHelper.new

  @columns.add(:status, {:name => "状態", :visible => true, :type => String})
  @columns.add(:author, {:name => "作者", :visible => true, :type => String})
  @columns.add(:name, {:name => "名前", :visible => true, :type => String})
  @columns.add(:description, {:name => "説明", :visible => true, :type => String})
  @columns.add(:fore_color, {:name => "文字色", :visible => false, :type => String})
  @columns.add(:info, {:name => "情報オブジェクト", :visible => false, :type => Hash})

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
    slug = widgets[:list].selection.selected[@columns[:info].index][:spec]["slug"]

    Packaged::Local::enable_plugin(slug)

    reload_liststore(widgets[:store])
  end

  # 無効化ボタン押下
  def menu_disable(actiongroup, action)
    slug = widgets[:list].selection.selected[@columns[:info].index][:spec]["slug"]

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

  # ウインドウを構築
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

  # ツールバーボタンの状態を変更する
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

    result[:list].signal_connect(:cursor_changed) {
      if result[:list].selection.selected
        info = widgets[:list].selection.selected[@columns[:info].index]

        set_toolbar_state(info[:status])
      end
    }

    result[:scrolled_list] = Gtk::ScrolledWindow.new
    result[:scrolled_list].set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)

    result[:scrolled_list].add(result[:list])

    result
  end

  def create_liststore
    store = Gtk::ListStore.new(*@columns.map { |_| _.type })
    store.set_sort_column_id(@columns[:name].index)
  end

  def reload_liststore(store)
    status_str = {
      :unmanaged => { :str => "管理外", :color => "grey" },
      :enabled => { :str => "有効", :color => "black" },
      :disabled => { :str => "無効", :color => "red" },
    }

    store.clear

    Packaged::Local::get_plugins.each { |plugin|
      item = store.append

      values = case plugin[:status]
      when :unmanaged
        {
          :status => status_str[plugin[:status]][:str],
          :name => plugin[:dir],
          :info => plugin,
          :fore_color => status_str[plugin[:status]][:color]
        }
      else
        {
          :status => status_str[plugin[:status]][:str],
          :author => plugin[:spec]["author"],
          :name => plugin[:spec]["slug"],
          :description => plugin[:spec]["description"],
          :info => plugin,
          :fore_color => status_str[plugin[:status]][:color]
        }
      end

      store.set_values(item, @columns.make_values(values))
    }

    store
  end
end
