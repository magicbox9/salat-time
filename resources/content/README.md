# Adhkar data — provenance

`adhkar.json` is copied unchanged from the Mac app (`mac_os/adhkar.json`,
SHA-256 `71e4c4c27d981f8bcf7ca0d6c6c65ca1544d51db62c947ab39a575731a501aed`
at the time of copy). Texts come from Hisn al-Muslim (Sa'id ibn Ali ibn Wahf
al-Qahtani) via hisnmuslim.com; morning and evening adhkar were curated with
their virtues and sources.

`App\Services\Content\AdhkarLibrary` reads it. Outside morning/evening the
`virtue` field holds the English meaning of the dhikr, so the page labels it
"Meaning (in English)". Audio streams in the browser only after the visitor
presses Listen: hisnmuslim.com recordings, and Mishary Alafasy on mp3quran.net
for Al-Ikhlas, Al-Falaq and An-Nas (112/113/114), as in the Mac app.
