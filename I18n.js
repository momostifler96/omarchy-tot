.pragma library

// UI strings for the Quick Note panel. English is the default and the fallback for
// any missing key. `{n}` is replaced by the count passed to tr().
var languages = ["en", "fr", "es", "de", "pt"]

var strings = {
  en: {
    note: "Note",
    placeholder: "Write something…",
    hints: "Ctrl+1…0 tab · Ctrl+Tab next · Ctrl+⇧S sync · Ctrl+B backup · Ctrl+⇧C copy · Ctrl+E editor · Esc close",
    words: "{n} words", word: "{n} word",
    chars: "{n} chars", char: "{n} char",
    justNow: "just now",
    minAgo: "{n} min ago", hourAgo: "{n} h ago", dayAgo: "{n} d ago",
    syncing: "syncing…",
    syncError: "sync error",
    cloudOff: "cloud not set up"
  },
  fr: {
    note: "Note",
    placeholder: "Écris quelque chose…",
    hints: "Ctrl+1…0 onglet · Ctrl+Tab suivant · Ctrl+⇧S synchro · Ctrl+B sauvegarde · Ctrl+⇧C copier · Ctrl+E éditeur · Esc fermer",
    words: "{n} mots", word: "{n} mot",
    chars: "{n} car.", char: "{n} car.",
    justNow: "à l'instant",
    minAgo: "il y a {n} min", hourAgo: "il y a {n} h", dayAgo: "il y a {n} j",
    syncing: "synchro…",
    syncError: "erreur synchro",
    cloudOff: "cloud non configuré"
  },
  es: {
    note: "Nota",
    placeholder: "Escribe algo…",
    hints: "Ctrl+1…0 pestaña · Ctrl+Tab siguiente · Ctrl+⇧S sincronizar · Ctrl+B copia de seguridad · Ctrl+⇧C copiar · Ctrl+E editor · Esc cerrar",
    words: "{n} palabras", word: "{n} palabra",
    chars: "{n} car.", char: "{n} car.",
    justNow: "ahora mismo",
    minAgo: "hace {n} min", hourAgo: "hace {n} h", dayAgo: "hace {n} d",
    syncing: "sincronizando…",
    syncError: "error de sincronización",
    cloudOff: "nube no configurada"
  },
  de: {
    note: "Notiz",
    placeholder: "Schreib etwas…",
    hints: "Strg+1…0 Tab · Strg+Tab weiter · Strg+⇧S Sync · Strg+B Backup · Strg+⇧C kopieren · Strg+E Editor · Esc schließen",
    words: "{n} Wörter", word: "{n} Wort",
    chars: "{n} Zeichen", char: "{n} Zeichen",
    justNow: "gerade eben",
    minAgo: "vor {n} Min.", hourAgo: "vor {n} Std.", dayAgo: "vor {n} T.",
    syncing: "synchronisiere…",
    syncError: "Sync-Fehler",
    cloudOff: "Cloud nicht eingerichtet"
  },
  pt: {
    note: "Nota",
    placeholder: "Escreva algo…",
    hints: "Ctrl+1…0 aba · Ctrl+Tab próxima · Ctrl+⇧S sincronizar · Ctrl+B backup · Ctrl+⇧C copiar · Ctrl+E editor · Esc fechar",
    words: "{n} palavras", word: "{n} palavra",
    chars: "{n} car.", char: "{n} car.",
    justNow: "agora mesmo",
    minAgo: "há {n} min", hourAgo: "há {n} h", dayAgo: "há {n} d",
    syncing: "sincronizando…",
    syncError: "erro de sincronização",
    cloudOff: "nuvem não configurada"
  }
}

// "auto" follows the system locale; anything unsupported falls back to English.
function resolve(setting, localeName) {
  var lang = String(setting || "en").toLowerCase()
  if (lang === "auto") lang = String(localeName || "en").slice(0, 2).toLowerCase()
  return languages.indexOf(lang) >= 0 ? lang : "en"
}

function tr(lang, key, n) {
  var table = strings[lang] || strings.en
  var s = table[key] !== undefined ? table[key] : strings.en[key]
  if (s === undefined) return key
  return n === undefined ? s : s.replace("{n}", String(n))
}

// Singular/plural pair picked by count (e.g. "word"/"words").
function count(lang, singular, plural, n) {
  return tr(lang, n === 1 ? singular : plural, n)
}
