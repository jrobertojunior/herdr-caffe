// A tab-bar button that keeps the computer awake: `caffeinate -d -i` on
// macOS, systemd-inhibit (or gnome-session-inhibit on GNOME) on Linux.
// caffe.sh does the work and keeps the pid in data/caffe/pid, so every copy
// (and the next start) sees the same state. The lock ends when Herdr quits.
import { View, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { exec, appHome, theme, shared, setShared, notify } from "herdr";

const KEY = "caffe.on";

const caffe = (action) =>
  exec("sh", [`${appHome()}/mods/caffe/caffe.sh`, action, `${appHome()}/data/caffe/pid`]);

async function running() {
  return (await caffe("check")).code === 0;
}

export default class Caffe extends View {
  init(_props, cx) {
    this.busy = false;
    cx.spawn(async (cx) => {
      setShared(KEY, await running());
      cx.notify();
    });
  }

  toggle(cx) {
    if (this.busy) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        // Ask the system, not the button: the lock may have ended.
        const r = await caffe((await running()) ? "stop" : "start");
        if (r.code !== 0) notify({ title: "Caffe", body: r.stderr.trim(), level: "error" });
        setShared(KEY, await running());
      } catch (error) {
        notify({ title: "Caffe", body: String(error), level: "error" });
      } finally {
        this.busy = false;
        cx.notify();
      }
    });
  }

  render() {
    const t = theme();
    const on = shared(KEY) === true;
    return h_flex().size_full().pr(4).items_center()
      .bg(t.chrome).border_b(1).border_color(t.border)
      .child(h_flex().id("caffe-toggle").h(26).px(8).gap(5).flex_none()
        .items_center().rounded(6).text_size(12)
        .bg(on ? t.selected : t.chrome)
        .text_color(on ? t.accent : t.muted)
        .hover((style) => style.bg(t.hover).text_color(on ? t.accent : t.foreground))
        .tooltip(on ? "This computer stays awake. Click to stop." : "Keep this computer awake")
        .on_mouse_down("left", (_event, cx) => cx.stop_propagation())
        .on_click((_event, cx) => this.toggle(cx))
        .child(svg("mods/caffe/coffee.svg").size(14))
        .child("Caffe"));
  }
}
