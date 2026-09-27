#!/usr/bin/env python3
from collections import deque
import os
import platform
import re
import shlex
import signal
import subprocess
import threading
import time
import tkinter as tk
from pathlib import Path

BG = "#001008"
PANEL = "#002013"
PANEL_DARK = "#00170d"
BAR = "#174a28"
BORDER = "#4e9a5d"
TEXT = "#b9e8b8"
GREEN = "#5ddd72"
DIM = "#6da879"
YELLOW = "#e4db78"
RED = "#ff8b72"
SELECT = "#2c713b"
FONT = ("DejaVu Sans Mono", 11)
FONT_SMALL = ("DejaVu Sans Mono", 10)
FONT_TINY = ("DejaVu Sans Mono", 9)
FONT_BOLD = ("DejaVu Sans Mono", 11, "bold")


class BurmalGUI:

    def __init__(self, root):
        self.root = root
        self.paths = [Path.home(), Path.home()]
        self.history = []
        self.history_index = 0
        self.process = None
        self.busy = False
        self.active_pane = 0
        self.panes = []
        self.fullscreen = True
        self._layout_job = None
        self._display_size = (0, 0)

        root.title("BURMAL-DOS")
        root.configure(bg=BG)
        try:
            root.overrideredirect(True)
        except tk.TclError:
            pass
        try:
            root.attributes("-fullscreen", True)
        except tk.TclError:
            pass

        root.bind_all("<F1>", lambda _e: self.show_help())
        root.bind_all("<F2>", lambda _e: self.show_files())
        root.bind_all("<F4>", lambda _e: self.command_focus())
        root.bind_all("<F5>", lambda _e: self.refresh_files())
        root.bind_all("<F10>", lambda _e: self.exit())
        root.bind_all("<F11>", self.toggle_fullscreen)
        root.bind_all("<Escape>", self.leave_fullscreen)
        root.bind("<Configure>", self.schedule_layout)
        root.protocol("WM_DELETE_WINDOW", self.exit)

        self.build()
        self.write_output("BURMAL-DOS COMMANDER\nType HELP for commands.\n\n")
        self.refresh_system()
        self.refresh_files()
        root.after_idle(self.sync_display)
        root.after(150, self.command_focus)
        self.update_clock()

    @property
    def cwd(self):
        return self.paths[self.active_pane]

    @cwd.setter
    def cwd(self, value):
        self.paths[self.active_pane] = Path(value)

    def frame(self, parent, **kwargs):
        return tk.Frame(parent, bg=kwargs.pop("bg", PANEL), **kwargs)

    def build(self):
        for row, weight in ((0, 0), (1, 1), (2, 0), (3, 0), (4, 0), (5, 0)):
            self.root.grid_rowconfigure(row, weight=weight)
        self.root.grid_columnconfigure(0, weight=1)

        self.header = self.frame(self.root, bg=BAR, height=34)
        self.header.grid(row=0, column=0, sticky="ew")
        self.header.grid_propagate(False)
        tk.Label(self.header, text=" BURMAL-DOS", bg=BAR, fg=YELLOW,
                 font=FONT_BOLD).pack(side="left", padx=(8, 22))
        self.header_shortcuts = []
        for label in ("F1 Help", "F2 Files", "F4 Command", "F5 Refresh", "F10 Exit"):
            widget = tk.Label(self.header, text=label, bg=BAR, fg=TEXT,
                              font=FONT_SMALL)
            widget.pack(side="left", padx=7)
            self.header_shortcuts.append(widget)
        self.clock = tk.Label(self.header, text="", bg=BAR, fg=GREEN,
                              font=FONT_SMALL)
        self.clock.pack(side="right", padx=10)

        self.body = self.frame(self.root, bg=BG, padx=6, pady=5)
        self.body.grid(row=1, column=0, sticky="nsew")
        self.body.grid_rowconfigure(1, weight=1)
        self.body.grid_columnconfigure(0, weight=1)
        self.body.grid_columnconfigure(1, weight=1)
        self.drivebar = self.frame(self.body, bg=BAR, height=25)
        self.drivebar.grid(row=0, column=0, columnspan=2, sticky="ew")
        self.drivebar.grid_propagate(False)
        tk.Label(self.drivebar, text=" Drive C:", bg=BAR, fg=TEXT,
                 font=FONT_SMALL, anchor="w").pack(side="left", fill="y")
        self.manager_label = tk.Label(self.drivebar, text=" BURMAL-DOS FILE MANAGER ",
                                      bg=BAR, fg=YELLOW, font=FONT_SMALL)
        self.manager_label.pack(side="left", padx=24)

        self.panes = [self.make_pane(self.body, 0), self.make_pane(self.body, 1)]
        self.panes[0]["outer"].grid(row=1, column=0, sticky="nsew", padx=(0, 3))
        self.panes[1]["outer"].grid(row=1, column=1, sticky="nsew", padx=(3, 0))

        console = self.frame(self.root, bg=BORDER, padx=1, pady=1)
        console.grid(row=2, column=0, sticky="ew", padx=6)
        inside = self.frame(console, bg=PANEL_DARK)
        inside.pack(fill="both", expand=True)
        tk.Label(inside, text=" COMMAND.COM ", bg=BAR, fg=YELLOW,
                 font=FONT_SMALL, anchor="w").pack(fill="x")
        self.output = tk.Text(inside, height=6, bg=PANEL_DARK, fg=GREEN,
                              insertbackground=TEXT, selectbackground=SELECT,
                              font=FONT, wrap="none", relief="flat", bd=0,
                              padx=8, pady=5, state="disabled", undo=False)
        self.output.pack(fill="both", expand=True)
        self.output.tag_configure("prompt", foreground=TEXT)
        self.output.tag_configure("error", foreground=RED)
        self.output.tag_configure("dim", foreground=DIM)
        self.output.bind("<Button-1>", lambda _e: self.command_focus())

        self.commandbar = self.frame(self.root, bg=BAR, height=32)
        self.commandbar.grid(row=3, column=0, sticky="ew", padx=6, pady=(4, 0))
        self.commandbar.grid_propagate(False)
        tk.Label(self.commandbar, text="C:\\>", bg=BAR, fg=YELLOW,
                 font=FONT_BOLD).pack(side="left", padx=(8, 4))
        self.command = tk.Entry(self.commandbar, bg=BAR, fg=TEXT,
                                insertbackground=TEXT, selectbackground=SELECT,
                                font=FONT, relief="flat", bd=0,
                                highlightthickness=0)
        self.command.pack(side="left", fill="x", expand=True, padx=2)
        self.command.bind("<Return>", self.submit_command)
        self.command.bind("<Up>", self.history_up)
        self.command.bind("<Down>", self.history_down)
        self.command.bind("<Button-1>", lambda _e: self.command.focus_force())

        self.status_frame = self.frame(self.root, bg=PANEL, height=38)
        self.status_frame.grid(row=4, column=0, sticky="ew", padx=6, pady=(4, 0))
        self.status_frame.grid_propagate(False)
        self.system_text = tk.Text(self.status_frame, height=2, bg=PANEL, fg=DIM,
                                   font=FONT_SMALL, relief="flat", bd=0,
                                   padx=7, pady=2, wrap="none", state="disabled")
        self.system_text.pack(side="left", fill="both", expand=True)
        self.status = tk.Label(self.status_frame, text="READY", bg=PANEL,
                               fg=GREEN, font=FONT_SMALL)
        self.status.pack(side="right", padx=10)

        self.footer = self.frame(self.root, bg=BAR, height=28)
        self.footer.grid(row=5, column=0, sticky="ew")
        self.footer.grid_propagate(False)
        self.footer_buttons = []
        for key, label, action in (
            ("F1", "Help", self.show_help),
            ("F2", "Files", self.show_files),
            ("F4", "Command", self.command_focus),
            ("F5", "Refresh", self.refresh_files),
            ("F10", "Exit", self.exit),
        ):
            button = tk.Button(self.footer, text=f" {key} {label} ", command=action,
                               bg=PANEL, fg=TEXT, activebackground=SELECT,
                               activeforeground=YELLOW, relief="raised", bd=1,
                               font=FONT_SMALL, padx=3, pady=0,
                               highlightthickness=0)
            button.pack(side="left", padx=(5 if key == "F1" else 1, 1), pady=2)
            self.footer_buttons.append(button)

    def make_pane(self, parent, index):
        outer = self.frame(parent, bg=BORDER, padx=1, pady=1)
        inside = self.frame(outer, bg=PANEL)
        inside.pack(fill="both", expand=True)
        title = tk.Label(inside, text=" C:\\ ", bg=BAR, fg=YELLOW,
                         font=FONT_SMALL, anchor="w")
        title.pack(fill="x")
        listing = tk.Listbox(inside, bg=PANEL, fg=TEXT,
                             selectbackground=SELECT, selectforeground=YELLOW,
                             font=FONT, relief="flat", bd=0,
                             highlightthickness=1, highlightbackground=BORDER,
                             highlightcolor=YELLOW, activestyle="none",
                             exportselection=False)
        listing.pack(side="left", fill="both", expand=True, padx=3, pady=3)
        scrollbar = tk.Scrollbar(inside, command=listing.yview, bg=BAR,
                                 troughcolor=PANEL_DARK, relief="flat", bd=0)
        scrollbar.pack(side="right", fill="y")
        listing.configure(yscrollcommand=scrollbar.set)
        listing.bind("<Double-Button-1>", self.open_selected_file)
        listing.bind("<Return>", self.open_selected_file)
        listing.bind("<Tab>", self.switch_pane)
        listing.bind("<Button-1>", lambda _e, i=index: self.set_active_pane(i))
        return {"outer": outer, "title": title, "list": listing, "entries": []}

    def write_output(self, text, tag=None):
        if not text:
            return
        self.output.configure(state="normal")
        self.output.insert("end", text, tag) if tag else self.output.insert("end", text)
        try:
            lines = int(self.output.index("end-1c").split(".")[0])
            if lines > 1200:
                self.output.delete("1.0", f"{lines - 900}.0")
        except tk.TclError:
            pass
        self.output.see("end")
        self.output.configure(state="disabled")

    def submit_command(self, _event=None):
        if self.busy:
            return "break"
        text = self.command.get().strip()
        self.command.delete(0, "end")
        if not text:
            return "break"
        self.history.append(text)
        self.history_index = len(self.history)
        self.write_output(f"C:\\> {text}\n", "prompt")
        try:
            args = shlex.split(text)
        except ValueError as exc:
            self.write_output(f"Syntax error: {exc}\n", "error")
            return "break"
        cmd = args[0].lower()
        if cmd in ("exit", "quit"):
            self.exit()
        elif cmd == "help":
            self.show_help(in_terminal=True)
        elif cmd == "clear":
            self.output.configure(state="normal")
            self.output.delete("1.0", "end")
            self.output.configure(state="disabled")
        elif cmd == "pwd":
            self.write_output(f"{self.cwd}\n")
        elif cmd == "cd":
            destination = Path(args[1]).expanduser() if len(args) > 1 else Path.home()
            if not destination.is_absolute():
                destination = self.cwd / destination
            try:
                destination = destination.resolve(strict=True)
                if not destination.is_dir():
                    raise NotADirectoryError(str(destination))
                self.cwd = destination
                self.refresh_files()
            except OSError as exc:
                self.write_output(f"cd: {exc}\n", "error")
        else:
            self.run_external(text)
        return "break"

    def run_external(self, command):
        try:
            self.process = subprocess.Popen(
                command,
                shell=True,
                executable="/bin/sh",
                cwd=str(self.cwd),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                errors="replace",
                start_new_session=True,
            )
        except (OSError, ValueError) as exc:
            self.write_output(f"{exc}\n", "error")
            return
        self.busy = True
        self.command.configure(state="disabled")
        self.status.configure(text="RUNNING", fg=YELLOW)
        process = self.process

        def collect():
            output = deque(maxlen=500)
            try:
                if process.stdout is not None:
                    for line in process.stdout:
                        output.append(line[:4096])
                code = process.wait()
                result = "".join(output)
            except Exception as exc:
                result, code = f"Command failed: {exc}\n", 1
            try:
                self.root.after(0, lambda: self.finish_external(result, code))
            except tk.TclError:
                pass

        threading.Thread(target=collect, daemon=True).start()

    def finish_external(self, output, code):
        if output:
            self.write_output(output[-16000:])
            if not output.endswith("\n"):
                self.write_output("\n")
        self.write_output(f"[exit {code}]\n\n", "dim" if code == 0 else "error")
        self.busy = False
        self.process = None
        self.command.configure(state="normal")
        self.command.focus_set()
        self.status.configure(text="READY", fg=GREEN)
        self.refresh_system()
        self.refresh_files(focus=False)

    def refresh_system(self):
        try:
            os_name = "BURMAL-DOS"
            for line in Path("/etc/os-release").read_text(errors="replace").splitlines():
                if line.startswith("PRETTY_NAME="):
                    os_name = line.split("=", 1)[1].strip('"')
                    break
            memory = "unknown"
            for line in Path("/proc/meminfo").read_text(errors="replace").splitlines():
                if line.startswith("MemTotal:"):
                    memory = f"{int(line.split()[1]) // 1024} MiB"
                    break
            info = (f"OS: {os_name}    KERNEL: {platform.release()}    "
                    f"MACHINE: {platform.machine()}    MEMORY: {memory}    "
                    f"USER: {os.environ.get('USER', 'user')}")
        except (OSError, ValueError) as exc:
            info = f"SYSTEM INFORMATION UNAVAILABLE: {exc}"
        self.system_text.configure(state="normal")
        self.system_text.delete("1.0", "end")
        self.system_text.insert("end", info)
        self.system_text.configure(state="disabled")

    def refresh_files(self, focus=False):
        for index, pane in enumerate(self.panes):
            directory = self.paths[index]
            listing = pane["list"]
            listing.delete(0, "end")
            pane["entries"] = [directory.parent]
            pane["title"].configure(text=f" C:\\ {directory} ")
            try:
                entries = sorted(directory.iterdir(),
                                 key=lambda item: (not item.is_dir(), item.name.lower()))
                listing.insert("end", "[..]  <DIR>  Parent directory")
                for item in entries[:100]:
                    pane["entries"].append(item)
                    if item.is_dir():
                        line = f"      <DIR>  {item.name}"
                    else:
                        try:
                            line = f"{item.stat().st_size:>10}  {item.name}"
                        except OSError:
                            line = f"           {item.name}"
                    listing.insert("end", line)
            except OSError as exc:
                listing.insert("end", str(exc))
        self.set_active_pane(self.active_pane, focus=focus)

    def set_active_pane(self, index, focus=True):
        self.active_pane = max(0, min(index, len(self.panes) - 1))
        for i, pane in enumerate(self.panes):
            pane["list"].configure(highlightcolor=YELLOW if i == self.active_pane else BORDER)
        if focus:
            self.panes[self.active_pane]["list"].focus_set()

    def switch_pane(self, _event=None):
        self.set_active_pane(1 - self.active_pane)
        return "break"

    def open_selected_file(self, _event=None):
        listing = self.panes[self.active_pane]["list"]
        selected = listing.curselection()
        if not selected:
            return "break"
        try:
            path = self.panes[self.active_pane]["entries"][selected[0]]
        except IndexError:
            return "break"
        if path.is_dir():
            self.cwd = path.resolve()
            self.refresh_files(focus=True)
        elif path.is_file():
            self.command.delete(0, "end")
            self.command.insert(0, f"cat {shlex.quote(str(path))}")
            self.command_focus()
        return "break"

    def history_up(self, _event=None):
        if self.history:
            self.history_index = max(0, self.history_index - 1)
            self.command.delete(0, "end")
            self.command.insert(0, self.history[self.history_index])
        return "break"

    def history_down(self, _event=None):
        if self.history:
            self.history_index = min(len(self.history), self.history_index + 1)
            self.command.delete(0, "end")
            if self.history_index < len(self.history):
                self.command.insert(0, self.history[self.history_index])
        return "break"

    def show_help(self, in_terminal=False):
        help_text = ("Commands: HELP, CLEAR, PWD, CD <directory>, LS, FASTFETCH, EXIT\n"
                     "Other system commands run through BURMAL-DOS.")
        self.write_output(help_text + "\n\n", "dim")
        self.command_focus()

    def show_files(self):
        self.refresh_files(focus=True)

    def command_focus(self):
        if not self.busy:
            self.root.lift()
            self.command.focus_force()

    def schedule_layout(self, _event=None):
        if self._layout_job is None:
            self._layout_job = self.root.after_idle(self.apply_layout)

    def apply_layout(self):
        self._layout_job = None
        width = max(1, self.root.winfo_width())
        height = max(1, self.root.winfo_height())
        if getattr(self, "_last_layout_size", None) == (width, height):
            return
        self._last_layout_size = (width, height)
        compact = width < 780
        narrow = width < 620
        very_short = height < 480
        if compact:
            if self.active_pane == 1:
                self.set_active_pane(0, focus=False)
            self.panes[1]["outer"].grid_remove()
            self.body.grid_columnconfigure(1, weight=0)
            self.manager_label.pack_forget()
            for widget in self.header_shortcuts:
                widget.pack_forget()
        else:
            self.panes[1]["outer"].grid(row=1, column=1, sticky="nsew", padx=(3, 0))
            self.body.grid_columnconfigure(1, weight=1)
            if not self.manager_label.winfo_ismapped():
                self.manager_label.pack(side="left", padx=24)
            for widget in self.header_shortcuts:
                if not widget.winfo_ismapped():
                    widget.pack(side="left", padx=7)
        for button in self.footer_buttons:
            button.pack_forget()
        visible = self.footer_buttons[:3] if narrow else self.footer_buttons
        for n, button in enumerate(visible):
            button.pack(side="left", padx=(5 if n == 0 else 1, 1), pady=2)

        if very_short:
            self.status_frame.grid_remove()
        else:
            self.status_frame.grid(row=4, column=0, sticky="ew", padx=6, pady=(4, 0))

        if narrow:
            self.clock.pack_forget()
        elif not self.clock.winfo_ismapped():
            self.clock.pack(side="right", padx=10)

        self.output.configure(height=max(3, min(8, (height - 330) // 45)))
        font = FONT_TINY if narrow else FONT
        for pane in self.panes:
            pane["list"].configure(font=font)
        self.output.configure(font=font)
        self.command.configure(font=font)
        self.system_text.configure(font=FONT_TINY if narrow else FONT_SMALL)

    def screen_size(self):
        try:
            result = subprocess.run(
                ["xrandr", "--current"], capture_output=True, text=True,
                errors="replace", timeout=1, check=False,
            )
            match = re.search(r"current\s+(\d+)\s+x\s+(\d+)", result.stdout)
            if match:
                return int(match.group(1)), int(match.group(2))
        except (OSError, subprocess.SubprocessError, ValueError):
            pass
        return max(1, self.root.winfo_screenwidth()), max(1, self.root.winfo_screenheight())

    def sync_display(self):
        if self.root.winfo_exists():
            width, height = self.screen_size()
            if self.fullscreen and (width, height) != self._display_size:
                self._display_size = (width, height)
                self.root.geometry(f"{width}x{height}+0+0")
                self.root.lift()
            self.root.after(1000, self.sync_display)

    def toggle_fullscreen(self, _event=None):
        if self.fullscreen:
            self.fullscreen = False
            try:
                self.root.attributes("-fullscreen", False)
                self.root.overrideredirect(False)
            except tk.TclError:
                pass
            width, height = self.screen_size()
            width, height = max(1, int(width * .88)), max(1, int(height * .88))
            self.root.geometry(f"{width}x{height}+20+20")
        else:
            self.enter_fullscreen()
        return "break"

    def enter_fullscreen(self):
        self.fullscreen = True
        try:
            self.root.overrideredirect(True)
            self.root.attributes("-fullscreen", True)
        except tk.TclError:
            pass
        self._display_size = (0, 0)
        width, height = self.screen_size()
        self.root.geometry(f"{width}x{height}+0+0")
        self._display_size = (width, height)

    def leave_fullscreen(self, _event=None):
        if self.fullscreen:
            self.toggle_fullscreen()
            return "break"

    def update_clock(self):
        if self.root.winfo_exists():
            self.clock.configure(text=time.strftime("%H:%M"))
            self.root.after(30000, self.update_clock)

    def exit(self):
        if self.busy and self.process:
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except (OSError, ProcessLookupError):
                pass
        self.root.destroy()


if __name__ == "__main__":
    app = tk.Tk()
    BurmalGUI(app)
    app.mainloop()
