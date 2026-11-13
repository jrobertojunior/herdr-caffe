#!/bin/sh
# caffe.sh start|stop|check <pidfile>
# Herdr runs this script, so $PPID is Herdr: the keep-awake process ends with it.
f=$2

alive() {
  p=$(cat "$f" 2>/dev/null) && [ -n "$p" ] &&
    ps -p "$p" -o comm= 2>/dev/null | grep -Eq 'caffeinate|inhibit|gnome-session'
}

case $1 in
check)
  alive
  ;;
start)
  alive && exit 0
  mkdir -p "$(dirname "$f")"
  app=$PPID
  wait_app="while kill -0 $app 2>/dev/null; do sleep 5; done"
  case $(uname -s) in
  Darwin)
    caffeinate -d -i -w "$app" </dev/null >/dev/null 2>&1 &
    ;;
  Linux)
    # GNOME blanks the screen on its own idle timer and ignores logind's idle
    # lock, so ask its session manager. Everywhere else, ask logind.
    case ${XDG_CURRENT_DESKTOP:-} in *GNOME*) gnome=1 ;; esac
    if [ -n "${gnome:-}" ] && command -v gnome-session-inhibit >/dev/null 2>&1; then
      gnome-session-inhibit --app-id herdr --reason "Herdr Caffe" \
        --inhibit idle:suspend sh -c "$wait_app" </dev/null >/dev/null 2>&1 &
    elif command -v systemd-inhibit >/dev/null 2>&1; then
      systemd-inhibit --what=idle:sleep --who="Herdr Caffe" \
        --why="Keep this computer awake" --mode=block \
        sh -c "$wait_app" </dev/null >/dev/null 2>&1 &
    else
      echo "Caffe needs systemd-inhibit or gnome-session-inhibit." >&2
      exit 1
    fi
    ;;
  *)
    echo "Caffe works on macOS and Linux only." >&2
    exit 1
    ;;
  esac
  echo $! > "$f"
  # A tool that cannot take the lock exits at once.
  sleep 0.5
  alive || { rm -f "$f"; echo "Caffe could not keep this computer awake." >&2; exit 1; }
  ;;
stop)
  if alive; then
    p=$(cat "$f")
    pkill -P "$p" 2>/dev/null
    kill "$p"
  fi
  rm -f "$f"
  ;;
*)
  echo "usage: caffe.sh start|stop|check <pidfile>" >&2
  exit 2
  ;;
esac
