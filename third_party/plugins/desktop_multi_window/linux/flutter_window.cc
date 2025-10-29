//
// Created by yangbin on 2022/1/11.
//

#include "flutter_window.h"

#include <iostream>
#include <cairo.h>

#include "include/desktop_multi_window/desktop_multi_window_plugin.h"
#include "desktop_multi_window_plugin_internal.h"

namespace {

WindowCreatedCallback _g_window_created_callback = nullptr;

}

gboolean on_close_clicked(GtkWidget *widget, GdkEvent *event, gpointer user_data) {
    gtk_widget_destroy(widget);
    return TRUE;
}

FlutterWindow::FlutterWindow(
    int64_t id,
    const std::string &args,
    const std::shared_ptr<FlutterWindowCallback> &callback
) : callback_(callback), id_(id) {
  window_ = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_default_size(GTK_WINDOW(window_), 1280, 720);
  gtk_window_set_title(GTK_WINDOW(window_), "");
  gtk_window_set_position(GTK_WINDOW(window_), GTK_WIN_POS_CENTER);
  gtk_window_set_decorated(GTK_WINDOW(window_), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(window_), FALSE);
  gtk_window_set_keep_above(GTK_WINDOW(window_), TRUE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(window_), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(window_), TRUE);
  gtk_widget_set_app_paintable(window_, TRUE);

  if (auto *screen = gtk_widget_get_screen(window_)) {
    if (auto *visual = gdk_screen_get_rgba_visual(screen)) {
      gtk_widget_set_visual(window_, visual);
    }
  }

  g_signal_connect(window_, "draw", G_CALLBACK(+[](GtkWidget *, cairo_t *cr, gpointer) {
    cairo_save(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0);
    cairo_paint(cr);
    cairo_restore(cr);
    return FALSE;
  }), nullptr);

  g_signal_connect(window_, "realize", G_CALLBACK(+[](GtkWidget *widget, gpointer) {
    if (auto *gdk_window = gtk_widget_get_window(widget)) {
      GdkRGBA transparent = {0.0, 0.0, 0.0, 0.0};
      gdk_window_set_background_rgba(gdk_window, &transparent);
    }
  }), nullptr);

  gtk_widget_show(GTK_WIDGET(window_));

  g_signal_connect(G_OBJECT(window_), "delete-event", G_CALLBACK(on_close_clicked), NULL);
  g_signal_connect(window_, "destroy", G_CALLBACK(+[](GtkWidget *, gpointer arg) {
    auto *self = static_cast<FlutterWindow *>(arg);
    if (auto callback = self->callback_.lock()) {
      callback->OnWindowClose(self->id_);
      callback->OnWindowDestroy(self->id_);
    }
  }), this);

  g_autoptr(FlDartProject)
      project = fl_dart_project_new();
  const char *entrypoint_args[] = {"multi_window", g_strdup_printf("%ld", id_), args.c_str(), nullptr};
  fl_dart_project_set_dart_entrypoint_arguments(project, const_cast<char **>(entrypoint_args));

  auto fl_view = fl_view_new(project);
  gtk_widget_set_app_paintable(GTK_WIDGET(fl_view), TRUE);
  g_signal_connect(fl_view, "realize", G_CALLBACK(+[](GtkWidget *widget, gpointer) {
    if (auto *gdk_window = gtk_widget_get_window(widget)) {
      GdkRGBA transparent = {0.0, 0.0, 0.0, 0.0};
      gdk_window_set_background_rgba(gdk_window, &transparent);
    }
  }), nullptr);
  gtk_container_add(GTK_CONTAINER(window_), GTK_WIDGET(fl_view));
  gtk_widget_show(GTK_WIDGET(fl_view));

  if (_g_window_created_callback) {
    _g_window_created_callback(FL_PLUGIN_REGISTRY(fl_view));
  }
  g_autoptr(FlPluginRegistrar)
      desktop_multi_window_registrar =
      fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(fl_view), "DesktopMultiWindowPlugin");
  desktop_multi_window_plugin_register_with_registrar_internal(desktop_multi_window_registrar);

  window_channel_ = WindowChannel::RegisterWithRegistrar(desktop_multi_window_registrar, id_);

  gtk_widget_grab_focus(GTK_WIDGET(fl_view));
  gtk_widget_hide(GTK_WIDGET(window_));
}

WindowChannel *FlutterWindow::GetWindowChannel() {
  return window_channel_.get();
}

FlutterWindow::~FlutterWindow() = default;

void desktop_multi_window_plugin_set_window_created_callback(WindowCreatedCallback callback) {
  _g_window_created_callback = callback;
}
