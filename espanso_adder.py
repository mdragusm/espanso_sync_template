#!/usr/bin/env python3
import tkinter as tk
from tkinter import messagebox, ttk
import subprocess
import os
import threading
import re
import platform

IS_WINDOWS = platform.system() == "Windows"

if IS_WINDOWS:
    MATCH_DIR = os.path.expandvars(r"%APPDATA%\espanso\match")
else:
    MATCH_DIR = os.path.expanduser("~/.config/espanso/match")

DOTFILES_DIR = os.path.expanduser("~/dotfiles")

SPECIAL_CHARS = ('@', ':', '#', '&', '*', '?', '|', '<', '>', '=', '!', '%', ',', '[', ']', '{', '}')

def needs_quotes(s):
    return s.startswith(SPECIAL_CHARS)

def get_group_files():
    files = {}
    for f in os.listdir(DOTFILES_DIR):
        if f.endswith(".yml") and f != "base.yml":
            name = f[:-4]
            files[name] = os.path.join(DOTFILES_DIR, f)
    files["base"] = os.path.join(DOTFILES_DIR, "base.yml")
    return files

def load_snippets_from_file(path):
    snippets = []
    try:
        real = os.path.realpath(path)
        with open(real, "r", encoding="utf-8") as f:
            content = f.read()
        blocks = re.findall(r'-\s+trigger:\s*["\']?(.+?)["\']?\n\s+replace:\s*["\']?(.+?)["\']?\s*\n', content)
        for trigger, replace in blocks:
            snippets.append((trigger.strip().strip('"\''), replace.strip().strip('"\'') ))
    except:
        pass
    return snippets

def load_all_snippets():
    all_snippets = []
    for group, path in get_group_files().items():
        for t, r in load_snippets_from_file(path):
            all_snippets.append((group, t, r))
    return all_snippets

def save_snippets_to_file(path, snippets):
    real = os.path.realpath(path)
    lines = ["matches:\n"]
    for trigger, replace in snippets:
        t = f'"{trigger}"' if needs_quotes(trigger) else trigger
        r = f'"{replace}"' if needs_quotes(replace) else replace
        lines.append(f"- trigger: {t}\n  replace: {r}\n")
    with open(real, "w", encoding="utf-8") as f:
        f.writelines(lines)

def save_all_snippets(all_snippets):
    groups = {}
    for group, t, r in all_snippets:
        groups.setdefault(group, []).append((t, r))
    group_files = get_group_files()
    for group, snippets in groups.items():
        if group not in group_files:
            path = os.path.join(DOTFILES_DIR, f"{group}.yml")
            group_files[group] = path
            # Also symlink to espanso match dir
            link = os.path.join(MATCH_DIR, f"{group}.yml")
            if not os.path.exists(link):
                if IS_WINDOWS:
                    subprocess.run(f'cmd /c mklink "{link}" "{path}"', shell=True)
                else:
                    os.symlink(path, link)
        save_snippets_to_file(group_files[group], snippets)
    # Clear groups that are now empty
    for group, path in group_files.items():
        if group not in groups:
            save_snippets_to_file(path, [])

def create_group_file(name):
    path = os.path.join(DOTFILES_DIR, f"{name}.yml")
    if os.path.exists(path):
        return False, "Group already exists."
    with open(path, "w", encoding="utf-8") as f:
        f.write("matches:\n")
    link = os.path.join(MATCH_DIR, f"{name}.yml")
    if not os.path.exists(link):
        if IS_WINDOWS:
            subprocess.run(f'cmd /c mklink "{link}" "{path}"', shell=True)
        else:
            os.symlink(path, link)
    return True, ""

def delete_group_file(name):
    if name == "base":
        return False, "Cannot delete the base group."
    path = os.path.join(DOTFILES_DIR, f"{name}.yml")
    link = os.path.join(MATCH_DIR, f"{name}.yml")
    if os.path.exists(path):
        os.remove(path)
    if os.path.exists(link):
        os.remove(link)
    return True, ""

# ── Git ──────────────────────────────────────────────────────────────────────

