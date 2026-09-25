-- Tot notes (shell plugin momoledev.tot)
local tot = os.getenv("HOME") .. "/.local/bin/tot-notes"
o.bind("SUPER + CTRL + J", "Tot notes", tot)
for note = 1, 10 do
  o.bind(
    "SUPER + CTRL + ALT + code:" .. tostring(note + 9),
    "Tot note " .. note,
    tot .. " " .. note
  )
end
