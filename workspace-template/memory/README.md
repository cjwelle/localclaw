# memory/

This directory is where per-workspace memory notes live. It ships **empty** on
purpose.

- The structured operational log is the SQLite database under the runtime
  state directory (see `sql/README.md`), **not** here.
- Any free-form notes you keep in this folder must contain **no secrets**: no
  tokens, unseal shares, private keys, or API keys.
- Do not commit personal or sensitive notes to a shared repository.

`.gitkeep` keeps the empty directory tracked. Delete this README in your own
workspace if you prefer.