def show_toast(message, color="#4caf50"):
    toast = tk.Toplevel(root)
    toast.overrideredirect(True)
    toast.configure(bg="#313244")
    root.update_idletasks()
    x = root.winfo_x() + root.winfo_width() // 2 - 120
    y = root.winfo_y() + root.winfo_height() // 2 - 30
    toast.geometry(f"240x60+{x}+{y}")
    tk.Label(toast, text=message, font=("Courier New", 11, "bold"),
             bg="#313244", fg=color, pady=18).pack(expand=True)
    toast.after(1500, toast.destroy)

def git_sync(on_done, status_lbl, btn_ref):
    status_lbl.config(text="Pushing to GitHub...", fg="#f0a500")
    dotfiles = os.path.expanduser("~/dotfiles")
    if IS_WINDOWS:
        cmd = f'cd /d "{dotfiles}" && git pull && git add *.yml && git commit -m "update snippets" && git push'
        restart_cmd = "espanso restart"
    else:
        cmd = f"cd '{dotfiles}' && git pull && git add *.yml && git commit -m 'update snippets' && git push"
        restart_cmd = "sleep 1 && espanso restart"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode == 0:
        subprocess.Popen(restart_cmd, shell=True, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        root.after(0, lambda: on_done(True, btn_ref, status_lbl))
    else:
        root.after(0, lambda: on_done(False, btn_ref, status_lbl))

def on_sync_done(success, btn_ref, status_lbl):
    btn_ref.config(state="normal")
    if success:
        status_lbl.config(text="✓ Synced!", fg="#4caf50")
        show_toast("✓ saved!")
    else:
        status_lbl.config(text="✗ Sync failed.", fg="#f44336")
        messagebox.showerror("Git error", "Could not push to GitHub.\nCheck your connection.")

# ── Theme ────────────────────────────────────────────────────────────────────

BG      = "#1e1e2e"
BG2     = "#313244"
FG      = "#cdd6f4"
ACCENT  = "#89b4fa"
GREEN   = "#4caf50"
RED     = "#f44336"
AMBER   = "#f0a500"
FONT    = ("Courier New", 11)
FONT_B  = ("Courier New", 11, "bold")
FONT_SM = ("Courier New", 9)
FONT_LG = ("Courier New", 15, "bold")

# ── Root ─────────────────────────────────────────────────────────────────────

root = tk.Tk()
root.title("Espanso Manager")
root.geometry("520x540")
root.resizable(True, True)
root.configure(bg=BG)

# ── Tab bar ──────────────────────────────────────────────────────────────────

tab_bar = tk.Frame(root, bg=BG)
tab_bar.pack(fill="x")

content = tk.Frame(root, bg=BG)
content.pack(fill="both", expand=True)
content.rowconfigure(0, weight=1)
content.columnconfigure(0, weight=1)

frames = {}
tab_btns = {}

def show_tab(name):
    for n, f in frames.items():
        f.pack_forget()
    frames[name].pack(fill="both", expand=True, padx=20, pady=12)
    for n, b in tab_btns.items():
        b.config(bg=ACCENT if n == name else BG2, fg=BG if n == name else FG)
    if name == "manage":
        refresh_list()
    if name == "groups":
        refresh_groups()

for tab in ["add", "manage", "groups"]:
    frames[tab] = tk.Frame(content, bg=BG)

for label, key in [("＋ Add", "add"), ("✎ Manage", "manage"), ("⬡ Groups", "groups")]:
    b = tk.Button(tab_bar, text=label, font=FONT_B, bg=BG2, fg=FG,
                  relief="flat", bd=0, padx=14, pady=8,
                  activebackground=ACCENT, activeforeground=BG,
                  cursor="hand2", command=lambda k=key: show_tab(k))
    b.pack(side="left")
    tab_btns[key] = b

# ══ ADD TAB ══════════════════════════════════════════════════════════════════

add_frame = frames["add"]
tk.Label(add_frame, text="ESPANSO MANAGER", font=FONT_LG, bg=BG, fg=ACCENT).pack(pady=(4, 2))
tk.Label(add_frame, text="add a snippet and push to github", font=FONT_SM, bg=BG, fg="#6c7086").pack(pady=(0, 10))

tk.Label(add_frame, text="group", font=FONT_B, bg=BG, fg=FG, anchor="w").pack(fill="x")
add_group_var = tk.StringVar(value="base")
add_group_menu = tk.OptionMenu(add_frame, add_group_var, "base")
add_group_menu.config(font=FONT, bg=BG2, fg=FG, activebackground=ACCENT,
                      activeforeground=BG, relief="flat", bd=0, highlightthickness=0)
add_group_menu["menu"].config(font=FONT, bg=BG2, fg=FG)
add_group_menu.pack(fill="x", pady=(2, 10))

tk.Label(add_frame, text="trigger", font=FONT_B, bg=BG, fg=FG, anchor="w").pack(fill="x")
trigger_entry = tk.Entry(add_frame, font=FONT, bg=BG2, fg=FG, insertbackground=FG, relief="flat", bd=6)
trigger_entry.pack(fill="x", pady=(2, 10))

tk.Label(add_frame, text="replacement", font=FONT_B, bg=BG, fg=FG, anchor="w").pack(fill="x")
replace_text = tk.Text(add_frame, font=FONT, bg=BG2, fg=FG, insertbackground=FG, relief="flat", bd=6, height=4)
replace_text.pack(fill="x", pady=(2, 10))

add_status = tk.Label(add_frame, text="", font=FONT_SM, bg=BG, fg=GREEN)
add_status.pack()

add_btn = tk.Button(add_frame, text="ADD + SYNC →", font=FONT_B,
                    bg=ACCENT, fg=BG, relief="flat", bd=0, padx=12, pady=6,
                    activebackground="#74c7ec", activeforeground=BG, cursor="hand2")
add_btn.pack(pady=(4, 0))

def update_group_dropdown(menu_widget, var, groups):
    menu = menu_widget["menu"]
    menu.delete(0, "end")
    for g in groups:
        menu.add_command(label=g, command=lambda v=g: var.set(v))
    if var.get() not in groups:
        var.set(groups[0] if groups else "base")

def refresh_group_dropdowns():
    groups = list(get_group_files().keys())
    update_group_dropdown(add_group_menu, add_group_var, groups)
    update_group_dropdown(move_group_menu, move_group_var, groups)

def do_add():
    trigger = trigger_entry.get().strip()
    replace = replace_text.get("1.0", tk.END).strip()
    group = add_group_var.get()
    if not trigger or not replace:
        messagebox.showwarning("Missing fields", "Please fill in both fields.")
        return
    all_snippets = load_all_snippets()
    all_snippets.append((group, trigger, replace))
    save_all_snippets(all_snippets)
    add_btn.config(state="disabled", text="Syncing...")
    add_status.config(text="Pushing to GitHub...", fg=AMBER)
    threading.Thread(target=git_sync, args=(on_sync_done, add_status, add_btn), daemon=True).start()
    trigger_entry.delete(0, tk.END)
    replace_text.delete("1.0", tk.END)

add_btn.config(command=do_add)

# ══ MANAGE TAB ═══════════════════════════════════════════════════════════════

mgmt_frame = frames["manage"]
tk.Label(mgmt_frame, text="MANAGE SNIPPETS", font=FONT_LG, bg=BG, fg=ACCENT).pack(pady=(0, 6))

# Filter bar
filter_bar = tk.Frame(mgmt_frame, bg=BG)
filter_bar.pack(fill="x", pady=(0, 4))
tk.Label(filter_bar, text="group:", font=FONT_SM, bg=BG, fg=FG).pack(side="left")
filter_var = tk.StringVar(value="all")
filter_menu = tk.OptionMenu(filter_bar, filter_var, "all")
filter_menu.config(font=FONT_SM, bg=BG2, fg=FG, activebackground=ACCENT,
                   activeforeground=BG, relief="flat", bd=0, highlightthickness=0)
filter_menu["menu"].config(font=FONT_SM, bg=BG2, fg=FG)
filter_menu.pack(side="left", padx=(4, 12))
tk.Label(filter_bar, text="sort:", font=FONT_SM, bg=BG, fg=FG).pack(side="left")
sort_var = tk.StringVar(value="none")
sort_menu = tk.OptionMenu(filter_bar, sort_var, "none", "trigger A-Z", "trigger Z-A", "group A-Z", "replacement A-Z")
sort_menu.config(font=FONT_SM, bg=BG2, fg=FG, activebackground=ACCENT,
                 activeforeground=BG, relief="flat", bd=0, highlightthickness=0)
sort_menu["menu"].config(font=FONT_SM, bg=BG2, fg=FG)
sort_menu.pack(side="left", padx=(4, 0))
filter_var.trace("w", lambda *a: refresh_list())
sort_var.trace("w", lambda *a: refresh_list())

# Search bar
search_bar = tk.Frame(mgmt_frame, bg=BG)
search_bar.pack(fill="x", pady=(0, 6))
tk.Label(search_bar, text="search:", font=FONT_SM, bg=BG, fg=FG).pack(side="left")
search_var = tk.StringVar()
search_entry = tk.Entry(search_bar, textvariable=search_var, font=FONT_SM, bg=BG2, fg=FG,
                        insertbackground=FG, relief="flat", bd=4)
search_entry.pack(side="left", fill="x", expand=True, padx=(4, 0))
search_var.trace("w", lambda *a: refresh_list())

list_frame = tk.Frame(mgmt_frame, bg=BG)
list_frame.pack(fill="both", expand=True)
scrollbar = tk.Scrollbar(list_frame, bg=BG2, troughcolor=BG)
scrollbar.pack(side="right", fill="y")
snippet_list = tk.Listbox(list_frame, font=FONT, bg=BG2, fg=FG,
                           selectbackground=ACCENT, selectforeground=BG,
                           relief="flat", bd=0, activestyle="none",
                           selectmode=tk.EXTENDED,
                           yscrollcommand=scrollbar.set, height=8)
snippet_list.pack(fill="both", expand=True)
scrollbar.config(command=snippet_list.yview)

edit_frame = tk.Frame(mgmt_frame, bg=BG)
edit_frame.pack(fill="x", pady=(8, 0))
tk.Label(edit_frame, text="trigger", font=FONT_B, bg=BG, fg=FG, anchor="w").grid(row=0, column=0, sticky="w")
edit_trigger = tk.Entry(edit_frame, font=FONT, bg=BG2, fg=FG, insertbackground=FG, relief="flat", bd=4, width=16)
edit_trigger.grid(row=1, column=0, padx=(0, 8), sticky="ew")
tk.Label(edit_frame, text="replacement", font=FONT_B, bg=BG, fg=FG, anchor="w").grid(row=0, column=1, sticky="w")
edit_replace = tk.Entry(edit_frame, font=FONT, bg=BG2, fg=FG, insertbackground=FG, relief="flat", bd=4)
edit_replace.grid(row=1, column=1, sticky="ew")
edit_frame.columnconfigure(1, weight=1)

move_frame = tk.Frame(mgmt_frame, bg=BG)
move_frame.pack(fill="x", pady=(6, 0))
tk.Label(move_frame, text="move to group:", font=FONT_SM, bg=BG, fg=FG).pack(side="left")
move_group_var = tk.StringVar(value="base")
move_group_menu = tk.OptionMenu(move_frame, move_group_var, "base")
move_group_menu.config(font=FONT_SM, bg=BG2, fg=FG, activebackground=ACCENT,
                       activeforeground=BG, relief="flat", bd=0, highlightthickness=0)
move_group_menu["menu"].config(font=FONT_SM, bg=BG2, fg=FG)
move_group_menu.pack(side="left", padx=(6, 0))

btn_row = tk.Frame(mgmt_frame, bg=BG)
btn_row.pack(fill="x", pady=(8, 0))
mgmt_status = tk.Label(mgmt_frame, text="", font=FONT_SM, bg=BG, fg=GREEN)
mgmt_status.pack()

all_snippets_cache = []
filtered_indices = []

def refresh_list():
    global all_snippets_cache, filtered_indices
    all_snippets_cache = load_all_snippets()
    selected_group = filter_var.get()
    search = search_var.get().strip().lower()
    sort = sort_var.get()

    # Update filter dropdown
    groups = ["all"] + list(get_group_files().keys())
    update_group_dropdown(filter_menu, filter_var, groups)
    if selected_group not in groups:
        filter_var.set("all")

    filtered = [(i, g, t, r) for i, (g, t, r) in enumerate(all_snippets_cache)
                if (selected_group == "all" or g == selected_group)
                and (not search or search in t.lower() or search in r.lower() or search in g.lower())]

    # Sort
    if sort == "trigger A-Z":
        filtered.sort(key=lambda x: x[2].lower())
    elif sort == "trigger Z-A":
        filtered.sort(key=lambda x: x[2].lower(), reverse=True)
    elif sort == "group A-Z":
        filtered.sort(key=lambda x: x[1].lower())
    elif sort == "replacement A-Z":
        filtered.sort(key=lambda x: x[3].lower())

    filtered_indices = [i for i, g, t, r in filtered]

    snippet_list.delete(0, tk.END)
    if not filtered:
        return
    max_t = max(len(t) for i, g, t, r in filtered)
    max_g = max(len(g) for i, g, t, r in filtered)
    for i, g, t, r in filtered:
        snippet_list.insert(tk.END, f"  {g.ljust(max_g)}  {t.ljust(max_t)}  →  {r}")

def on_select(event):
    sel = snippet_list.curselection()
    if not sel:
        return
    if len(sel) == 1:
        idx = filtered_indices[sel[0]]
        g, t, r = all_snippets_cache[idx]
        edit_trigger.delete(0, tk.END)
        edit_trigger.insert(0, t)
        edit_replace.delete(0, tk.END)
        edit_replace.insert(0, r)
        move_group_var.set(g)
    else:
        edit_trigger.delete(0, tk.END)
        edit_trigger.insert(0, f"({len(sel)} selected)")
        edit_replace.delete(0, tk.END)

snippet_list.bind("<<ListboxSelect>>", on_select)

def do_save_edit():
    sel = snippet_list.curselection()
    if not sel:
        messagebox.showwarning("No selection", "Select a snippet to edit.")
        return
    g = move_group_var.get()
    if len(sel) > 1:
        # Multi-select: move all to selected group
        if not messagebox.askyesno("Move snippets?", f"Move {len(sel)} snippets to group '{g}'?"):
            return
        for s in sel:
            idx = filtered_indices[s]
            old_g, t, r = all_snippets_cache[idx]
            all_snippets_cache[idx] = (g, t, r)
    else:
        idx = filtered_indices[sel[0]]
        t = edit_trigger.get().strip()
        r = edit_replace.get().strip()
        if not t or not r:
            messagebox.showwarning("Missing fields", "Fill in both fields.")
            return
        all_snippets_cache[idx] = (g, t, r)
    save_all_snippets(all_snippets_cache)
    refresh_list()
    save_btn.config(state="disabled")
    threading.Thread(target=git_sync, args=(on_sync_done, mgmt_status, save_btn), daemon=True).start()

def do_delete():
    sel = snippet_list.curselection()
    if not sel:
        messagebox.showwarning("No selection", "Select a snippet to delete.")
        return
    if len(sel) > 1:
        if not messagebox.askyesno("Delete?", f"Delete {len(sel)} snippets?"):
            return
        for idx in sorted([filtered_indices[s] for s in sel], reverse=True):
            del all_snippets_cache[idx]
    else:
        idx = filtered_indices[sel[0]]
        g, t, r = all_snippets_cache[idx]
        if not messagebox.askyesno("Delete?", f"Delete snippet '{t}'?"):
            return
        del all_snippets_cache[idx]
    save_all_snippets(all_snippets_cache)
    refresh_list()
    edit_trigger.delete(0, tk.END)
    edit_replace.delete(0, tk.END)
    delete_btn.config(state="disabled")
    threading.Thread(target=git_sync, args=(on_sync_done, mgmt_status, delete_btn), daemon=True).start()

save_btn = tk.Button(btn_row, text="SAVE EDIT →", font=FONT_B,
                     bg=ACCENT, fg=BG, relief="flat", bd=0, padx=10, pady=5,
                     cursor="hand2", command=do_save_edit)
save_btn.pack(side="left", padx=(0, 8))

delete_btn = tk.Button(btn_row, text="DELETE ✕", font=FONT_B,
                       bg=RED, fg=FG, relief="flat", bd=0, padx=10, pady=5,
                       cursor="hand2", command=do_delete)
delete_btn.pack(side="left")

# ══ GROUPS TAB ═══════════════════════════════════════════════════════════════

groups_frame = frames["groups"]
tk.Label(groups_frame, text="MANAGE GROUPS", font=FONT_LG, bg=BG, fg=ACCENT).pack(pady=(0, 10))

groups_list_frame = tk.Frame(groups_frame, bg=BG)
groups_list_frame.pack(fill="both", expand=True)
g_scrollbar = tk.Scrollbar(groups_list_frame, bg=BG2, troughcolor=BG)
g_scrollbar.pack(side="right", fill="y")
groups_listbox = tk.Listbox(groups_list_frame, font=FONT, bg=BG2, fg=FG,
                             selectbackground=ACCENT, selectforeground=BG,
                             relief="flat", bd=0, activestyle="none",
                             yscrollcommand=g_scrollbar.set, height=8)
groups_listbox.pack(fill="both", expand=True)
g_scrollbar.config(command=groups_listbox.yview)

new_group_frame = tk.Frame(groups_frame, bg=BG)
new_group_frame.pack(fill="x", pady=(10, 0))
tk.Label(new_group_frame, text="new group name", font=FONT_B, bg=BG, fg=FG, anchor="w").pack(fill="x")
new_group_entry = tk.Entry(new_group_frame, font=FONT, bg=BG2, fg=FG,
                            insertbackground=FG, relief="flat", bd=6)
new_group_entry.pack(fill="x", pady=(2, 8))

g_status = tk.Label(groups_frame, text="", font=FONT_SM, bg=BG, fg=GREEN)
g_status.pack()

g_btn_row = tk.Frame(groups_frame, bg=BG)
g_btn_row.pack(fill="x", pady=(4, 0))

def refresh_groups():
    groups_listbox.delete(0, tk.END)
    for name, path in get_group_files().items():
        count = len(load_snippets_from_file(path))
        groups_listbox.insert(tk.END, f"  {name.ljust(20)}  {count} snippets")
    refresh_group_dropdowns()

def do_create_group():
    name = new_group_entry.get().strip().lower().replace(" ", "_")
    if not name:
        messagebox.showwarning("Missing name", "Enter a group name.")
        return
    ok, err = create_group_file(name)
    if not ok:
        messagebox.showerror("Error", err)
        return
    new_group_entry.delete(0, tk.END)
    refresh_groups()
    g_status.config(text=f"✓ Group '{name}' created", fg=GREEN)
    threading.Thread(target=git_sync, args=(on_sync_done, g_status, create_btn), daemon=True).start()

def do_delete_group():
    sel = groups_listbox.curselection()
    if not sel:
        messagebox.showwarning("No selection", "Select a group to delete.")
        return
    name = groups_listbox.get(sel[0]).strip().split()[0]
    if name == "base":
        messagebox.showerror("Error", "Cannot delete the base group.")
        return
    count = len(load_snippets_from_file(get_group_files().get(name, "")))
    if not messagebox.askyesno("Delete group?", f"Delete group '{name}' and all {count} snippets in it?"):
        return
    ok, err = delete_group_file(name)
    if not ok:
        messagebox.showerror("Error", err)
        return
    refresh_groups()
    g_status.config(text=f"✓ Group '{name}' deleted", fg=GREEN)
    delete_g_btn.config(state="disabled")
    threading.Thread(target=git_sync, args=(on_sync_done, g_status, delete_g_btn), daemon=True).start()

create_btn = tk.Button(g_btn_row, text="CREATE GROUP →", font=FONT_B,
                       bg=ACCENT, fg=BG, relief="flat", bd=0, padx=10, pady=5,
                       cursor="hand2", command=do_create_group)
create_btn.pack(side="left", padx=(0, 8))

delete_g_btn = tk.Button(g_btn_row, text="DELETE GROUP ✕", font=FONT_B,
                          bg=RED, fg=FG, relief="flat", bd=0, padx=10, pady=5,
                          cursor="hand2", command=do_delete_group)
delete_g_btn.pack(side="left")

# ── Start ────────────────────────────────────────────────────────────────────

refresh_group_dropdowns()
show_tab("add")
root.mainloop()
